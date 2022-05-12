// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBridgeRouter} from "./interfaces/IBridgeRouter.sol";

import {ERC20Burnable} from "@openzeppelin/contracts-solc8/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import {IBridge} from "../vault/interfaces/IBridge.sol";

import {Router} from "./Router.sol";

// solhint-disable reason-string
// solhint-disable not-rely-on-time

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
        require(_bridgeMaxSwaps != 0, "Max swaps can't be 0");
        require(_bridgeMaxSwaps <= 4, "Max swaps too big");
        bridgeMaxSwaps = _bridgeMaxSwaps;
    }

    // -- BRIDGE FUNCTIONS [initial chain]: to EVM chains --

    function bridgeTokenToEVM(
        address to,
        uint256 chainId,
        IBridge.SwapParams calldata initialSwapParams,
        uint256 amountIn,
        IBridge.SwapParams calldata destinationSwapParams,
        bool gasdropRequested
    ) external returns (uint256 amountBridged) {
        // First, perform swap on initial chain
        // Need to pull tokens from caller => isSelfSwap = false
        IERC20 bridgeToken = _swapToBridge(initialSwapParams, amountIn, false);

        // Then, perform bridging
        amountBridged = IBridge(bridge).bridgeToEVM(
            to,
            chainId,
            bridgeToken,
            destinationSwapParams,
            gasdropRequested
        );
    }

    function bridgeGasToEVM(
        address to,
        uint256 chainId,
        IBridge.SwapParams calldata initialSwapParams,
        IBridge.SwapParams calldata destinationSwapParams,
        bool gasdropRequested
    ) external payable returns (uint256 amountBridged) {
        // TODO: enforce consistency?? introduce amountIn parameter

        require(
            initialSwapParams.path.length > 0 &&
                initialSwapParams.path[0] == WGAS,
            "Router: path needs to begin with WGAS"
        );

        // First, wrap GAS into WGAS
        _wrap(msg.value);

        // Then, perform swap on initial chain
        // Tokens(WGAS) are in the contract => isSelfSwap = true
        IERC20 bridgeToken = _swapToBridge(initialSwapParams, msg.value, true);

        // Finally, perform bridging
        amountBridged = IBridge(bridge).bridgeToEVM(
            to,
            chainId,
            bridgeToken,
            destinationSwapParams,
            gasdropRequested
        );
    }

    // -- BRIDGE FUNCTIONS [initial chain]: to non-EVM chains --

    function bridgeTokenToNonEVM(
        bytes32 to,
        uint256 chainId,
        IBridge.SwapParams calldata initialSwapParams,
        uint256 amountIn
    ) external returns (uint256 amountBridged) {
        // First, perform swap on initial chain
        // Need to pull tokens from caller => isSelfSwap = false
        IERC20 bridgeToken = _swapToBridge(initialSwapParams, amountIn, false);

        // Then, perform bridging
        amountBridged = IBridge(bridge).bridgeToNonEVM(
            to,
            chainId,
            bridgeToken
        );
    }

    function bridgeGasToNonEVM(
        bytes32 to,
        uint256 chainId,
        IBridge.SwapParams calldata initialSwapParams
    ) external payable returns (uint256 amountBridged) {
        // TODO: enforce consistency?? introduce amountIn parameter

        require(
            initialSwapParams.path.length > 0 &&
                initialSwapParams.path[0] == WGAS,
            "Router: path needs to begin with WGAS"
        );

        // First, wrap GAS into WGAS
        _wrap(msg.value);

        // Then, perform swap on initial chain
        // Tokens(WGAS) are in the contract => isSelfSwap = true
        IERC20 bridgeToken = _swapToBridge(initialSwapParams, msg.value, true);

        // Finally, perform bridging
        amountBridged = IBridge(bridge).bridgeToNonEVM(
            to,
            chainId,
            bridgeToken
        );
    }

    // -- BRIDGE FUNCTIONS [initial chain]: internal helpers

    function _swapToBridge(
        IBridge.SwapParams calldata initialSwapParams,
        uint256 amountIn,
        bool isSelfSwap
    ) internal checkSwapParams(initialSwapParams) returns (IERC20 lastToken) {
        if (_isSwapPresent(initialSwapParams)) {
            require(
                block.timestamp <= initialSwapParams.deadline,
                "Router: past deadline"
            );
            // Swap, and send swapped tokens to Bridge contract directly
            (isSelfSwap ? _selfSwap : _swap)(
                bridge,
                initialSwapParams.path,
                initialSwapParams.adapters,
                amountIn,
                initialSwapParams.minAmountOut
            );

            lastToken = _getLastToken(initialSwapParams);
        } else {
            // checkSwapParams() checked that path.length == 1
            lastToken = IERC20(initialSwapParams.path[0]);

            if (isSelfSwap) {
                // Tokens are in the contract, send them to Bridge
                lastToken.transfer(bridge, amountIn);
            } else {
                // If tokens aren't in the contract, we need to send them from caller to Bridge
                lastToken.safeTransferFrom(msg.sender, bridge, amountIn);
            }
        }
    }

    // -- BRIDGE RELATED FUNCTIONS [destination chain] --

    /**
        @notice refund tokens from unsuccessful swap back to user
        @dev This will return native GAS to user, if token = WGAS, so calling contract
             needs to check for reentrancy.
        @param token token to refund
        @param amount amount of tokens to refund
        @param to address to receive refund tokens
     */
    function refundToAddress(
        address to,
        IERC20 token,
        uint256 amount
    ) external onlyBridge {
        // We don't check for reentrancy here as all the work is done

        // BUT Bridge contract might want to check
        // for reentrancy when calling refundToAddress()
        // Imagine [Bridge GAS & Swap] back to its native chain.
        // If swap fails, this unwrap WGAS and return GAS to user

        _returnTokensTo(to, token, amount);
    }

    /**
        @notice Perform a series of swaps, assuming the starting tokens
                are already deposited in this contract
        @dev 1. This will revert if amount of adapters is too big, 
                bridgeMaxSwaps is usually lower than MAX_SWAPS
             2. Use BridgeQuoter.findBestPathDestinationChain() to correctly 
                find path with len(_adapters) <= bridgeMaxSwaps
             3. len(_path) = N, len(_adapters) = N - 1
        @param amountIn amount of initial tokens to swap
        @param to address to receive final tokens
        @return amountOut Final amount of tokens swapped
     */
    function postBridgeSwap(
        address to,
        IBridge.SwapParams calldata swapParams,
        uint256 amountIn
    ) external onlyBridge returns (uint256 amountOut) {
        require(
            swapParams.adapters.length <= bridgeMaxSwaps,
            "BridgeRouter: Too many swaps in path"
        );
        if (address(_getLastToken(swapParams)) == WGAS) {
            // Path ends with WGAS, and no one wants
            // to receive WGAS after bridging, right?
            amountOut = _selfSwap(
                address(this),
                swapParams.path,
                swapParams.adapters,
                amountIn,
                swapParams.minAmountOut
            );
            // this will unwrap WGAS and return GAS
            // reentrancy not an issue here, as all work is done
            _returnTokensTo(to, IERC20(WGAS), amountOut);
        } else {
            amountOut = _selfSwap(
                to,
                swapParams.path,
                swapParams.adapters,
                amountIn,
                swapParams.minAmountOut
            );
        }
    }

    // -- INTERNAL HELPERS --

    function _getLastToken(IBridge.SwapParams calldata swapParams)
        internal
        pure
        returns (IERC20 lastToken)
    {
        lastToken = IERC20(swapParams.path[swapParams.path.length - 1]);
    }

    function _isSwapPresent(IBridge.SwapParams calldata swapParams)
        internal
        pure
        returns (bool)
    {
        return swapParams.adapters.length > 0;
    }
}
