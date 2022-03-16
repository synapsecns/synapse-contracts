// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBridgeRouter} from "./interfaces/IBridgeRouter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

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

    // -- RESTRICTED SETTERS --

    function setBridgeMaxSwaps(uint8 _bridgeMaxSwaps)
        public
        onlyRole(GOVERNANCE_ROLE)
    {
        bridgeMaxSwaps = _bridgeMaxSwaps;
    }

    // -- BRIDGE RELATED FUNCTIONS [initial chain] --

    /** @dev
        Anyone interacting with BridgeRouter, willing to do a swap + bridge + swap is supposed to:

        1. [off-chain] use Quoter.getTradeDataAmountOut(_amountIn, _tokenIn, _bridgeToken, ...) on THIS chain 
           to get (_tradeData, _amountOut) for a swap from _amountIn [initial token -> bridge token].
           _tradeData will include _minAmountOut: estimated output (in bridged token) with max slippage
           user is willing to accept on this chain.
           _bridgeToken is address of bridge token on THIS chain

        2. [off-chain] use BridgeConfig on Ethereum Mainnet to get minBridgedAmount,
            which is _amountOut (assuming no slippage) after bridging fees.

        3. [off-chain] use BridgeQuoter.getBridgeDataAmountOut(_bridgeToken, minBridgeAmount, bridgedToken, tokenOut, ...)
           on DESTINATION chain to get (bridgeData, amountOut) for a swap from minBridgedAmount [bridgedToken -> tokenOut].
           _bridgeToken is address of bridge token on THIS chain
           bridgedToken is address of bridge token on DESTINATION chain

           bridgeData will include _minAmountOut: estimated output (in final token) with max slippage
           user is willing to accept for the whole [initial token -> final token] Swap&Bridge&Swap tx.
           Make sure to set slippage at least as much as in step 1.

        4. amountOut is the estimated final token output for Swap&Bridge&Swap, taking bridge fees into account,
           assuming no slippage on both swaps. Use this as "estimated amount" in the UI.
           
           _tradeData._minAmountOut: minimum amount of bridged token to receive after the first swap
           _bridgeData._minAmountOut: minimum amount of final token to receive after the second swap

        5. Unpack _tradeData and call BridgeRouter.swapAndBridge(
            ...(_tradeData),
            _bridgeData
        )

        6. Use BridgeRouter.swapFromGasAndBridge() with same params instead, 
           if you want to start from GAS
     */

    /// @dev Use this function, when doing a "swap into ETH and bridge" on Mainnet,
    /// as bridging from ETH Mainnet requires depositing WETH into bridge contract
    /// This is why there's no "swapToGasAndBridge()" implemented
    /// The same applies to "swap into BNB and bridge" on BNB,
    /// "swap into AVAX and bridge" on Avalanche, etc
    /**
        @notice Perform a series of swaps along the token path, using the provided Adapters,
                then bridge the final token
        @dev 1. Tokens will be pulled from msg.sender, so make sure Router has enough allowance to 
                 spend initial token. 
             2. Use Quoter -> _minAmountOut to set slippage.
             3. len(_path) = N, len(_adapters) = N - 1
             4. _bridgeData does NOT include amount of tokens, all swapped final tokens will be bridged
             5. Make sure final token (_path[N-1]) is supported by Bridge via _bridgeData
        @param _amountIn amount of initial tokens to swap
        @param _minAmountOut minimum amount of final tokens for a swap to be successful
        @param _path token path for the swap, path[0] = initial token, path[N - 1] = final token
        @param _adapters adapters that will be used for swap. _adapters[i]: swap _path[i] -> _path[i + 1]
        @param _bridgeData calldata for Bridge contract to perform a final bridge operation
        @return _amountOut amount of bridged tokens
     */
    function swapAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external returns (uint256 _amountOut) {
        _amountOut = _swap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            msg.sender,
            address(this)
        );
        _callBridge(_path[_path.length - 1], _amountOut, _bridgeData);
    }

    /**
        @notice Perform a series of swaps along the token path, starting with
                chain's native currency (GAS), using the provided Adapters, then bridge the final token.
        @dev 1. Make sure to set _amountIn = msg.value, _path[0] = WGAS
             2. Use Quoter -> _minAmountOut to set slippage.
             3. len(_path) = N, len(_adapters) = N - 1
             4. _bridgeData does NOT include amount of tokens, all swapped final tokens will be bridged
             5. Make sure final token (_path[N-1]) is supported by Bridge via _bridgeData
        @param _amountIn amount of initial tokens to swap
        @param _minAmountOut minimum amount of final tokens for a swap to be successful
        @param _path token path for the swap, path[0] = initial token, path[N - 1] = final token
        @param _adapters adapters that will be used for swap. _adapters[i]: swap _path[i] -> _path[i + 1]
        @param _bridgeData calldata for Bridge contract to perform a final bridge operation
        @return _amountOut amount of bridged tokens
     */
    function swapFromGasAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external payable returns (uint256 _amountOut) {
        require(msg.value == _amountIn, "Router: incorrect amount of GAS");
        require(_path[0] == WGAS, "Router: path needs to begin with WGAS");
        _wrap(_amountIn);
        // WGAS tokens need to be sent from this contract
        _amountOut = _selfSwap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            address(this)
        );
        _callBridge(_path[_path.length - 1], _amountOut, _bridgeData);
    }

    /**
        @notice Ask Synapse:Bridge to perform a bridge operation
        @param _bridgeToken token to bridge
        @param _bridgeAmount amount of tokens to bridge
        @param _bridgeData calldata for Bridge contract to perform a bridge operation
     */
    function _callBridge(
        address _bridgeToken,
        uint256 _bridgeAmount,
        bytes calldata _bridgeData
    ) internal {
        _setBridgeTokenAllowance(_bridgeToken, _bridgeAmount);
        // solhint-disable-next-line
        (bool success, ) = bridge.call(_bridgeData);
        require(success, "Bridge interaction failed");
    }

    // -- BRIDGE RELATED FUNCTIONS [destination chain] --

    /** @dev
        Bridge contract is supposed to 
        1. Transfer tokens (token: _path[0]; amount: _amountIn) to Router contract

        2. Call ROUTER.selfSwap(...)

        3. If swap succeeds, no need to do anything, tokens are at _to address
                If _path ends with WGAS, user will receive GAS instead of WGAS

        4. If selfSwap() reverts, bridge is supposed to call 
                refundToAddress(_path[0], _amountIn, _to);
            This will return bridged token (nUSD, nETH, ...) to the user
            (!!!) This will return GAS to user, when bridging WGAS back to its native chain
     */

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
        _returnTokensTo(_token, _amount, _to);
    }

    /**
        @notice Perform a series of swaps, assuming the starting tokens
                are already deposited in this contract
        @dev 1. This will revert if amount of adapters is too big, 
                bridgeMaxSwaps is usually lower than maxSwaps
             2. Use BridgeQuoter.getBridgeDataAmountOut -> _bridgeData to correctly 
                find path with len(_adapters) <= bridgeMaxSwaps and set slippage.
             3. len(_path) = N, len(_adapters) = N - 1
        @param _amountIn amount of initial tokens to swap
        @param _minAmountOut minimum amount of final tokens for a swap to be successful
        @param _path token path for the swap, path[0] = initial token, path[N - 1] = final token
        @param _adapters adapters that will be used for swap. _adapters[i]: swap _path[i] -> _path[i + 1]
        @param _to address to receive final tokens
        @return _amountOut Final amount of tokens swapped
     */
    function selfSwap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external onlyBridge returns (uint256 _amountOut) {
        require(
            _adapters.length <= bridgeMaxSwaps,
            "BridgeRouter: Too many swaps in path"
        );
        if (_path[_path.length - 1] == WGAS) {
            // Path ends with WGAS, and no one wants
            // to receive WGAS after bridging, right?
            _amountOut = _selfSwap(
                _amountIn,
                _minAmountOut,
                _path,
                _adapters,
                address(this)
            );
            // this will unwrap WGAS and return GAS
            // reentrancy not an issue here, as all work is done
            _returnTokensTo(WGAS, _amountOut, _to);
        } else {
            _amountOut = _selfSwap(
                _amountIn,
                _minAmountOut,
                _path,
                _adapters,
                _to
            );
        }
    }

    // -- INTERNAL HELPERS --

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
        IERC20 _token = IERC20(_bridgeToken);
        uint256 allowance = _token.allowance(address(this), bridge);
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. (c) openzeppelin
        if (allowance != 0) {
            _token.safeApprove(bridge, 0);
        }
        _token.safeApprove(bridge, _amount);
    }
}
