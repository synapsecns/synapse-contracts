// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockBridgeModule} from "../mocks/MockBridgeModule.sol";
import {Action, ActionLib, BridgeToken, LimitedToken, DestRequest, SwapQuery} from "../../../contracts/router/libs/Structs.sol";
import {UniversalTokenLib} from "../../../contracts/router/libs/UniversalToken.sol";
import {SynapseRouterV2} from "../../../contracts/router/SynapseRouterV2.sol";

import {BasicSynapseRouterV2Test} from "./BasicSynapseRouterV2.t.sol";

// solhint-disable func-name-mixedcase
contract SynapseRouterV2InspectionTest is BasicSynapseRouterV2Test {
    bytes32 public constant moduleIdL1 = keccak256("L1 MODULE");
    bytes32 public constant moduleIdL2 = keccak256("L2 MODULE");

    MockBridgeModule public bridgeModuleL1;
    MockBridgeModule public bridgeModuleL2;

    function deployL1BridgeModule() public {
        // set up the l1 bridge module
        // use l1 pools: nexusPoolDaiUsdcUsdt
        BridgeToken[] memory bridgeTokens = new BridgeToken[](4);
        bridgeTokens[0] = BridgeToken({token: nexusDai, symbol: "ETH DAI"});
        bridgeTokens[1] = BridgeToken({token: nexusUsdc, symbol: "ETH USDC"});
        bridgeTokens[2] = BridgeToken({token: nexusUsdt, symbol: "ETH USDT"});
        bridgeTokens[3] = BridgeToken({token: nexusNusd, symbol: "ETH nUSD"});

        uint256 actionMask = ActionLib.mask(Action.RemoveLiquidity, Action.HandleEth);
        LimitedToken[] memory limitedTokens = new LimitedToken[](4);
        limitedTokens[0] = LimitedToken({token: nexusDai, actionMask: actionMask});
        limitedTokens[1] = LimitedToken({token: nexusUsdc, actionMask: actionMask});
        limitedTokens[2] = LimitedToken({token: nexusUsdt, actionMask: actionMask});
        limitedTokens[3] = LimitedToken({token: nexusNusd, actionMask: actionMask});

        bridgeModuleL1 = new MockBridgeModule(bridgeTokens, limitedTokens);

        vm.prank(owner);
        router.connectBridgeModule(moduleIdL1, address(bridgeModuleL1));

        vm.label(nexusDai, "ETH DAI");
        vm.label(nexusUsdc, "ETH USDC");
        vm.label(nexusUsdt, "ETH USDT");
        vm.label(nexusNusd, "ETH nUSD");
    }

    function deployL2BridgeModule() public {
        // set up l2 bridge module
        // use l2 pools:
        //   - Default Pools: poolNethWeth, poolNusdUsdcEUsdt, poolUsdcUsdcE, poolUsdcEUsdt
        //   - Linked Pools: linkedPoolNusd, linkedPoolUsdc
        BridgeToken[] memory bridgeTokens = new BridgeToken[](2);
        bridgeTokens[0] = BridgeToken({token: neth, symbol: "nETH"});
        bridgeTokens[1] = BridgeToken({token: nusd, symbol: "nUSD"});

        LimitedToken[] memory limitedTokens = new LimitedToken[](2);
        limitedTokens[0] = LimitedToken({token: neth, actionMask: ActionLib.mask(Action.Swap)});
        limitedTokens[1] = LimitedToken({token: nusd, actionMask: ActionLib.mask(Action.Swap)});

        bridgeModuleL2 = new MockBridgeModule(bridgeTokens, limitedTokens);

        vm.prank(owner);
        router.connectBridgeModule(moduleIdL2, address(bridgeModuleL2));

        vm.label(neth, "nETH");
        vm.label(nusd, "nUSD");
        vm.label(usdcE, "USDC.e");
        vm.label(usdt, "USDT");
        vm.label(usdc, "USDC");
        vm.label(weth, "WETH");
        vm.label(UniversalTokenLib.ETH_ADDRESS, "ETH");
    }

    function checkBridgeTokens(BridgeToken[] memory expectedTokens, BridgeToken[] memory actualTokens) public {
        for (uint256 i = 0; i < actualTokens.length; i++) {
            BridgeToken memory expectedToken = expectedTokens[i];
            BridgeToken memory actualToken = actualTokens[i];

            assertEq(expectedToken.token, actualToken.token);
            assertEq(expectedToken.symbol, actualToken.symbol);
        }
    }

    function testGetDestinationBridgeTokensL1Pool() public {
        // L2 => L1
        addL1Pool();
        deployL1BridgeModule();

        BridgeToken[] memory expectedTokens = new BridgeToken[](2);
        expectedTokens[0] = BridgeToken({token: nexusDai, symbol: "ETH DAI"});
        expectedTokens[1] = BridgeToken({token: nexusNusd, symbol: "ETH nUSD"});

        BridgeToken[] memory actualTokens = router.getDestinationBridgeTokens(nexusDai);

        assertEq(expectedTokens.length, actualTokens.length);
        checkBridgeTokens(expectedTokens, actualTokens);
    }

    function testGetDestinationBridgeTokensL2Pools() public {
        // L1 => L2
        addL2Pools();
        deployL2BridgeModule();

        BridgeToken[] memory expectedTokens = new BridgeToken[](1);
        expectedTokens[0] = BridgeToken({token: nusd, symbol: "nUSD"});

        BridgeToken[] memory actualTokens = router.getDestinationBridgeTokens(usdcE);

        assertEq(expectedTokens.length, actualTokens.length);
        checkBridgeTokens(expectedTokens, actualTokens);
    }

    function testGetOriginBridgeTokensL1Pool() public {
        // L1 => L2
        addL1Pool();
        deployL1BridgeModule();

        BridgeToken[] memory expectedTokens = new BridgeToken[](4);
        expectedTokens[0] = BridgeToken({token: nexusDai, symbol: "ETH DAI"});
        expectedTokens[1] = BridgeToken({token: nexusUsdc, symbol: "ETH USDC"});
        expectedTokens[2] = BridgeToken({token: nexusUsdt, symbol: "ETH USDT"});
        expectedTokens[3] = BridgeToken({token: nexusNusd, symbol: "ETH nUSD"});

        BridgeToken[] memory actualTokens = router.getOriginBridgeTokens(nexusDai);

        assertEq(expectedTokens.length, actualTokens.length);
        checkBridgeTokens(expectedTokens, actualTokens);
    }

    function testGetOriginBridgeTokensL2Pools() public {
        // L2 => L1
        addL2Pools();
        deployL2BridgeModule();

        BridgeToken[] memory expectedTokens = new BridgeToken[](1);
        expectedTokens[0] = BridgeToken({token: nusd, symbol: "nUSD"});

        BridgeToken[] memory actualTokens = router.getOriginBridgeTokens(usdcE);

        assertEq(expectedTokens.length, actualTokens.length);
        checkBridgeTokens(expectedTokens, actualTokens);
    }

    function checkSupportedTokens(address[] memory expectedTokens, address[] memory actualTokens) public {
        for (uint256 i = 0; i < actualTokens.length; i++) {
            address expectedToken = expectedTokens[i];
            address actualToken = actualTokens[i];
            assertEq(expectedToken, actualToken);
        }
    }

    function testGetSupportedTokensL1Pool() public {
        // L1
        addL1Pool();
        deployL1BridgeModule();

        address[] memory expectedTokens = new address[](4);
        expectedTokens[0] = nexusDai;
        expectedTokens[1] = nexusUsdc;
        expectedTokens[2] = nexusUsdt;
        expectedTokens[3] = nexusNusd;

        address[] memory actualTokens = router.getSupportedTokens();

        assertEq(expectedTokens.length, actualTokens.length);
        checkSupportedTokens(expectedTokens, actualTokens);
    }

    function testGetSupportedTokensL2Pools() public {
        // L2
        addL2Pools();
        deployL2BridgeModule();

        // @dev usdc not included in supported tokens as not in a pool paired w bridge token
        address[] memory expectedTokens = new address[](6);
        expectedTokens[0] = neth;
        expectedTokens[1] = weth;
        expectedTokens[2] = nusd;
        expectedTokens[3] = usdcE;
        expectedTokens[4] = usdt;
        expectedTokens[5] = UniversalTokenLib.ETH_ADDRESS; // added since WETH in supported list

        address[] memory actualTokens = router.getSupportedTokens();

        assertEq(expectedTokens.length, actualTokens.length);
        checkSupportedTokens(expectedTokens, actualTokens);
    }

    function checkSwapQueries(SwapQuery[] memory expectedQueries, SwapQuery[] memory actualQueries) public {
        for (uint256 i = 0; i < actualQueries.length; i++) {
            SwapQuery memory expectedQuery = expectedQueries[i];
            SwapQuery memory actualQuery = actualQueries[i];

            assertEq(expectedQuery.routerAdapter, actualQuery.routerAdapter);
            assertEq(expectedQuery.tokenOut, actualQuery.tokenOut);
            assertEq(expectedQuery.minAmountOut, actualQuery.minAmountOut);
            assertEq(expectedQuery.deadline, actualQuery.deadline);
            assertEq(expectedQuery.rawParams, actualQuery.rawParams);
        }
    }

    function testGetDestinationAmountOutL2Pools() public {
        // L1 => L2
        addL2Pools();
        deployL2BridgeModule();

        uint256 rate = 0.0001e10; // 1 bps
        bridgeModuleL2.setFeeRate(neth, rate);

        uint256 maxBridgedAmount = 100e18;
        bridgeModuleL2.setMaxBridgedAmount(neth, maxBridgedAmount);

        uint256 amountIn = 1000000000000000000; // 1 wad
        DestRequest[] memory requests = new DestRequest[](1);
        requests[0] = DestRequest({symbol: "nETH", amountIn: amountIn});
        address tokenOut = weth;

        SwapQuery[] memory expectedQueries = new SwapQuery[](1);
        expectedQueries[0] = SwapQuery({
            routerAdapter: address(router), // default pool
            tokenOut: weth,
            minAmountOut: 999800019849755190, // 0.9998 wad
            deadline: type(uint256).max,
            rawParams: getSwapParams(address(poolNethWeth), 0, 1)
        });

        SwapQuery[] memory actualQueries = router.getDestinationAmountOut(requests, weth);

        assertEq(expectedQueries.length, actualQueries.length);
        checkSwapQueries(expectedQueries, actualQueries);
    }

    function testGetOriginAmountOutL2Pools() public {
        // L2 => L1
        addL2Pools();
        deployL2BridgeModule();

        uint256 rate = 0.0001e10; // 1 bps
        bridgeModuleL2.setFeeRate(neth, rate);

        uint256 maxBridgedAmount = 100e18;
        bridgeModuleL2.setMaxBridgedAmount(neth, maxBridgedAmount);

        address tokenIn = weth;
        string[] memory tokenSymbols = new string[](1);
        tokenSymbols[0] = "nETH";
        uint256 amountIn = 1000000000000000000; // 1 wad

        SwapQuery[] memory expectedQueries = new SwapQuery[](1);
        expectedQueries[0] = SwapQuery({
            routerAdapter: address(router), // default pool
            tokenOut: neth,
            minAmountOut: 999702966365812232, // 0.9997 wad
            deadline: type(uint256).max,
            rawParams: getSwapParams(address(poolNethWeth), 1, 0)
        });

        SwapQuery[] memory actualQueries = router.getOriginAmountOut(tokenIn, tokenSymbols, amountIn);

        assertEq(expectedQueries.length, actualQueries.length);
        checkSwapQueries(expectedQueries, actualQueries);
    }
}
