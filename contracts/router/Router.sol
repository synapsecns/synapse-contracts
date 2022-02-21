// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAdapter} from "./interfaces/IAdapter.sol";
import {IRouter} from "./interfaces/IRouter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import {BasicRouter} from "./BasicRouter.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts-4.4.2/security/ReentrancyGuard.sol";

contract Router is ReentrancyGuard, BasicRouter, IRouter {
    using SafeERC20 for IERC20;

    address public bridge;

    constructor(
        address[] memory _adapters,
        address payable _wgas,
        address _bridge
    ) BasicRouter(_adapters, _wgas) {
        bridge = _bridge;
    }

    modifier onlyBridge {
        require(msg.sender == bridge, "Caller is not Bridge");

        _;
    }

    // -- SWAPPERS [single chain swaps] --

    function swap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256 _swappedAmount) {
        _swappedAmount = _swap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            msg.sender,
            _to
        );
    }

    function swapFromGAS(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external payable returns (uint256 _swappedAmount) {
        require(msg.value == _amountIn, "Router: incorrect amount of GAS");
        require(_path[0] == WGAS, "Router: Path needs to begin with WGAS");
        _wrap(_amountIn);
        // WGAS tokens need to be sent from this contract
        _swappedAmount = _selfSwap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            _to
        );
    }

    function swapToGAS(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256 _swappedAmount) {
        require(
            _path[_path.length - 1] == WGAS,
            "Router: Path needs to end with WGAS"
        );
        // This contract needs to receive WGAS in order to unwrap it
        _swappedAmount = _swap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            msg.sender,
            address(this)
        );
        _unwrap(_swappedAmount);
        // reentrancy not an issue here, as all work is done
        _returnTokensTo(GAS, _swappedAmount, _to);
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
        uint256 _swapAmount = _swap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            msg.sender,
            address(this)
        );
        _callBridge(_path[_path.length - 1], _swapAmount, _bridgeData);
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
        uint256 _swapAmount = _selfSwap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            address(this)
        );
        _callBridge(_path[_path.length - 1], _swapAmount, _bridgeData);
    }

    function _callBridge(
        address _bridgeToken,
        uint256 _bridgeAmount,
        bytes calldata _bridgeData
    ) internal {
        _setBridgeTokenAllowance(_bridgeToken, _bridgeAmount);
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
            This will return intermediate token (nUSD, nETH, ...) to the user
     */

    function refundToAddress(
        address _token,
        uint256 _amount,
        address _to
    ) external onlyBridge {
        // reentrancy not an issue here, as _token was
        // bridged to this chain, so it can't be WGAS
        _returnTokensTo(_token, _amount, _to);
    }

    function selfSwap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external onlyBridge returns (uint256 _swappedAmount) {
        if (_path[_path.length - 1] == WGAS) {
            // Path ends with WGAS, and no one wants
            // to receive WGAS after bridging, right?
            _swappedAmount = _selfSwap(
                _amountIn,
                _minAmountOut,
                _path,
                _adapters,
                address(this)
            );
            _unwrap(_swappedAmount);
            // reentrancy not an issue here, as all work is done
            _returnTokensTo(GAS, _swappedAmount, _to);
        } else {
            _swappedAmount = _selfSwap(
                _amountIn,
                _minAmountOut,
                _path,
                _adapters,
                _to
            );
        }
    }

    // -- INTERNAL SWAP FUNCTIONS --

    /// @dev All internal swap functions have a reentrancy guard

    /**
     * @notice Pull tokens from user and perform a series of swaps
     * @dev Use _selfSwap if tokens are already in the contract
     *      Don't do this: _from = address(this);
     * @return Final amount of tokens swapped
     */
    function _swap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _from,
        address _to
    ) internal nonReentrant returns (uint256) {
        require(
            _path.length == _adapters.length + 1,
            "Router: wrong amount of _adapters/tokens"
        );
        require(_to != address(0), "Router: incorrect _to address");
        IERC20(_path[0]).safeTransferFrom(
            _from,
            _getDepositAddress(_path, _adapters, 0),
            _amountIn
        );

        return _doChainedSwaps(_amountIn, _minAmountOut, _path, _adapters, _to);
    }

    /**
     * @notice Perform a series of swaps, assuming
     *         they are already deposited in this contract
     * @return Final amount of tokens swapped
     */
    function _selfSwap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) internal nonReentrant returns (uint256) {
        require(
            _path.length == _adapters.length + 1,
            "Router: wrong amount of _adapters/tokens"
        );
        require(_to != address(0), "Router: incorrect _to address");
        IERC20(_path[0]).safeTransfer(
            _getDepositAddress(_path, _adapters, 0),
            _amountIn
        );

        return _doChainedSwaps(_amountIn, _minAmountOut, _path, _adapters, _to);
    }

    /**
     * @notice Perform a series of swaps, assuming
     *         they have already been deposited in the first adapter
     * @return _amount Final amount of tokens swapped
     */
    function _doChainedSwaps(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) internal returns (uint256 _amount) {
        for (uint256 i = 0; i < _adapters.length; i++) {
            require(isTrustedAdapter[_adapters[i]], "Router: unknown adapter");
        }
        _amount = _amountIn;
        for (uint256 i = 0; i < _adapters.length; i++) {
            address _targetAddress = i < _adapters.length - 1
                ? _getDepositAddress(_path, _adapters, i + 1)
                : _to;
            _amount = IAdapter(_adapters[i]).swap(
                _amount,
                _path[i],
                _path[i + 1],
                _targetAddress
            );
        }
        require(_amount >= _minAmountOut, "Router: Insufficient output amount");
        emit Swap(_path[0], _path[_path.length - 1], _amountIn, _amount);
    }

    // -- INTERNAL HELPERS

    /**
     * @notice Get selected adapter's deposit address
     *
     * @dev Return value of address(0) means that
     *      adapter doesn't support this pair of tokens
     */
    function _getDepositAddress(
        address[] calldata _path,
        address[] calldata _adapters,
        uint256 _index
    ) internal view returns (address _depositAddress) {
        _depositAddress = IAdapter(_adapters[_index]).depositAddress(
            _path[_index],
            _path[_index + 1]
        );
        require(_depositAddress != address(0), "Adapter: unknown tokens");
    }

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
