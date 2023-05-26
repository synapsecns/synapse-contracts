// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./SynapseRouterSuite.t.sol";

// solhint-disable func-name-mixedcase
contract SynapseRouterEndToEndNUSDTest is SynapseRouterSuite {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           TESTS: ETH -> L2                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_ethereumToOptimism_inNUSD_outNUSD() public {
        // Prepare test parameters: Ethereum nUSD -> Optimism nUSD
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.nusd;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        depositEvent = DepositEvent(TO, OPT_CHAINID, address(origin.nusd), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_ethereumToOptimism_inNUSD_outUSDC() public {
        // Prepare test parameters: Ethereum nUSD -> Optimism USDC
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
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
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_ethereumToOptimism_inUSDC_outNUSD() public {
        // Prepare test parameters: Ethereum USDC -> Optimism nUSD
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.nusd;
        uint256 amountIn = 10**6;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        depositEvent = DepositEvent(TO, OPT_CHAINID, address(origin.nusd), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_ethereumToOptimism_inUSDC_outUSDC() public {
        // Prepare test parameters: Ethereum USDC -> Optimism USDC
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**6;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
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
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        TESTS: L2 -> ETHEREUM                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_optimismToEthereum_inNUSD_outNUSD() public {
        // Prepare test parameters: Optimism nUSD -> Ethereum nUSD
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.nusd;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.nusd), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToEthereum_inNUSD_outUSDC() public {
        // Prepare test parameters: Optimism nUSD -> Ethereum nUSD
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
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
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToEthereum_inUSDC_outNUSD() public {
        // Prepare test parameters: Optimism USDC -> Ethereum nUSD
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.nusd;
        uint256 amountIn = 10**6;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.nusd), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToEthereum_inUSDC_outUSDC() public {
        // Prepare test parameters: Optimism USDC -> Ethereum nUSD
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**6;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
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
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           TESTS: L2 <> L2                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_optimismToArbitrum_inNUSD_outNUSD() public {
        // Prepare test parameters: Optimism nUSD -> Arbitrum nUSD
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.nusd;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ARB_CHAINID, address(origin.nusd), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToArbitrum_inNUSD_outUSDC() public {
        // Prepare test parameters: Optimism nUSD -> Arbitrum USDC
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.nusd;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemAndSwapEvent = RedeemAndSwapEvent({
            to: TO,
            chainId: ARB_CHAINID,
            token: address(origin.nusd),
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemAndSwapEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToArbitrum_inUSDC_outNUSD() public {
        // Prepare test parameters: Optimism USDC -> Arbitrum nUSD
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.nusd;
        uint256 amountIn = 10**6;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ARB_CHAINID, address(origin.nusd), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToArbitrum_inUSDC_outUSDC() public {
        // Prepare test parameters: Optimism USDC -> Arbitrum USDC
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.usdc;
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**6;
        address bridgeTokenDest = address(destination.nusd);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemAndSwapEvent = RedeemAndSwapEvent({
            to: TO,
            chainId: ARB_CHAINID,
            token: address(origin.nusd),
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemAndSwapEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }
}
