// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockBridgeModule} from "../mocks/MockBridgeModule.sol";
import {Action, ActionLib, BridgeToken, LimitedToken} from "../../../contracts/router/libs/Structs.sol";
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

        uint256 actionMask = ActionLib.mask(Action.Swap) |
            ActionLib.mask(Action.AddLiquidity) |
            ActionLib.mask(Action.RemoveLiquidity);
        LimitedToken[] memory limitedTokens = new LimitedToken[](4);
        limitedTokens[0] = LimitedToken({token: nexusDai, actionMask: actionMask});
        limitedTokens[1] = LimitedToken({token: nexusUsdc, actionMask: actionMask});
        limitedTokens[2] = LimitedToken({token: nexusUsdt, actionMask: actionMask});
        limitedTokens[3] = LimitedToken({token: nexusNusd, actionMask: ActionLib.mask(Action.RemoveLiquidity)});

        bridgeModuleL1 = new MockBridgeModule(bridgeTokens, limitedTokens);

        vm.prank(owner);
        router.connectBridgeModule(moduleIdL1, address(bridgeModuleL1));
    }

    function deployL2BridgeModule() public {
        // set up l2 bridge module
        // use l2 pools:
        //   - Default Pools: poolNethWeth, poolNusdUsdcEUsdt, poolUsdcUsdcE, poolUsdcEUsdt
        //   - Linked Pools: linkedPoolNusd, linkedPoolUsdc
        BridgeToken[] memory bridgeTokens = new BridgeToken[](6);
        bridgeTokens[0] = BridgeToken({token: neth, symbol: "nETH"});
        bridgeTokens[1] = BridgeToken({token: weth, symbol: "WETH"});
        bridgeTokens[2] = BridgeToken({token: nusd, symbol: "nUSD"});
        bridgeTokens[3] = BridgeToken({token: usdc, symbol: "USDC"});
        bridgeTokens[4] = BridgeToken({token: usdcE, symbol: "USDC.e"});
        bridgeTokens[5] = BridgeToken({token: usdt, symbol: "USDT"});

        uint256 actionMask = ActionLib.mask(Action.Swap) |
            ActionLib.mask(Action.AddLiquidity) |
            ActionLib.mask(Action.RemoveLiquidity);
        LimitedToken[] memory limitedTokens = new LimitedToken[](6);
        limitedTokens[0] = LimitedToken({token: neth, actionMask: ActionLib.allActions()});
        limitedTokens[1] = LimitedToken({token: weth, actionMask: ActionLib.allActions()});
        limitedTokens[2] = LimitedToken({token: nusd, actionMask: actionMask});
        limitedTokens[3] = LimitedToken({token: usdc, actionMask: actionMask});
        limitedTokens[4] = LimitedToken({token: usdcE, actionMask: actionMask});
        limitedTokens[5] = LimitedToken({token: usdt, actionMask: actionMask});

        bridgeModuleL2 = new MockBridgeModule(bridgeTokens, limitedTokens);

        vm.prank(owner);
        router.connectBridgeModule(moduleIdL2, address(bridgeModuleL2));
    }

    function testGetDestinationBridgeTokensL1Pool() public {
        // L2 => L1
        addL1Pool();
        deployL1BridgeModule();

        // TODO: fix
        BridgeToken[] memory expectedTokens = new BridgeToken[](2);
        expectedTokens[0] = BridgeToken({token: nexusDai, symbol: "ETH DAI"});
        expectedTokens[1] = BridgeToken({token: nexusNusd, symbol: "ETH nUSD"});

        BridgeToken[] memory actualTokens = router.getDestinationBridgeTokens(nexusDai);
        assertEq(expectedTokens.length, actualTokens.length);

        for (uint256 i = 0; i < actualTokens.length; i++) {
            BridgeToken memory expectedToken = expectedTokens[i];
            BridgeToken memory actualToken = actualTokens[i];

            assertEq(expectedToken.token, actualToken.token);
            assertEq(expectedToken.symbol, actualToken.symbol);
        }
    }

    function testGetDestinationBridgeTokensL2Pools() public {
        // L1 => L2
        addL2Pools();
        deployL2BridgeModule();

        // TODO: fix
        BridgeToken[] memory expectedTokens = new BridgeToken[](2);
        expectedTokens[0] = BridgeToken({token: nusd, symbol: "nUSD"});
        expectedTokens[1] = BridgeToken({token: usdcE, symbol: "USDC.e"});

        BridgeToken[] memory actualTokens = router.getDestinationBridgeTokens(usdcE);
        assertEq(expectedTokens.length, actualTokens.length);

        for (uint256 i = 0; i < actualTokens.length; i++) {
            BridgeToken memory expectedToken = expectedTokens[i];
            BridgeToken memory actualToken = actualTokens[i];

            assertEq(expectedToken.token, actualToken.token);
            assertEq(expectedToken.symbol, actualToken.symbol);
        }
    }
}
