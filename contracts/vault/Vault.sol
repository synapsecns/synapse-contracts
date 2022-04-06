// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract Vault is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant NODEGROUP_ROLE = keccak256("NODEGROUP_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    mapping(address => uint256) private fees;

    uint256 public startBlockNumber;

    // solhint-disable-next-line
    uint256 public constant bridgeVersion = 7;

    uint256 public chainGasAmount;

    // solhint-disable-next-line
    address payable public WETH_ADDRESS;

    mapping(bytes32 => bool) private kappaMap;

    // -- END OF Synapse:Bridge V1 state variables --

    receive() external payable {
        this;
    }

    function initialize() external initializer {
        startBlockNumber = block.number;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init_unchained();
    }

    // -- EVENTS

    event FeesWithdrawn(IERC20 indexed token, uint256 amount);

    event GasRecovered(uint256 amount);

    event UpdatedChainGasAmount(uint256 amount);

    // -- MODIFIERS --

    /// @notice Check if address is a valid receiver
    modifier checkReceiver(address to) {
        require(to != address(0), "to is 0x00 address");
        _;
    }

    /// @notice Check if possible to withdraw amount of token
    modifier checkTokenRequest(IERC20 token, uint256 amount) {
        require(amount != 0, "Amount is zero");
        require(getTokenBalance(token) >= amount, "Withdraw amount is too big");
        _;
    }

    /// @notice Check if kappa has already been used, mark as used if not
    modifier markKappa(bytes32 kappa) {
        require(!kappaMap[kappa], "Kappa already exists");
        kappaMap[kappa] = true;
        _;
    }

    /// @notice This role can setup WETh address and manage other roles
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }

    /// @notice This role sets Vault parameters, withdraws fees
    modifier onlyGovernance() {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
        _;
    }

    /// @notice This is role for Synapse: Bridge contract
    /// It's able to withdraw assets by providing valid kappa
    modifier onlyNodeGroup() {
        require(hasRole(NODEGROUP_ROLE, msg.sender), "Not governance");
        _;
    }

    // -- VIEWS --

    function getFeeBalance(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return fees[tokenAddress];
    }

    function getTokenBalance(IERC20 token) public view returns (uint256) {
        uint256 tokenBalance = token.balanceOf(address(this));
        uint256 tokenFees = fees[address(token)];
        return tokenBalance > tokenFees ? tokenBalance - tokenFees : 0;
    }

    function kappaExists(bytes32 kappa) external view returns (bool) {
        return kappaMap[kappa];
    }

    // -- RESTRICTED SETTERS --

    function setChainGasAmount(uint256 amount) external onlyGovernance {
        chainGasAmount = amount;
        emit UpdatedChainGasAmount(amount);
    }

    function setWethAddress(address payable _wethAddress) external onlyAdmin {
        WETH_ADDRESS = _wethAddress;
    }

    function addKappas(bytes32[] calldata kappas) external onlyGovernance {
        for (uint256 i = 0; i < kappas.length; ++i) {
            kappaMap[kappas[i]] = true;
        }
    }

    // -- RECOVER TOKEN/GAS --

    /**
        @notice Recover GAS from the contract
     */
    function recoverGAS() external onlyGovernance {
        uint256 amount = address(this).balance;
        require(amount != 0, "Nothing to recover");

        emit GasRecovered(amount);
        //solhint-disable-next-line
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "GAS transfer failed");
    }

    /**
     * * @notice withdraw specified ERC20 token fees to a given address
     * * @param token ERC20 token in which fees accumulated to transfer
     * * @param to Address to send the fees to
     */
    function withdrawFees(IERC20 token, address to)
        external
        onlyGovernance
        whenNotPaused
    {
        require(to != address(0), "Address is 0x00");
        uint256 feeAmount = fees[address(token)];
        require(feeAmount != 0, "Nothing to withdraw");

        emit FeesWithdrawn(token, feeAmount);
        fees[address(token)] = 0;
        token.safeTransfer(to, feeAmount);
    }

    // -- PAUSABLE FUNCTIONS --

    function pause() external onlyGovernance {
        _pause();
    }

    function unpause() external onlyGovernance {
        _unpause();
    }

    // -- VAULT FUNCTIONS --

    function mintToken(
        address to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        bool gasdropRequested,
        bytes32 kappa
    )
        external
        onlyNodeGroup
        nonReentrant
        whenNotPaused
        markKappa(kappa)
        checkReceiver(to)
        returns (uint256 gasdropAmount)
    {
        fees[address(token)] += fee;
        token.mint(to, amount);
        token.mint(address(this), fee);

        if (gasdropRequested) {
            gasdropAmount = _transferGasDrop(to);
        }
    }

    function withdrawToken(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bool gasdropRequested,
        bytes32 kappa
    )
        external
        onlyNodeGroup
        nonReentrant
        whenNotPaused
        markKappa(kappa)
        checkReceiver(to)
        checkTokenRequest(token, amount + fee)
        returns (uint256 gasdropAmount)
    {
        fees[address(token)] += fee;
        token.safeTransfer(to, amount);

        if (gasdropRequested) {
            gasdropAmount = _transferGasDrop(to);
        }
    }

    function _transferGasDrop(address to)
        internal
        returns (uint256 gasdropAmount)
    {
        if (chainGasAmount > 0 && address(this).balance >= chainGasAmount) {
            // solhint-disable avoid-low-level-calls
            (bool success, ) = to.call{value: chainGasAmount}("");
            if (success) {
                gasdropAmount = chainGasAmount;
            }
        }
    }
}
