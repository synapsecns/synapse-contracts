// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import {Initializable} from "@openzeppelin/contracts-upgradeable-solc8/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable-solc8/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable-solc8/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable-solc8/security/PausableUpgradeable.sol";

import {ERC20Burnable} from "@openzeppelin/contracts-solc8/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import {IVault} from "./interfaces/IVault.sol";
import {IBridge} from "./interfaces/IBridge.sol";

import {IBridgeRouter} from "../router/interfaces/IBridgeRouter.sol";

// solhint-disable reason-string

contract Bridge is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IBridge
{
    using SafeERC20 for IERC20;

    IVault public vault;
    IBridgeRouter public router;

    bytes32 public constant NODEGROUP_ROLE = keccak256("NODEGROUP_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    /// @notice Maximum amount of GAS units for Swap part of bridge transaction
    uint256 public maxGasForSwap;

    uint256 internal constant UINT_MAX = type(uint256).max;

    /// @dev Some of the tokens are not directly compatible with Synapse:Bridge contract.
    /// For these tokens a wrapper contract is deployed, that will be used
    /// as a "bridge token" in Synapse:Bridge.
    /// The UI, or any other entity, interacting with the BridgeRouter, do NOT need to
    /// know anything about the "bridge wrappers", they should interact as if the
    /// underlying token is the "bridge token".

    /// For example, when calling {depositEVM}, set `token` as underlying token
    /// Also, use underlying token for `destinationSwapParams.path[0]`
    mapping(address => address) internal bridgeWrappers;
    mapping(address => address) internal underlyingTokens;

    /// @dev key is underlyingToken here,
    mapping(address => TokenType) public bridgeTokenType;

    function initialize(IVault _vault, uint128 _maxGasForSwap)
        external
        initializer
    {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        vault = _vault;
        maxGasForSwap = _maxGasForSwap;
    }

    // -- MODIFIERS --

    modifier checkFee(uint256 amount, uint256 fee) {
        require(amount > fee, "Amount must be greater than fee");

        _;
    }

    modifier checkSwapParams(SwapParams calldata swapParams) {
        require(
            swapParams.path.length == swapParams.adapters.length + 1,
            "Bridge: len(path)!=len(adapters)+1"
        );

        _;
    }

    modifier checkTokenSupported(IERC20 token) {
        require(
            bridgeTokenType[address(token)] != TokenType.NOT_SUPPORTED,
            "Bridge: token is not supported"
        );

        _;
    }

    // -- VIEWS --

    function getBridgeToken(IERC20 token)
        public
        view
        returns (IERC20 bridgeToken)
    {
        address bridgeTokenAddress = bridgeWrappers[address(token)];
        if (bridgeTokenAddress == address(0)) {
            bridgeToken = token;
        } else {
            bridgeToken = IERC20(bridgeTokenAddress);
        }
    }

    function getUnderlyingToken(IERC20 token)
        public
        view
        returns (IERC20 underlyingToken)
    {
        address underlyingTokenAddress = underlyingTokens[address(token)];
        if (underlyingTokenAddress == address(0)) {
            underlyingToken = token;
        } else {
            underlyingToken = IERC20(underlyingTokenAddress);
        }
    }

    // -- RECOVER TOKEN/GAS --

    /**
        @notice Recover GAS from the contract
     */
    function recoverGAS() external onlyRole(GOVERNANCE_ROLE) {
        uint256 amount = address(this).balance;
        require(amount != 0, "Nothing to recover");

        emit Recovered(address(0), amount);
        //solhint-disable-next-line
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "GAS transfer failed");
    }

    /**
        @notice Recover a token from the contract
        @param token token to recover
     */
    function recoverERC20(IERC20 token) external onlyRole(GOVERNANCE_ROLE) {
        uint256 amount = token.balanceOf(address(this));
        require(amount != 0, "Nothing to recover");

        emit Recovered(address(token), amount);
        //solhint-disable-next-line
        token.safeTransfer(msg.sender, amount);
    }

    // -- RESTRICTED SETTERS --

    /**
        @notice Register a bridge token for later usage on the bridge
        @dev Most of the time `bridgeToken` will be directly compatible with Synapse: Bridge,
        i.e. can be safely used as deposit-withdraw, or can be used as mint-burn, if both
        {mint} and {burnFrom} are implemented correctly, and `Vault` has a Minter role.
        In this case, `bridgeToken == bridgeWrapper`.

        In some cases, an intermediate contract is required to achieve that, it is called a Bridge Wrapper.
        In this case, `bridgeToken != bridgeWrapper`.

        Use registerBridgeToken(bridgeToken, bridgeWrapper, NOT_SUPPORTED) to remove token from supported list
        Use registerBridgeToken(bridgeToken, newBridgeWrapper, MINT_BURN) to update record about a Bridge Wrapper

        @param bridgeToken token that will be bridged
        @param bridgeWrapper token that Synapse:Bridge will use for bridging
        @param tokenType not-supported, mint-burn or deposit-withdraw
     */
    function registerBridgeToken(
        address bridgeToken,
        address bridgeWrapper,
        TokenType tokenType
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(
            bridgeToken != address(0),
            "Bridge token can't be zero address"
        );
        require(
            bridgeWrapper != address(0),
            "Bridge wrapper can't be zero address"
        );

        address _oldUnderlying = underlyingTokens[bridgeWrapper];
        require(
            _oldUnderlying == address(0) || _oldUnderlying == bridgeWrapper,
            "BridgeWrapper is linked to another bridge token"
        );

        // Delete record of underlying from bridgeToken's "old bridge wrapper",
        // if there is one
        address _oldWrapper = bridgeWrappers[bridgeToken];
        if (_oldWrapper != address(0) && _oldWrapper != bridgeWrapper) {
            underlyingTokens[_oldWrapper] = address(0);
        }

        if (tokenType != TokenType.NOT_SUPPORTED) {
            // Save records
            underlyingTokens[bridgeWrapper] = bridgeToken;
            bridgeWrappers[bridgeToken] = bridgeWrapper;
        } else {
            // Delete records
            underlyingTokens[bridgeWrapper] = address(0);
            bridgeWrappers[bridgeToken] = address(0);
        }

        bridgeTokenType[bridgeToken] = tokenType;
        emit BridgeTokenRegistered(bridgeToken, bridgeWrapper, tokenType);
    }

    function setMaxGasForSwap(uint128 _maxGasForSwap)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        maxGasForSwap = _maxGasForSwap;
    }

    function setRouter(IBridgeRouter _router)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        router = _router;
    }

    // -- BRIDGE OUT FUNCTIONS: to EVM chains --

    function bridgeToEVM(
        address to,
        uint256 chainId,
        IERC20 token,
        SwapParams calldata destinationSwapParams
    )
        external
        checkTokenSupported(token)
        checkSwapParams(destinationSwapParams)
        returns (uint256 amountBridged)
    {
        // First, burn token, or deposit to Vault (depending on bridge token type).
        // Use verified burnt/deposited amount for bridging purposes.
        amountBridged = _lockToken(token);

        // Finally, emit a Bridge Event
        emit BridgedOutEVM(
            to,
            chainId,
            token,
            amountBridged,
            destinationSwapParams
        );
    }

    // -- BRIDGE OUT FUNCTIONS: to non-EVM chain --

    function bridgeToNonEVM(
        bytes32 to,
        uint256 chainId,
        IERC20 token
    ) external checkTokenSupported(token) returns (uint256 amountBridged) {
        // First, burn token, or deposit to Vault (depending on bridge token type).
        // Use verified burnt/deposited amount for bridging purposes.
        amountBridged = _lockToken(token);

        // Then, emit a Bridge Event
        emit BridgedOutNonEVM(to, chainId, token, amountBridged);
    }

    // -- BRIDGE OUT : internal helpers --

    function _burnToken(IERC20 token, uint256 amount)
        internal
        returns (uint256 amountBurnt)
    {
        uint256 balanceBefore = token.balanceOf(address(this));

        address bridgeTokenAddress = address(getBridgeToken(token));
        ERC20Burnable(bridgeTokenAddress).burn(amount);

        amountBurnt = balanceBefore - token.balanceOf(address(this));
        require(amountBurnt > 0, "No burn happened");
    }

    function _depositToken(IERC20 token, uint256 amount)
        internal
        returns (uint256 amountDeposited)
    {
        uint256 balanceBefore = token.balanceOf(address(vault));

        address bridgeTokenAddress = address(getBridgeToken(token));
        IERC20(bridgeTokenAddress).transfer(address(vault), amount);

        amountDeposited = token.balanceOf(address(vault)) - balanceBefore;
        require(amountDeposited > 0, "No deposit happened");
    }

    function _lockToken(IERC20 token)
        internal
        returns (uint256 amountVerified)
    {
        // First, figure out how much tokens do we have.
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "Bridge: Insufficient token amount");

        // Then, burn token, or deposit to Vault (depending on bridge token type).
        amountVerified = (
            bridgeTokenType[address(token)] == TokenType.MINT_BURN
                ? _burnToken
                : _depositToken
        )(token, amount);
    }

    // -- BRIDGE IN FUNCTIONS --

    function bridgeIn(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        SwapParams calldata swapParams,
        bytes32 kappa
    )
        external
        onlyRole(NODEGROUP_ROLE)
        nonReentrant
        whenNotPaused
        checkFee(amount, fee)
        checkTokenSupported(token)
    {
        // First, get the amount post fees
        amount = amount - fee;

        SwapResult memory swapResult;
        bool airdropGiven;
        bool isMint = bridgeTokenType[address(token)] == TokenType.MINT_BURN;

        if (
            _isSwapPresent(swapParams) &&
            !_isDeadlineFailed(swapParams.deadline)
        ) {
            // If there's a swap, and deadline check is passed,
            // release bridged tokens to Router
            airdropGiven = _releaseToken(
                address(router),
                token,
                amount,
                fee,
                isMint,
                kappa
            );

            // Then handle the swap part
            swapResult = _handleSwap(to, token, amount, swapParams);
        } else {
            // If there's no swap, or deadline check is not passed,
            // release bridged token to needed address
            airdropGiven = _releaseToken(to, token, amount, fee, isMint, kappa);

            swapResult = SwapResult(token, amount);
        }

        // Finally, emit BridgeIn Event
        emit TokenBridgedIn(
            to,
            token,
            amount + fee,
            fee,
            isMint,
            swapResult.tokenReceived,
            swapResult.amountReceived,
            airdropGiven,
            kappa
        );
    }

    // -- BRIDGE IN: internal helpers --

    function _handleSwap(
        address to,
        IERC20 token,
        uint256 amountPostFee,
        SwapParams calldata swapParams
    ) internal returns (SwapResult memory swapResult) {
        // We're limiting amount of gas forwarded to Router,
        // so we always have some leftover gas to transfer
        // bridged token, should the swap run out of gas
        try
            router.postBridgeSwap{gas: maxGasForSwap}(
                to,
                swapParams,
                amountPostFee
            )
        returns (uint256 _amountOut) {
            swapResult = SwapResult(
                IERC20(swapParams.path[swapParams.path.length - 1]),
                _amountOut
            );
        } catch {
            swapResult = SwapResult(token, amountPostFee);
            router.refundToAddress(to, token, amountPostFee);
        }
    }

    function _isDeadlineFailed(uint256 deadline) internal view returns (bool) {
        //solhint-disable-next-line
        return block.timestamp > deadline;
    }

    function _isSwapPresent(SwapParams calldata params)
        internal
        pure
        returns (bool)
    {
        return params.adapters.length > 0;
    }

    function _releaseToken(
        address to,
        IERC20 token,
        uint256 amountPostFee,
        uint256 fee,
        bool isMint,
        bytes32 kappa
    ) internal returns (bool airdropGiven) {
        IERC20 bridgeToken = getBridgeToken(token);
        airdropGiven = (isMint ? vault.mintToken : vault.withdrawToken)(
            to,
            bridgeToken,
            amountPostFee,
            fee,
            true, // airdropRequested
            kappa
        );
    }
}
