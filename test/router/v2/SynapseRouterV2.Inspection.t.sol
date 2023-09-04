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

        uint256 actionMask = ActionLib.mask(Action.RemoveLiquidity, Action.HandleEth);
        LimitedToken[] memory limitedTokens = new LimitedToken[](4);
        limitedTokens[0] = LimitedToken({token: nexusDai, actionMask: actionMask});
        limitedTokens[1] = LimitedToken({token: nexusUsdc, actionMask: actionMask});
        limitedTokens[2] = LimitedToken({token: nexusUsdt, actionMask: actionMask});
        limitedTokens[3] = LimitedToken({token: nexusNusd, actionMask: actionMask});

        bridgeModuleL1 = new MockBridgeModule(bridgeTokens, limitedTokens);

        vm.prank(owner);
        router.connectBridgeModule(moduleIdL1, address(bridgeModuleL1));
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

    function testGetOriginBridgeTokensL2Pool() public {
        // L2 => L1
        addL2Pools();
        deployL2BridgeModule();

        BridgeToken[] memory expectedTokens = new BridgeToken[](1);
        expectedTokens[0] = BridgeToken({token: nusd, symbol: "nUSD"});

        BridgeToken[] memory actualTokens = router.getOriginBridgeTokens(usdcE);

        assertEq(expectedTokens.length, actualTokens.length);
        checkBridgeTokens(expectedTokens, actualTokens);
    }
}
