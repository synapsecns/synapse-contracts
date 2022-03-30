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

    /// @dev for some tokens external Synapse contracts will need
    /// to withdraw funds from Vault by locking/burning other tokens
    /// without providing kappa (single-chain tx)
    mapping(address => address) private tokenSpender;

    /// @dev Some of the tokens are not directly compatible with Synapse:Bridge contract.
    /// For these tokens a wrapper contract is deployed, that will be used
    /// as a "bridge token" in Synapse:Bridge.

    /// The UI, or any other entity, interacting with the BridgeRouter do NOT need to
    /// know anything about the "bridge wrappers", they should interact as if the
    /// underlying token is the "bridge token".

    /// Contracts, interacting with Bridge/Vault directly (such as BridgeRouter), need to know
    /// if a token is supported, or a "bridge wrapper" needs to be used

    mapping(address => address) public bridgeWrappers;
    mapping(address => address) public underlyingTokens;

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

    event UpdatedTokenSpender(IERC20 indexed token, address spender);

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

    /**
        @notice Register a MintBurnWrapper that will be used as a "bridge token".
        @dev This is meant to be used, when original bridge token isn't directly compatible with Synapse:Bridge.
             1. Set `_bridgeWrapper` = address(0) to bridge `bridgeToken` directly
             2. Use unique `bridgeWrapper` for every `bridgeToken` that needs a bridge wrapper contract
        @param bridgeToken underlying (native) bridge token
        @param _bridgeWrapper wrapper contract used for actual bridging
     */
    function setBridgeWrapper(address bridgeToken, address _bridgeWrapper)
        external
        onlyGovernance
    {
        // Delete record of underlying from bridgeToken's "old bridge wrapper",
        // if there is one
        address _oldWrapper = bridgeWrappers[bridgeToken];
        if (_oldWrapper != address(0)) {
            underlyingTokens[_oldWrapper] = address(0);
        }

        // Delete record of wrapper from bridgeWrapper's "old underlying token",
        // if there is one
        address _oldUnderlying = underlyingTokens[_bridgeWrapper];
        if (_oldUnderlying != address(0)) {
            bridgeWrappers[_oldUnderlying] = address(0);
        }

        // Update records for both tokens
        bridgeWrappers[bridgeToken] = _bridgeWrapper;
        underlyingTokens[_bridgeWrapper] = bridgeToken;
    }

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
        bytes32 kappa
    )
        external
        onlyNodeGroup
        nonReentrant
        whenNotPaused
        markKappa(kappa)
        checkReceiver(to)
    {
        /// @dev if `token` is a Bridge Wrapper, fees are collected
        /// in underlying token and have to be stored accordingly,
        /// otherwise these fees will be unclaimable via {withdrawFees}
        fees[_getUnderlyingToken(address(token))] += fee;

        token.mint(to, amount);
        token.mint(address(this), fee);
    }

    function spendToken(
        address to,
        IERC20 token,
        uint256 amount
    )
        external
        onlyTokenSpender(token)
        nonReentrant
        whenNotPaused
        checkReceiver(to)
        checkTokenRequest(token, amount)
    {
        token.safeTransfer(to, amount);
    }

    function withdrawToken(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    )
        external
        onlyNodeGroup
        nonReentrant
        whenNotPaused
        markKappa(kappa)
        checkReceiver(to)
        checkTokenRequest(token, amount + fee)
    {
        fees[address(token)] += fee;
        token.safeTransfer(to, amount);
    }

    // -- INTERNAL HELPERS --
    function _getUnderlyingToken(address bridgeToken)
        internal
        view
        returns (address actualUnderlyingToken)
    {
        actualUnderlyingToken = underlyingTokens[bridgeToken];
        if (actualUnderlyingToken == address(0)) {
            actualUnderlyingToken = bridgeToken;
        }
    }
}
