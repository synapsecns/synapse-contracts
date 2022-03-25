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
        >>> PARAMS

        IC = Initial Chain
        DC = Destination Chain

        addressDC: user address on DC

        chainIdDC: chainId of DC

        gasPriceIC: estimation for gas price on IC, in wei
        gasPriceDC: estimation for gas price on DC, in wei

        tokenIn: initial token on IC
        amountIn: amount of initial tokens
        
        bridgeTokenIC: intermediate (bridge) token on IC
        amountOutIC: estimated amount of bridge token received after swap on IC

        slippageIC: max slippage % user can tolerate on IC
        minAmountOutIC: minimum received on IC after swap, or tx will be reverted

        bridgeTokenDC: intermediate (bridge) token on DC
        amountInDC: estimated amount of bridge token received after bridging to DC

        tokenOut: final token on DC
        amountOut: estimated amount of final token received after swap on DC

        slippageTotal: max slippage % user can tolerate for the whole tokenIn -> tokenOut swap
        minAmountOut: minimum received on DC after swap, or user will receive bridgeTokenDC instead

        >>> SLIPPAGE SETTINGS

        Practically, for the sake of simplicity:
            slippageIC = slippageTotal
        
        On chains, where trade with high slippage is likely to be sandwiched:
            slippageIC = slippageTotal * X%, where X = ~50%

        >>> GENERAL BRIDGE FLOW

        1. tokenIn -> bridgeTokenIC swap on IC
        2. bridgeTokenIC is bridged to DC, where its address is bridgeTokenDC
        3. bridgeTokenDC -> tokenOut swap on DC

        >>> HOW TO: SWAP + BRIDGE + SWAP

        1. [off-chain on IC]
            bestOfferIC = BridgeQuoter.findBestPathInitialChain(amountIn, tokenIn, bridgeTokenIC, gasPriceIC);
            amountOutIC = bestOfferIC.amounts[bestOfferIC.amounts.length - 1];

        2. [off-chain on Ethereum]
            bridgeFees = BridgeConfig.calculateSwapFee(bridgeTokenDC, chainIdDC, amountOutIC)
            amountInDC = max(amountOutIC - bridgeFees, 0)

        3. [off-chain on DC] 
            bestOfferDC = BridgeQuoter.findBestPathDestinationChain(amountInDC, bridgeTokenDC, tokenOut, gasPriceDC);
            amountOutDC = bestOfferDC.amounts[bestOfferDC.amounts.length - 1];

        4. Apply slippage
            minAmountOutIC = applySlippage(amountOutIC, slippageIC);
            minAmountOutDC = applySlippage(amountOutDC, slippageTotal);

        5. Figure out selectorIC: selector for Synapse: Bridge function, 
        that is used for bridging bridgeTokenIC from IC to DC.

        Might be eventually supported by BridgeConfig, but has to be done manually for now.
        
        6. bridgeDataIC = ethers.abi.encodeWithSelector(
            selectorIC,
            addressDC,
            chainIdDC,
            bridgeTokenIC,
            minAmountOutDC,
            bestOfferDC.path,
            bestOfferDC.adapters
        );

        7. [on-chain on IC]
            BridgeRouter.swapAndBridge(
                amountIn,
                minAmountOutIC,
                bestOfferIC.path,
                bestOfferIC.adapters,
                bridgeDataIC
            );

        7a. Use BridgeRouter.swapFromGasAndBridge() with same params instead, 
        if you want to start from GAS

        7b. Use BridgeRouter.bridgeToken(bridgeTokenIC, amountIn, bridgeData) instead,
        if no swap on IC is needed, i.e. user starts from already supported token on IC
    */

    /**
        @notice Pull a token from user, then perform a bridging transaction
        @dev 1. Tokens will be pulled from msg.sender, so make sure Router has enough allowance to 
                spend bridged token. 
             2. _bridgeData does NOT include amount of tokens.
             3. Make sure bridged token is supported by Bridge.call(_bridgeData)
        @param _bridgeToken token to bridge
        @param _bridgeAmount amount tokens to bridge
        @param _bridgeData calldata for Bridge contract to perform a final bridge operation
     */
    function bridgeToken(
        IERC20 _bridgeToken,
        uint256 _bridgeAmount,
        bytes calldata _bridgeData
    ) external {
        // First, pull token from user
        _bridgeToken.safeTransferFrom(msg.sender, address(this), _bridgeAmount);
        // Then, perform bridging
        _callBridge(address(_bridgeToken), _bridgeAmount, _bridgeData);
    }

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
             2. len(_path) = N, len(_adapters) = N - 1
             3. _bridgeData does NOT include amount of tokens, all swapped final tokens will be bridged
             4. Make sure final token (_path[N-1]) is supported by Bridge.call(_bridgeData)
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
        // First, do the swap on this chain
        _amountOut = _swap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            address(this)
        );
        // Then, perform bridging
        _callBridge(_path[_path.length - 1], _amountOut, _bridgeData);
    }

    /**
        @notice Perform a series of swaps along the token path, starting with
                chain's native currency (GAS), using the provided Adapters, then bridge the final token.
        @dev 1. Make sure to set _amountIn = msg.value, _path[0] = WGAS
             2. len(_path) = N, len(_adapters) = N - 1
             3. _bridgeData does NOT include amount of tokens, all swapped final tokens will be bridged
             4. Make sure final token (_path[N-1]) is supported by Bridge.call(_bridgeData)
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
        // First, wrap GAS into WGAS
        _wrap(_amountIn);
        // Then, swap WGAS on this chain
        // WGAS is in this contract, thus _selfSwap()
        _amountOut = _selfSwap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            address(this)
        );
        // Then, perform bridging
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
        // First, allow bridge to spend exactly _bridgeAmount
        _setBridgeTokenAllowance(_bridgeToken, _bridgeAmount);
        // Do the actual bridging
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
             2. Use BridgeQuoter.findBestPathDestinationChain() to correctly 
                find path with len(_adapters) <= bridgeMaxSwaps
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
