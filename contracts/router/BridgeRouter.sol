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
        Anyone interacting with Router, willing to do a swap + bridge is supposed to
        1. Query [off-chain] this Router to get (_amountOut, _path, _adapters)
           for a swap from _amountIn [initial token -> bridge token]

        2. Add reasonable slippage to _amountOut -> _minAmountOut

        3. Query [off-chain] BridgeConfig to get minBridgedAmount,
           which is _minAmountOut after bridging fees

        4. Query [off-chain] Router on destination chain to get (amountOutDest, pathDest, adaptersDest)
           for a swap from minBridgedAmount [bridge token -> destination token]

        5. Add reasonable slippage to amountOutDest -> _minBridgedAmountOut

        6. Construct bridgeData: 
            a. use selector for either depositMaxAndSwap [deposit-withdraw bridge token]
               or redeemMaxAndSwap [burn-mint bridge token]
            b. provide data for swap on destination chain: 
                    (_minBridgedAmountOut, pathDest, adaptersDest)

        7. Call swapAndBridge(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            _bridgeData
        )

        8. Use swapFromGasAndBridge with same params instead, 
           if you want to start from GAS
     */

    /// @dev Use this function, when doing a "swap into ETH and bridge" on Mainnet,
    /// as bridging from ETH Mainnet requires depositing WETH into bridge contract
    /// This is why there's so "swapToGasAndBridge()" implemented
    /// The same applies to "swap into BNB and bridge" on BNB,
    /// "swap into AVAX and bridge" on Avalanche, etc
    function swapAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external {
        uint256 _amountOut = _swap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            msg.sender,
            address(this)
        );
        _callBridge(_path[_path.length - 1], _amountOut, _bridgeData);
    }

    function swapFromGasAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external payable {
        require(msg.value == _amountIn, "Router: incorrect amount of GAS");
        require(_path[0] == WGAS, "Router: path needs to begin with WGAS");
        _wrap(_amountIn);
        // WGAS tokens need to be sent from this contract
        uint256 _amountOut = _selfSwap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            address(this)
        );
        _callBridge(_path[_path.length - 1], _amountOut, _bridgeData);
    }

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
			Check for reentrancy in the contract that is calling refundToAddress()
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
     * @notice Set approval for bridge to spend Router's _bridgeToken
     *
     * @dev This uses a finite _amount rather than UINT_MAX, so
     *      Bridge's function redeemMax (depositMax) will be able to
     *      pull exactly as much tokens as we need
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
