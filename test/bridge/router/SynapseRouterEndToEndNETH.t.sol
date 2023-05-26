// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./SynapseRouterSuite.t.sol";
import {Swap} from "../../utils/Utilities06.sol";
import {LendingPoolMock} from "./mocks/AaveMock.t.sol";
import {AaveSwapWrapper} from "./mocks/AaveMock.t.sol";

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
contract SynapseRouterEndToEndNETHTest is SynapseRouterSuite {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         OVERRIDES: AAVE POOL                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function deployPool(
        ChainSetup memory chain,
        IERC20[] memory tokens,
        uint256 seedAmount
    ) public virtual override returns (address pool) {
        if (!equals(chain.name, "AVA") || tokens[0] != chain.neth) {
            return super.deployPool(chain, tokens, seedAmount);
        }
        LendingPoolMock lendingPool = new LendingPoolMock();
        IERC20 aWETH = deployERC20(chain, "aWETH", 18);
        mintInitialTestTokens(chain, address(lendingPool), address(chain.weth), aWETH.totalSupply());
        Ownable(address(aWETH)).transferOwnership(address(lendingPool));
        lendingPool.addToken(address(aWETH), address(chain.weth));
        tokens[1] = aWETH;
        // Deploy nETH + aWETH pool
        address aavePool = super.deployPool(chain, tokens, seedAmount);
        tokens[1] = chain.weth;
        // Deploy Aave Swap Wrapper and use it as the pool for SwapQuoter
        AaveSwapWrapper _pool = new AaveSwapWrapper(Swap(aavePool), tokens, address(lendingPool), address(this));
        pool = address(_pool);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TESTS: ETH -> L2 (FROM ETH)                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_ethereumToOptimism_inETH_outNETH() public {
        // Prepare test parameters: Ethereum ETH -> Optimism nETH
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.neth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        depositEvent = DepositEvent(TO, OPT_CHAINID, address(origin.weth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_ethereumToOptimism_inETH_outETH() public {
        // Prepare test parameters: Ethereum ETH -> Optimism ETH
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
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
            token: address(origin.weth),
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

    function test_ethereumToOptimism_inETH_outWETH() public {
        // Prepare test parameters: Ethereum ETH -> Optimism WETH (will receive ETH instead)
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.weth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
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
            token: address(origin.weth),
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
    ▏*║                     TESTS: ETH -> L2 (FROM WETH)                     ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_ethereumToOptimism_inWETH_outNETH() public {
        // Prepare test parameters: Ethereum WETH -> Optimism nETH
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.weth;
        IERC20 tokenOut = destination.neth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        depositEvent = DepositEvent(TO, OPT_CHAINID, address(origin.weth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_ethereumToOptimism_inWETH_outETH() public {
        // Prepare test parameters: Ethereum WETH -> Optimism ETH
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.weth;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
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
            token: address(origin.weth),
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

    function test_ethereumToOptimism_inWETH_outWETH() public {
        // Prepare test parameters: Ethereum WETH -> Optimism WETH (will receive ETH instead)
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[OPT_CHAINID];
        IERC20 tokenIn = origin.weth;
        IERC20 tokenOut = destination.weth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
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
            token: address(origin.weth),
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

    function test_optimismToEthereum_inNETH_outETH() public {
        // Prepare test parameters: Optimism nETH -> Ethereum ETH
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.neth;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.weth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToEthereum_inNETH_outWETH() public {
        // Prepare test parameters: Optimism nETH -> Ethereum WETH (will receive ETH instead)
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.neth;
        IERC20 tokenOut = destination.weth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.weth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToEthereum_inETH_outETH() public {
        // Prepare test parameters: Optimism ETH -> Ethereum ETH
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.weth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToEthereum_inETH_outWETH() public {
        // Prepare test parameters: Optimism ETH -> Ethereum WETH (will receive ETH instead)
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.weth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.weth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToEthereum_inWETH_outETH() public {
        // Prepare test parameters: Optimism WETH -> Ethereum ETH
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.weth;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.weth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToEthereum_inWETH_outWETH() public {
        // Prepare test parameters: Optimism WETH -> Ethereum WETH (will receive ETH instead)
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.weth;
        IERC20 tokenOut = destination.weth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.weth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TESTS: L2 -> L2 (FROM NETH)                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_optimismToArbitrum_inNETH_outNETH() public {
        // Prepare test parameters: Optimism nETH -> Arbitrum nETH
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.neth;
        IERC20 tokenOut = destination.neth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ARB_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToArbitrum_inNETH_outETH() public {
        // Prepare test parameters: Optimism nETH -> Arbitrum ETH
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.neth;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
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
            token: address(origin.neth),
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

    function test_optimismToArbitrum_inNETH_outWETH() public {
        // Prepare test parameters: Optimism nETH -> Arbitrum WETH (will receive ETH instead)
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.neth;
        IERC20 tokenOut = destination.weth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
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
            token: address(origin.neth),
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

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      TESTS: L2 -> L2 (FROM ETH)                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_optimismToArbitrum_inETH_outNETH() public {
        // Prepare test parameters: Optimism ETH -> Arbitrum nETH
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.neth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ARB_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToArbitrum_inETH_outETH() public {
        // Prepare test parameters: Optimism ETH -> Arbitrum ETH
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
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
            token: address(origin.neth),
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

    function test_optimismToArbitrum_inETH_outWETH() public {
        // Prepare test parameters: Optimism ETH -> Arbitrum WETH (will receive ETh instead)
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.weth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
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
            token: address(origin.neth),
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

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TESTS: L2 -> L2 (FROM WETH)                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_optimismToArbitrum_inWETH_outNETH() public {
        // Prepare test parameters: Optimism WETH -> Arbitrum nETH
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.weth;
        IERC20 tokenOut = destination.neth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ARB_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_optimismToArbitrum_inWETH_outETH() public {
        // Prepare test parameters: Optimism WETH -> Arbitrum ETH
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.weth;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
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
            token: address(origin.neth),
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

    function test_optimismToArbitrum_inWETH_outWETH() public {
        // Prepare test parameters: Optimism WETH -> Arbitrum WETH (will receive ETH instead)
        ChainSetup memory origin = chains[OPT_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = origin.weth;
        IERC20 tokenOut = destination.weth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
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
            token: address(origin.neth),
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

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      TESTS: AVALANCHE AAVE WETH                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_avalancheToEthereum_inNETH_outETH() public {
        // Prepare test parameters: Avalanche nETH -> Ethereum ETH
        ChainSetup memory origin = chains[AVA_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.neth;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.weth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_avalancheToEthereum_inWETH_outETH() public {
        // Prepare test parameters: Avalanche WETH -> Ethereum ETH
        ChainSetup memory origin = chains[AVA_CHAINID];
        ChainSetup memory destination = chains[ETH_CHAINID];
        IERC20 tokenIn = origin.weth;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.weth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, ETH_CHAINID, address(origin.neth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_ethereumToAvalanche_inETH_outNETH() public {
        // Prepare test parameters: Ethereum ETH -> Avalanche nETH
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[AVA_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.neth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        depositEvent = DepositEvent(TO, AVA_CHAINID, address(origin.weth), originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_ethereumToAvalanche_inETH_outWETH() public {
        // Prepare test parameters: Ethereum ETH -> Avalanche WETH
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[AVA_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = destination.weth;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.neth);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        depositAndSwapEvent = DepositAndSwapEvent({
            to: TO,
            chainId: AVA_CHAINID,
            token: address(origin.weth),
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
}
