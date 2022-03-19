// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

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

    /// @dev for some tokens external Synapse contracts will need
    /// to withdraw funds from Vault by locking/burning other tokens
    /// without providing kappa (single-chain tx)
    mapping(address => address) private tokenSpender;

    receive() external payable {
        this;
    }

    function initialize() external initializer {
        startBlockNumber = block.number;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();
    }

    // -- EVENTS

    event UpdatedChainGasAmount(uint256 amount);

    event UpdatedTokenSpender(IERC20 token, address spender);

    // -- MODIFIERS --

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

    /// @notice Token's spender is able to withdraw a given token
    /// without providing kappa. This is permissioned and is supposed
    /// to be used for tricky swap adapters.
    modifier onlyTokenSpender(IERC20 token) {
        require(msg.sender == tokenSpender[address(token)], "Not spender");
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

    function setTokenSpender(IERC20 token, address spender)
        external
        onlyGovernance
    {
        tokenSpender[address(token)] = spender;
        emit UpdatedTokenSpender(token, spender);
    }

    function setWethAddress(address payable _wethAddress) external onlyAdmin {
        WETH_ADDRESS = _wethAddress;
    }

    function addKappas(bytes32[] calldata kappas) external onlyGovernance {
        for (uint256 i = 0; i < kappas.length; ++i) {
            kappaMap[kappas[i]] = true;
        }
    }

    // -- FEE FUNCTIONS --

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
        fees[address(token)] = 0;
        token.safeTransfer(to, feeAmount);
    }

    // -- PAUSABLE FUNCTIONS --

    function pause() external {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
        _pause();
    }

    function unpause() external {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
        _unpause();
    }

    // -- VAULT FUNCTIONS --

    function withdrawToken(
        IERC20 token,
        uint256 amount,
        address to,
        bytes32 kappa
    ) external onlyNodeGroup nonReentrant whenNotPaused {
        _checkTokenRequest(token, amount, to);
        require(!kappaMap[kappa], "Kappa already exists");
        kappaMap[kappa] = true;
        token.safeTransfer(to, amount);
    }

    function spendToken(
        IERC20 token,
        uint256 amount,
        address to
    ) external onlyTokenSpender(token) nonReentrant whenNotPaused {
        _checkTokenRequest(token, amount, to);
        token.safeTransfer(to, amount);
    }

    // -- INTERNAL HELPERS --

    function _checkTokenRequest(
        IERC20 token,
        uint256 amount,
        address to
    ) internal view {
        require(amount != 0, "Amount is zero");
        require(to != address(0), "to is 0x00 address");
        require(getTokenBalance(token) >= amount, "Withdraw amount is too big");
    }
}
