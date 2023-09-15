// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockBridgeModule} from "../mocks/MockBridgeModule.sol";
import {MockFailedBridgeModule} from "../mocks/MockFailedBridgeModule.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC20TransferFees} from "../mocks/MockERC20TransferFees.sol";
import {Action, ActionLib, BridgeToken, DefaultParams, LimitedToken, SwapQuery} from "../../../contracts/router/libs/Structs.sol";
import {SynapseRouterV2} from "../../../contracts/router/SynapseRouterV2.sol";

import {BasicSynapseRouterV2Test} from "./BasicSynapseRouterV2.t.sol";

// solhint-disable func-name-mixedcase
contract SynapseRouterV2BridgeViaSynapseTest is BasicSynapseRouterV2Test {
    bytes32 public constant moduleId = keccak256("MOCK_BRIDGE");
    bytes32 public constant failedModuleId = keccak256("FAILED_BRIDGE");

    address public teth; // transfer fee eth

    MockBridgeModule public bridgeModule;

    event Deposit(address recipient, uint256 chainId, address token, uint256 amount, bytes params);

    function deployBridgeModule() public {
        // set up the bridge module
        BridgeToken[] memory bridgeTokens = new BridgeToken[](1);
        bridgeTokens[0] = BridgeToken({token: neth, symbol: "MOCK_NETH"});

        LimitedToken[] memory limitedTokens = new LimitedToken[](1);
        limitedTokens[0] = LimitedToken({token: neth, actionMask: ActionLib.allActions()});

        bridgeModule = new MockBridgeModule(bridgeTokens, limitedTokens);

        vm.prank(owner);
        router.connectBridgeModule(moduleId, address(bridgeModule));
    }

    function deployFailedBridgeModule() public {
        // set up the bridge module
        BridgeToken[] memory bridgeTokens = new BridgeToken[](1);
        bridgeTokens[0] = BridgeToken({token: neth, symbol: "MOCK_NETH"});

        LimitedToken[] memory limitedTokens = new LimitedToken[](1);
        limitedTokens[0] = LimitedToken({token: neth, actionMask: ActionLib.allActions()});

        MockFailedBridgeModule failedBridgeModule = new MockFailedBridgeModule(bridgeTokens, limitedTokens);

        vm.prank(owner);
        router.connectBridgeModule(failedModuleId, address(failedBridgeModule));
    }

    function deployBridgeModuleTransferFees() public {
        // deploy transfer fee mock token
        teth = address(new MockERC20TransferFees("tETH", 18, 0.005e10));

        // set up the bridge module
        BridgeToken[] memory bridgeTokens = new BridgeToken[](1);
        bridgeTokens[0] = BridgeToken({token: teth, symbol: "MOCK_TETH"});

        LimitedToken[] memory limitedTokens = new LimitedToken[](1);
        limitedTokens[0] = LimitedToken({token: teth, actionMask: ActionLib.allActions()});

        bridgeModule = new MockBridgeModule(bridgeTokens, limitedTokens);

        vm.prank(owner);
        router.connectBridgeModule(moduleId, address(bridgeModule));
    }

    function testBridgeViaSynapse() public {
        deployBridgeModule();

        address to = address(0xA);
        uint256 chainId = 42161;
        address token = neth;
        uint256 amount = 1e18;

        prepareUser(token, amount);

        // no origin adapter involved
        SwapQuery memory originQuery;
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(router), // "router" on dest chain
            tokenOut: weth,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: getSwapParams(address(poolNethWeth), 0, 1)
        });

        // test event emitted by mock bridge
        bytes memory params = bridgeModule.formatQuery(destQuery);
        vm.expectEmit();
        emit Deposit(to, chainId, token, amount, params);

        vm.prank(user);
        router.bridgeViaSynapse(to, chainId, moduleId, token, amount, originQuery, destQuery);

        // test token pulled and transferred to mock bridge
        address bridge = address(bridgeModule.bridge());
        assertEq(MockERC20(token).balanceOf(bridge), amount);
    }

    function testBridgeViaSynapse_hasAdapterOriginQuery() public {
        deployBridgeModule();
        addL2Pools(); // L2 => L1

        address to = address(0xA);
        uint256 chainId = 1;
        address token = weth;
        uint256 amount = 1e18;

        prepareUser(token, amount);

        // origin adapter should swap weth for neth
        address tokenOut = neth;
        uint256 amountOut = quoter
            .getAmountOut(LimitedToken({token: weth, actionMask: ActionLib.allActions()}), tokenOut, amount)
            .minAmountOut;
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router), // "router" on origin chain
            tokenOut: neth,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: getSwapParams(address(poolNethWeth), 1, 0)
        });
        SwapQuery memory destQuery;

        // test event emitted by mock bridge
        bytes memory params = bridgeModule.formatQuery(destQuery);
        vm.expectEmit();
        emit Deposit(to, chainId, tokenOut, amountOut, params);

        vm.prank(user);
        router.bridgeViaSynapse(to, chainId, moduleId, token, amount, originQuery, destQuery);

        // test token pulled and transferred to mock bridge
        address bridge = address(bridgeModule.bridge());
        assertEq(MockERC20(tokenOut).balanceOf(bridge), amountOut);
    }

    function testBridgeViaSynapse_tokenHasTransferFees() public {
        deployBridgeModuleTransferFees();
        addL2Pools(); // L2 => L1

        address to = address(0xA);
        uint256 chainId = 1;
        address token = teth;
        uint256 amount = 1e18;

        prepareUser(token, amount);

        // no origin or dest adapter involved
        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        vm.prank(user);
        router.bridgeViaSynapse(to, chainId, moduleId, token, amount, originQuery, destQuery);

        // two hops: one in to router, another in to bridge
        uint256 feeRate = MockERC20TransferFees(token).feeRate();
        uint256 feeDecimals = MockERC20TransferFees(token).FEE_DECIMALS();

        uint256 amountFeesRouter = (amount * feeRate) / feeDecimals;
        amount -= amountFeesRouter;

        uint256 amountFeesBridge = (amount * feeRate) / feeDecimals;
        amount -= amountFeesBridge;

        uint256 amountFees = amountFeesRouter + amountFeesBridge;

        // test token pulled and transferred to mock bridge
        address bridge = address(bridgeModule.bridge());
        assertEq(MockERC20(token).balanceOf(bridge), amount);

        // test transfer fees taken
        assertEq(MockERC20(token).balanceOf(MockERC20TransferFees(token).owner()), amountFees);
    }

    function testBridgeViaSynapse_revert_moduleNotExists() public {
        // don't deploy the bridge module
        address to = address(0xA);
        uint256 chainId = 42161;
        address token = neth;
        uint256 amount = 1e18;

        prepareUser(token, amount);

        // no adapters involved
        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        vm.expectRevert(SynapseRouterV2.SynapseRouterV2__ModuleNotExists.selector);
        vm.prank(user);
        router.bridgeViaSynapse(to, chainId, moduleId, token, amount, originQuery, destQuery);
    }

    function testBridgeViaSynapse_revert_bridgeFailed() public {
        deployFailedBridgeModule();

        address to = address(0xA);
        uint256 chainId = 42161;
        address token = neth;
        uint256 amount = 1e18;

        prepareUser(token, amount);

        // no adapters involved
        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        vm.expectRevert("Failed");
        vm.prank(user);
        router.bridgeViaSynapse(to, chainId, failedModuleId, token, amount, originQuery, destQuery);
    }
}
