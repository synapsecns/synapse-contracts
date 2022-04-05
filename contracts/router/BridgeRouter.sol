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

    modifier checkSwapParams(IBridge.SwapParams calldata swapParams) {
        require(
            swapParams.path.length == swapParams.adapters.length + 1,
            "BridgeRouter: len(path)!=len(adapters)+1"
        );

        _;
    }

    // -- RESTRICTED SETTERS --

    function setBridgeMaxSwaps(uint8 _bridgeMaxSwaps)
        public
        onlyRole(GOVERNANCE_ROLE)
    {
        bridgeMaxSwaps = _bridgeMaxSwaps;
    }

    function setInfiniteTokenAllowance(IERC20 _token, address _spender)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        require(_spender != bridge, "Bridge doesn't need infinite allowance");
        _setTokenAllowance(_token, UINT_MAX, _spender);
    }

    function revokeTokenAllowance(IERC20 _token, address _spender)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        _token.safeApprove(_spender, 0);
    }

    // -- BRIDGE FUNCTIONS [initial chain]: to EVM chains --

    function bridgeTokenToEVM(
        address _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _initialSwapParams,
        uint256 _amountIn,
        IBridge.SwapParams calldata _destinationSwapParams
    ) external returns (uint256 _amountBridged) {
        // First, perform swap on initial chain
        // Need to pull tokens from caller => isSelfSwap = false
        IERC20 _bridgeToken;
        (_bridgeToken, _amountBridged) = _swapAndPrepare(
            _initialSwapParams,
            _amountIn,
            false
        );

        // Then, perform bridging
        IBridge(bridge).bridgeToEVM(
            _to,
            _chainId,
            _bridgeToken,
            _amountBridged,
            _destinationSwapParams
        );
    }

    function bridgeGasToEVM(
        address _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _initialSwapParams,
        IBridge.SwapParams calldata _destinationSwapParams
    ) external payable returns (uint256 _amountBridged) {
        // TODO: enforce consistency?? introduce _amountIn parameter

        require(
            _initialSwapParams.path.length > 0 &&
                _initialSwapParams.path[0] == WGAS,
            "Router: path needs to begin with WGAS"
        );

        // First, wrap GAS into WGAS
        _wrap(msg.value);

        // Then, perform swap on initial chain
        // Tokens(WGAS) are in the contract => isSelfSwap = true
        IERC20 _bridgeToken;
        (_bridgeToken, _amountBridged) = _swapAndPrepare(
            _initialSwapParams,
            msg.value,
            true
        );

        // Finally, perform bridging
        IBridge(bridge).bridgeToEVM(
            _to,
            _chainId,
            _bridgeToken,
            _amountBridged,
            _destinationSwapParams
        );
    }

    // -- BRIDGE FUNCTIONS [initial chain]: to non-EVM chains --

    function bridgeTokenToNonEVM(
        bytes32 _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _initialSwapParams,
        uint256 _amountIn
    ) external returns (uint256 _amountBridged) {
        // First, perform swap on initial chain
        // Need to pull tokens from caller => isSelfSwap = false
        IERC20 _bridgeToken;
        (_bridgeToken, _amountBridged) = _swapAndPrepare(
            _initialSwapParams,
            _amountIn,
            false
        );

        // Then, perform bridging
        IBridge(bridge).bridgeToNonEVM(
            _to,
            _chainId,
            _bridgeToken,
            _amountBridged
        );
    }

    function bridgeGasToNonEVM(
        bytes32 _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _initialSwapParams
    ) external payable returns (uint256 _amountBridged) {
        // TODO: enforce consistency?? introduce _amountIn parameter

        require(
            _initialSwapParams.path.length > 0 &&
                _initialSwapParams.path[0] == WGAS,
            "Router: path needs to begin with WGAS"
        );

        // First, wrap GAS into WGAS
        _wrap(msg.value);

        // Then, perform swap on initial chain
        // Tokens(WGAS) are in the contract => isSelfSwap = true
        IERC20 _bridgeToken;
        (_bridgeToken, _amountBridged) = _swapAndPrepare(
            _initialSwapParams,
            msg.value,
            true
        );

        // Finally, perform bridging
        IBridge(bridge).bridgeToNonEVM(
            _to,
            _chainId,
            _bridgeToken,
            _amountBridged
        );
    }

    // -- BRIDGE FUNCTIONS [initial chain]: internal helpers

    function _swapAndPrepare(
        IBridge.SwapParams calldata _initialSwapParams,
        uint256 _amountIn,
        bool _isSelfSwap
    )
        internal
        checkSwapParams(_initialSwapParams)
        returns (IERC20 _lastToken, uint256 _amountOut)
    {
        if (_isSwapPresent(_initialSwapParams)) {
            _amountOut = (_isSelfSwap ? _selfSwap : _swap)(
                address(this),
                _initialSwapParams.path,
                _initialSwapParams.adapters,
                _amountIn,
                _initialSwapParams.minAmountOut
            );

            _lastToken = _getLastToken(_initialSwapParams);
        } else {
            // checkSwapParams() checked that path.length == 1
            _lastToken = IERC20(_initialSwapParams.path[0]);

            if (_isSelfSwap) {
                // Tokens are already in the contract
                _amountOut = _amountIn;
            } else {
                // If tokens aren't in the contract, we need to pull them from caller
                // Use pulled amount as actual amount of tokens
                _amountOut = _pullTokenFromCaller(_lastToken, _amountIn);
            }
        }
        // Allow Bridge to spend token we got from the swap
        _setBridgeTokenAllowance(_lastToken, _amountOut);
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
        address _to,
        IERC20 _token,
        uint256 _amount
    ) external onlyBridge {
        // We don't check for reentrancy here as all the work is done

        // BUT Bridge contract might want to check
        // for reentrancy when calling refundToAddress()
        // Imagine [Bridge GAS & Swap] back to its native chain.
        // If swap fails, this unwrap WGAS and return GAS to user

        _returnTokensTo(_to, _token, _amount);
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
        address _to,
        IBridge.SwapParams calldata _swapParams,
        uint256 _amountIn
    ) external onlyBridge returns (uint256 _amountOut) {
        require(
            _swapParams.adapters.length <= bridgeMaxSwaps,
            "BridgeRouter: Too many swaps in path"
        );
        if (address(_getLastToken(_swapParams)) == WGAS) {
            // Path ends with WGAS, and no one wants
            // to receive WGAS after bridging, right?
            _amountOut = _selfSwap(
                address(this),
                _swapParams.path,
                _swapParams.adapters,
                _amountIn,
                _swapParams.minAmountOut
            );
            // this will unwrap WGAS and return GAS
            // reentrancy not an issue here, as all work is done
            _returnTokensTo(_to, IERC20(WGAS), _amountOut);
        } else {
            _amountOut = _selfSwap(
                _to,
                _swapParams.path,
                _swapParams.adapters,
                _amountIn,
                _swapParams.minAmountOut
            );
        }
    }

    // -- INTERNAL HELPERS --

    function _getLastToken(IBridge.SwapParams calldata _swapParams)
        internal
        pure
        returns (IERC20 _lastToken)
    {
        _lastToken = IERC20(_swapParams.path[_swapParams.path.length - 1]);
    }

    function _isSwapPresent(IBridge.SwapParams calldata _swapParams)
        internal
        pure
        returns (bool)
    {
        return _swapParams.adapters.length > 0;
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
    function _setBridgeTokenAllowance(IERC20 _bridgeToken, uint256 _amount)
        internal
    {
        _setTokenAllowance(_bridgeToken, _amount, bridge);
    }

    function _setTokenAllowance(
        IERC20 _token,
        uint256 _amount,
        address _spender
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
