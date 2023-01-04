// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./SynapseRouterE2E.t.sol";

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
contract SynapseRouterNethE2ETest is SynapseRouterE2E {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TESTS: ETH -> L2 (FROM ETH)                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_ethereumToOptimism_inETH_outNETH() public {
        // Prepare test parameters
        Chain memory origin = chains[ETH_CHAINID];
        Chain memory destination = chains[OPT_CHAINID];
        bool startFromETH = true; // ASSET IN: ETH
        IERC20 tokenIn = origin.weth; // TOKEN IN: WETH
        IERC20 tokenOut = destination.neth; // TOKEN OUT: NETH; ASSET OUT: NETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenDeposit(TO, OPT_CHAINID, bridgeTokenOrigin, originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_ethereumToOptimism_inETH_outETH() public {
        // Prepare test parameters
        Chain memory origin = chains[ETH_CHAINID];
        Chain memory destination = chains[OPT_CHAINID];
        bool startFromETH = true; // ASSET IN: ETH
        IERC20 tokenIn = origin.weth; // TOKEN IN: WETH
        IERC20 tokenOut = destination.weth; // TOKEN OUT: WETH; ASSET OUT: ETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenDepositAndSwap({
            to: TO,
            chainId: OPT_CHAINID,
            token: bridgeTokenOrigin,
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: block.timestamp + DELAY
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TESTS: ETH -> L2 (FROM WETH)                     ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_ethereumToOptimism_inWETH_outNETH() public {
        // Prepare test parameters
        Chain memory origin = chains[ETH_CHAINID];
        Chain memory destination = chains[OPT_CHAINID];
        bool startFromETH = false;
        IERC20 tokenIn = origin.weth; // TOKEN IN: WETH
        IERC20 tokenOut = destination.neth; // TOKEN OUT: NETH; ASSET OUT: NETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenDeposit(TO, OPT_CHAINID, bridgeTokenOrigin, originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_ethereumToOptimism_inWETH_outETH() public {
        // Prepare test parameters
        Chain memory origin = chains[ETH_CHAINID];
        Chain memory destination = chains[OPT_CHAINID];
        bool startFromETH = false;
        IERC20 tokenIn = origin.weth; // TOKEN IN: WETH
        IERC20 tokenOut = destination.weth; // TOKEN OUT: WETH; ASSET OUT: ETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenDepositAndSwap({
            to: TO,
            chainId: OPT_CHAINID,
            token: bridgeTokenOrigin,
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: block.timestamp + DELAY
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        TESTS: L2 -> ETHEREUM                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_optimismToEthereum_inNETH_outETH() public {
        // Prepare test parameters
        Chain memory origin = chains[OPT_CHAINID];
        Chain memory destination = chains[ETH_CHAINID];
        bool startFromETH = false;
        IERC20 tokenIn = origin.neth; // TOKEN IN: NETH
        IERC20 tokenOut = destination.weth; // TOKEN OUT: WETH; ASSET OUT: ETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ETH_CHAINID, bridgeTokenOrigin, originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToEthereum_inETH_outETH() public {
        // Prepare test parameters
        Chain memory origin = chains[OPT_CHAINID];
        Chain memory destination = chains[ETH_CHAINID];
        bool startFromETH = true; // ASSET IN: ETH
        IERC20 tokenIn = origin.weth; // TOKEN IN: WETH
        IERC20 tokenOut = destination.weth; // TOKEN OUT: WETH; ASSET OUT: ETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ETH_CHAINID, bridgeTokenOrigin, originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToEthereum_inWETH_outETH() public {
        // Prepare test parameters
        Chain memory origin = chains[OPT_CHAINID];
        Chain memory destination = chains[ETH_CHAINID];
        bool startFromETH = false;
        IERC20 tokenIn = origin.weth; // TOKEN IN: WETH
        IERC20 tokenOut = destination.weth; // TOKEN OUT: WETH; ASSET OUT: ETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ETH_CHAINID, bridgeTokenOrigin, originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TESTS: L2 -> L2 (FROM NETH)                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_optimismToArbitrum_inNETH_outNETH() public {
        // Prepare test parameters
        Chain memory origin = chains[OPT_CHAINID];
        Chain memory destination = chains[ARB_CHAINID];
        bool startFromETH = false;
        IERC20 tokenIn = origin.neth; // TOKEN IN: NETH
        IERC20 tokenOut = destination.neth; // TOKEN OUT: NETH; ASSET OUT: NETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ARB_CHAINID, bridgeTokenOrigin, originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToArbitrum_inNETH_outETH() public {
        // Prepare test parameters
        Chain memory origin = chains[OPT_CHAINID];
        Chain memory destination = chains[ARB_CHAINID];
        bool startFromETH = false;
        IERC20 tokenIn = origin.neth; // TOKEN IN: NETH
        IERC20 tokenOut = destination.weth; // TOKEN OUT: WETH; ASSET OUT: ETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndSwap({
            to: TO,
            chainId: ARB_CHAINID,
            token: bridgeTokenOrigin,
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: block.timestamp + DELAY
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      TESTS: L2 -> L2 (FROM ETH)                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_optimismToArbitrum_inETH_outNETH() public {
        // Prepare test parameters
        Chain memory origin = chains[OPT_CHAINID];
        Chain memory destination = chains[ARB_CHAINID];
        bool startFromETH = true; // ASSET IN: ETH
        IERC20 tokenIn = origin.weth; // TOKEN IN: WETH
        IERC20 tokenOut = destination.neth; // TOKEN OUT: NETH; ASSET OUT: NETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ARB_CHAINID, bridgeTokenOrigin, originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToArbitrum_inETH_outETH() public {
        // Prepare test parameters
        Chain memory origin = chains[OPT_CHAINID];
        Chain memory destination = chains[ARB_CHAINID];
        bool startFromETH = true; // ASSET IN: ETH
        IERC20 tokenIn = origin.weth; // TOKEN IN: WETH
        IERC20 tokenOut = destination.weth; // TOKEN OUT: WETH; ASSET OUT: ETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndSwap({
            to: TO,
            chainId: ARB_CHAINID,
            token: bridgeTokenOrigin,
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: block.timestamp + DELAY
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TESTS: L2 -> L2 (FROM WETH)                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_optimismToArbitrum_inWETH_outNETH() public {
        // Prepare test parameters
        Chain memory origin = chains[OPT_CHAINID];
        Chain memory destination = chains[ARB_CHAINID];
        bool startFromETH = false;
        IERC20 tokenIn = origin.weth; // TOKEN IN: WETH
        IERC20 tokenOut = destination.neth; // TOKEN OUT: NETH; ASSET OUT: NETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ARB_CHAINID, bridgeTokenOrigin, originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToArbitrum_inWETH_outETH() public {
        // Prepare test parameters
        Chain memory origin = chains[OPT_CHAINID];
        Chain memory destination = chains[ARB_CHAINID];
        bool startFromETH = false;
        IERC20 tokenIn = origin.weth; // TOKEN IN: WETH
        IERC20 tokenOut = destination.weth; // TOKEN OUT: WETH; ASSET OUT: ETH
        address bridgeTokenOrigin = origin.bridgeTokenEth;
        address bridgeTokenDest = destination.bridgeTokenEth;
        uint256 amountIn = 10**18;
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndSwap({
            to: TO,
            chainId: ARB_CHAINID,
            token: bridgeTokenOrigin,
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: destQuery.minAmountOut,
            deadline: block.timestamp + DELAY
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, startFromETH, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }
}
