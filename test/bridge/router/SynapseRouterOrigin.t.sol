// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./SynapseRouterSuite.t.sol";

/**
 * @notice Tests for making sure that the correct Bridge event is emitted
 * upon SynapseRouter interaction on origin chain.
 * Every pre-existing function in (L1/L2)BridgeZap is covered.
 */
// solhint-disable func-name-mixedcase
contract SynapseRouterOriginTest is SynapseRouterSuite {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TESTS: BRIDGE, NO SWAPS                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/
    /// @notice Bridge tests (no swaps) are prefixed test_b

    function test_b_deposit() public {
        // Prepare test parameters: Ethereum nUSD -> Optimism nUSD
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.nusd;
        uint256 amountIn = 10**18;
        depositEvent = DepositEvent(TO, OPT_CHAINID, address(origin.nusd), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    function test_b_depositETH() public {
        // Prepare test parameters: Ethereum ETH -> Optimism nETH
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.neth;
        uint256 amountIn = 10**18;
        depositEvent = DepositEvent(TO, OPT_CHAINID, address(origin.weth), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    function test_b_redeem() public {
        // Prepare test parameters: Optimism nUSD -> Ethereum nUSD
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.nusd;
        uint256 amountIn = 10**18;
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.nusd), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         TESTS: SWAP & BRIDGE                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/
    /// @notice Swap & Bridge tests are prefixed test_sb

    function test_sb_swapAndRedeem() public {
        // Prepare test parameters: Optimism USDC -> Ethereum nUSD
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.nusd;
        uint256 amountIn = 10**6;
        // Peek pool swap quotes
        (SwapQuery memory originQuery, ) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.nusd), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    function test_sb_swapETHAndRedeem() public {
        // Prepare test parameters: Optimism ETH -> Ethereum ETH
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        // Peek pool swap quotes
        (SwapQuery memory originQuery, ) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    function test_sb_zapAndDeposit() public {
        // Prepare test parameters: Ethereum USDC -> Optimism nUSD
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.nusd;
        uint256 amountIn = 10**6;
        // Peek pool swap quotes
        (SwapQuery memory originQuery, ) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        depositEvent = DepositEvent(TO, OPT_CHAINID, address(origin.nusd), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         TESTS: BRIDGE & SWAP                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/
    /// @notice Bridge & Swap tests are prefixed test_bs

    function test_bs_depositAndSwap() public {
        // Prepare test parameters: Ethereum nUSD -> Optimism USDC
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**18;
        // Peek pool swap quotes
        (, SwapQuery memory destQuery) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        depositAndSwapEvent = DepositAndSwapEvent({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(origin.nusd),
            amount: amountIn,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositAndSwapEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    function test_bs_depositETHAndSwap() public {
        // Prepare test parameters: Ethereum ETH -> Optimism ETH
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        // Peek pool swap quotes
        (, SwapQuery memory destQuery) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        depositAndSwapEvent = DepositAndSwapEvent({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(origin.weth),
            amount: amountIn,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositAndSwapEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    function test_bs_redeemAndSwap() public {
        // Prepare test parameters: Arbitrum nUSD -> Optimism USDC
        ChainSetup memory origin = chains[ARB_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**18;
        // Peek pool swap quotes
        (, SwapQuery memory destQuery) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        redeemAndSwapEvent = RedeemAndSwapEvent({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(origin.nusd),
            amount: amountIn,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemAndSwapEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    function test_bs_redeemAndRemove() public {
        // Prepare test parameters: Optimism nUSD -> Ethereum USDC
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**18;
        (, SwapQuery memory destQuery) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        redeemAndRemoveEvent = RedeemAndRemoveEvent({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(origin.nusd),
            amount: amountIn,
            swapTokenIndex: 1,
            swapMinAmount: destQuery.minAmountOut,
            swapDeadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemAndRemoveEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TESTS: SWAP & BRIDGE & SWAP                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/
    /// @notice Swap & Bridge & Swap tests are prefixed test_sbs

    function test_sbs_swapAndRedeemAndSwap() public {
        // Prepare test parameters: Arbitrum USDC -> Optimism USDC
        ChainSetup memory origin = chains[ARB_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**6;
        // Peek pool swap quotes
        SwapQuery memory originQuery;
        SwapQuery memory destQuery;
        (originQuery, destQuery) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        redeemAndSwapEvent = RedeemAndSwapEvent({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(origin.nusd),
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemAndSwapEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    function test_sbs_swapETHAndRedeemAndSwap() public {
        // Prepare test parameters: Arbitrum ETH -> Optimism ETH
        ChainSetup memory origin = chains[ARB_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        // Peek pool swap quotes
        SwapQuery memory originQuery;
        SwapQuery memory destQuery;
        (originQuery, destQuery) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        redeemAndSwapEvent = RedeemAndSwapEvent({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(origin.neth),
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemAndSwapEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    function test_sbs_swapAndRedeemAndRemove() public {
        // Prepare test parameters: Optimism USDC -> Ethereum USDC
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**6;
        // Peek pool swap quotes
        SwapQuery memory originQuery;
        SwapQuery memory destQuery;
        (originQuery, destQuery) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        redeemAndRemoveEvent = RedeemAndRemoveEvent({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(origin.nusd),
            amount: originQuery.minAmountOut,
            swapTokenIndex: 1,
            swapMinAmount: destQuery.minAmountOut,
            swapDeadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemAndRemoveEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }

    function test_sbs_zapAndDepositAndSwap() public {
        // Prepare test parameters: Ethereum USDC -> Optimism USDC
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**6;
        // Peek pool swap quotes
        SwapQuery memory originQuery;
        SwapQuery memory destQuery;
        (originQuery, destQuery) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        depositAndSwapEvent = DepositAndSwapEvent({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(origin.nusd),
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositAndSwapEvent, origin, destination, tokenIn, tokenOut, amountIn);
    }
}
