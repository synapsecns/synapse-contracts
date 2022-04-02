// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBridgeRouter} from "./interfaces/IBridgeRouter.sol";

import {ERC20Burnable} from "@openzeppelin/contracts-solc8/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import {IBridge} from "../vault/interfaces/IBridge.sol";

import {Router} from "./Router.sol";

// solhint-disable reason-string

contract BridgeRouter is Router, IBridgeRouter {
    using SafeERC20 for IERC20;

    /// @notice Address of Synapse: Bridge contract
    address public immutable bridge;

    /// @notice Maximum amount of swaps for Bridge&Swap transaction
    /// It is enforced to limit the gas costs for validators on "expensive" chains
    /// There's no extra limitation for Swap&Bridge txs, as the gas is paid by the user
    uint8 public bridgeMaxSwaps;

    /// @dev Some of the tokens are not directly compatible with Synapse:Bridge contract.
    /// For these tokens a wrapper contract is deployed, that will be used
    /// as a "bridge token" in Synapse:Bridge.
    /// The UI, or any other entity, interacting with the BridgeRouter, do NOT need to
    /// know anything about the "bridge wrappers", they should interact as if the
    /// underlying token is the "bridge token".

    /// For example, when calling {bridgeToken}, set `_bridgeToken` as underlying token.
    /// In {swapAndBridge} use underlying token as `path[N-1]`.
    mapping(address => address) public bridgeWrappers;
    mapping(address => address) public underlyingTokens;

    uint256 internal constant MINT_BURN = 1;
    uint256 internal constant DEPOSIT_WITHDRAW = 2;

    uint256 internal constant EVM_CHAIN = 1;
    uint256 internal constant NON_EVM_CHAIN = 2;

    constructor(
        address payable _wgas,
        address _bridge,
        uint8 _bridgeMaxSwaps
    ) Router(_wgas) {
        bridge = _bridge;
        setBridgeMaxSwaps(_bridgeMaxSwaps);
    }

    modifier onlyBridge() {
        require(msg.sender == bridge, "Caller is not Bridge");

        _;
    }

    // -- RESTRICTED SETTERS --

    function setBridgeMaxSwaps(uint8 _bridgeMaxSwaps)
        public
        onlyRole(GOVERNANCE_ROLE)
    {
        bridgeMaxSwaps = _bridgeMaxSwaps;
    }

    /**
        @notice Register a MintBurnWrapper that will be used as a "bridge token".
        @dev This is meant to be used, when original bridge token isn't directly compatible with Synapse:Bridge.
             1. Set `_bridgeWrapper` = address(0) to bridge `_bridgeToken` directly
             2. Use unique `bridgeWrapper` for every `bridgeToken` that needs a bridge wrapper contract
        @param _bridgeToken underlying (native) bridge token
        @param _bridgeWrapper wrapper contract used for actual bridging
     */
    function setBridgeWrapper(address _bridgeToken, address _bridgeWrapper)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        // Delete record of underlying from bridgeToken's "old bridge wrapper",
        // if there is one
        address _oldWrapper = bridgeWrappers[_bridgeToken];
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
        bridgeWrappers[_bridgeToken] = _bridgeWrapper;
        underlyingTokens[_bridgeWrapper] = _bridgeToken;
    }

    function setInfiniteTokenAllowance(IERC20 _token, address _spender)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        require(_spender != bridge, "Bridge doesn't need infinite allowance");
        _setTokenAllowance(_token, _spender, UINT_MAX);
    }

    function revokeTokenAllowance(IERC20 _token, address _spender)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        _token.safeApprove(_spender, 0);
    }

    // -- BRIDGE FUNCTIONS [initial chain]: to EVM chains --

    function bridgeToEVM(
        IERC20 _tokenIn,
        uint256 _amountIn,
        address _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _bridgedSwapParams
    ) external returns (uint256 _amountBridged) {
        // First, pull token from user and use actual amount received later
        _amountBridged = _pullTokenFromCaller(_tokenIn, _amountIn);

        // Then, perform bridging
        _bridgeToEVM(
            address(_tokenIn),
            _amountBridged,
            _to,
            _chainId,
            _bridgedSwapParams
        );
    }

    function swapAndBridgeToEVM(
        uint256 _amountIn,
        IBridge.SwapParams calldata _initialSwapParams,
        address _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _bridgedSwapParams
    ) external returns (uint256 _amountBridged) {
        // First, perform swap on initial chain
        // Need to pull tokens from caller => isSelfSwap = false
        address _bridgeToken;
        (_bridgeToken, _amountBridged) = _doInitialSwap(
            _amountIn,
            _initialSwapParams,
            false
        );

        // Then, perform bridging
        _bridgeToEVM(
            _bridgeToken,
            _amountBridged,
            _to,
            _chainId,
            _bridgedSwapParams
        );
    }

    function swapFromGasAndBridgeToEVM(
        uint256 _amountIn,
        IBridge.SwapParams calldata _initialSwapParams,
        address _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _bridgedSwapParams
    ) external payable returns (uint256 _amountBridged) {
        // TODO: ditch _amountIn ? or leave for consistency with other functions' params
        require(msg.value == _amountIn, "Router: incorrect amount of GAS");
        require(
            _initialSwapParams.path[0] == WGAS,
            "Router: path needs to begin with WGAS"
        );

        // First, wrap GAS into WGAS
        _wrap(_amountIn);

        // Then, perform swap on initial chain
        // Tokens(WGAS) are in the contract => isSelfSwap = true
        address _bridgeToken;
        (_bridgeToken, _amountBridged) = _doInitialSwap(
            _amountIn,
            _initialSwapParams,
            true
        );

        // Finally, perform bridging
        _bridgeToEVM(
            _bridgeToken,
            _amountBridged,
            _to,
            _chainId,
            _bridgedSwapParams
        );
    }

    // -- BRIDGE FUNCTIONS [initial chain]: to non-EVM chains --

    function bridgeToNonEVM(
        IERC20 _tokenIn,
        uint256 _amountIn,
        bytes32 _to,
        uint256 _chainId
    ) external returns (uint256 _amountBridged) {
        // First, pull token from user and use actual amount received later
        _amountBridged = _pullTokenFromCaller(_tokenIn, _amountIn);

        // Then, perform bridging
        _bridgeToNonEVM(address(_tokenIn), _amountIn, _to, _chainId);
    }

    function swapAndBridgeToNonEVM(
        uint256 _amountIn,
        IBridge.SwapParams calldata _initialSwapParams,
        bytes32 _to,
        uint256 _chainId
    ) external returns (uint256 _amountBridged) {
        // First, perform swap on initial chain
        // Need to pull tokens from caller => isSelfSwap = false
        address _bridgeToken;
        (_bridgeToken, _amountBridged) = _doInitialSwap(
            _amountIn,
            _initialSwapParams,
            false
        );

        // Then, perform bridging
        _bridgeToNonEVM(_bridgeToken, _amountBridged, _to, _chainId);
    }

    function swapFromGasAndBridgeToNonEVM(
        uint256 _amountIn,
        IBridge.SwapParams calldata _initialSwapParams,
        bytes32 _to,
        uint256 _chainId
    ) external payable returns (uint256 _amountBridged) {
        // TODO: ditch _amountIn ? or leave for consistency with other functions' params
        require(msg.value == _amountIn, "Router: incorrect amount of GAS");
        require(
            _initialSwapParams.path[0] == WGAS,
            "Router: path needs to begin with WGAS"
        );

        // First, wrap GAS into WGAS
        _wrap(_amountIn);

        // Then, perform swap on initial chain
        // Tokens(WGAS) are in the contract => isSelfSwap = true
        address _bridgeToken;
        (_bridgeToken, _amountBridged) = _doInitialSwap(
            _amountIn,
            _initialSwapParams,
            true
        );

        // Finally, perform bridging
        _bridgeToNonEVM(_bridgeToken, _amountBridged, _to, _chainId);
    }

    // -- BRIDGE FUNCTIONS [initial chain]: internal helpers

    function _bridgeToEVM(
        address _bridgeToken,
        uint256 _bridgeAmount,
        address _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _bridgedSwapParams
    ) internal {
        // Use Wrapper contract, if there's one registered
        // This allows to abstract concept of "Bridge Wrappers" away from the UI
        _bridgeToken = _getBridgeToken(_bridgeToken);

        uint256 _bridgeType = IBridge(bridge).tokenBridgeType(_bridgeToken);
        require(
            _bridgeType == MINT_BURN || _bridgeType == DEPOSIT_WITHDRAW,
            "BridgeRouter: Unsupported bridge token"
        );

        (
            _bridgeType == MINT_BURN
                ? IBridge(bridge).redeemEVM
                : IBridge(bridge).depositEVM
        )(_to, _chainId, _bridgeToken, _bridgeAmount, _bridgedSwapParams);
    }

    function _bridgeToNonEVM(
        address _bridgeToken,
        uint256 _bridgeAmount,
        bytes32 _to,
        uint256 _chainId
    ) internal {
        // Use Wrapper contract, if there's one registered
        // This allows to abstract concept of "Bridge Wrappers" away from the UI
        _bridgeToken = _getBridgeToken(_bridgeToken);

        uint256 _bridgeType = IBridge(bridge).tokenBridgeType(_bridgeToken);
        require(
            _bridgeType == MINT_BURN || _bridgeType == DEPOSIT_WITHDRAW,
            "BridgeRouter: Unsupported bridge token"
        );

        (
            _bridgeType == MINT_BURN
                ? IBridge(bridge).redeemNonEVM
                : IBridge(bridge).depositNonEVM
        )(_to, _chainId, _bridgeToken, _bridgeAmount);
    }

    function _doInitialSwap(
        uint256 _amountIn,
        IBridge.SwapParams calldata _initialSwapParams,
        bool _isSelfSwap
    ) internal returns (address _lastToken, uint256 _amountOut) {
        _amountOut = (_isSelfSwap ? _selfSwap : _swap)(
            _amountIn,
            _initialSwapParams.minAmountOut,
            _initialSwapParams.path,
            _initialSwapParams.adapters,
            address(this)
        );

        _lastToken = _getLastToken(_initialSwapParams);
    }

    // -- BRIDGE RELATED FUNCTIONS [destination chain] --

    /**
        @notice refund tokens from unsuccessful swap back to user
        @dev This will return native GAS to user, if token = WGAS, so calling contract
             needs to check for reentrancy.
        @param _token token to refund
        @param _amount amount of tokens to refund
        @param _to address to receive refund tokens
     */
    function refundToAddress(
        address _token,
        uint256 _amount,
        address _to
    ) external onlyBridge {
        // We don't check for reentrancy here as all the work is done

        // BUT Bridge contract might want to check
        // for reentrancy when calling refundToAddress()
        // Imagine [Bridge GAS & Swap] back to its native chain.
        // If swap fails, this unwrap WGAS and return GAS to user

        /// @dev In case `_token` is a Bridge Wrapper, we need to return underlying token
        _returnTokensTo(_getUnderlyingToken(_token), _amount, _to);
    }

    /**
        @notice Perform a series of swaps, assuming the starting tokens
                are already deposited in this contract
        @dev 1. This will revert if amount of adapters is too big, 
                bridgeMaxSwaps is usually lower than maxSwaps
             2. Use BridgeQuoter.findBestPathDestinationChain() to correctly 
                find path with len(_adapters) <= bridgeMaxSwaps
             3. len(_path) = N, len(_adapters) = N - 1
        @param _amountIn amount of initial tokens to swap
        @param _to address to receive final tokens
        @return _amountOut Final amount of tokens swapped
     */
    function postBridgeSwap(
        uint256 _amountIn,
        IBridge.SwapParams calldata _swapParams,
        address _to
    ) external onlyBridge returns (uint256 _amountOut) {
        require(
            _swapParams.adapters.length <= bridgeMaxSwaps,
            "BridgeRouter: Too many swaps in path"
        );
        if (_getLastToken(_swapParams) == WGAS) {
            // Path ends with WGAS, and no one wants
            // to receive WGAS after bridging, right?
            _amountOut = _selfSwap(
                _amountIn,
                _swapParams.minAmountOut,
                _swapParams.path,
                _swapParams.adapters,
                address(this)
            );
            // this will unwrap WGAS and return GAS
            // reentrancy not an issue here, as all work is done
            _returnTokensTo(WGAS, _amountOut, _to);
        } else {
            _amountOut = _selfSwap(
                _amountIn,
                _swapParams.minAmountOut,
                _swapParams.path,
                _swapParams.adapters,
                _to
            );
        }
    }

    // -- INTERNAL HELPERS --

    function _getBridgeToken(address _bridgeToken)
        internal
        view
        returns (address _actualBridgeToken)
    {
        _actualBridgeToken = bridgeWrappers[_bridgeToken];
        if (_actualBridgeToken == address(0)) {
            _actualBridgeToken = _bridgeToken;
        }
    }

    function _getUnderlyingToken(address _bridgeToken)
        internal
        view
        returns (address _actualUnderlyingToken)
    {
        _actualUnderlyingToken = underlyingTokens[_bridgeToken];
        if (_actualUnderlyingToken == address(0)) {
            _actualUnderlyingToken = _bridgeToken;
        }
    }

    function _getLastToken(IBridge.SwapParams calldata _swapParams)
        internal
        pure
        returns (address _lastToken)
    {
        _lastToken = _swapParams.path[_swapParams.path.length - 1];
    }

    function _pullTokenFromCaller(IERC20 _token, uint256 _amount)
        internal
        returns (uint256 _amountPulled)
    {
        _amountPulled = _token.balanceOf(address(this));
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        // Return difference in token balance
        _amountPulled = _token.balanceOf(address(this)) - _amountPulled;
    }

    /**
        @notice Set approval for bridge to spend Router's _bridgeToken
     
        @dev 1. This uses a finite _amount rather than UINT_MAX, so
                Bridge's function redeemMax (depositMax) will be able to
                pull exactly as much tokens as we need.
        @param _bridgeToken token to approve
        @param _amount amount of tokens to approve
     */
    function _setBridgeTokenAllowance(address _bridgeToken, uint256 _amount)
        internal
    {
        _setTokenAllowance(IERC20(_bridgeToken), bridge, _amount);
    }

    function _setTokenAllowance(
        IERC20 _token,
        address _spender,
        uint256 _amount
    ) internal {
        uint256 allowance = _token.allowance(address(this), _spender);
        if (allowance == _amount) {
            return;
        }
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. (c) openzeppelin
        if (allowance != 0) {
            _token.safeApprove(_spender, 0);
        }
        _token.safeApprove(_spender, _amount);
    }
}
