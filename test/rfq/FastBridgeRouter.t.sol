// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouter} from "../../contracts/rfq/FastBridgeRouter.sol";

import {MockFastBridge} from "../mocks/MockFastBridge.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockDefaultPool} from "../mocks/MockDefaultPool.sol";

import {Test} from "forge-std/Test.sol";

contract FastBridgeRouterTest is Test {
    FastBridgeRouter public router;
    MockFastBridge public fastBridge;
    address owner;

    MockERC20 public token0;
    MockERC20 public token1;

    MockDefaultPool public pool;

    function setUp() public {
        owner = makeAddr("Owner");
        fastBridge = new MockFastBridge();
        router = new FastBridgeRouter(address(fastBridge), owner);

        token0 = new MockERC20("T0", 18);
        token1 = new MockERC20("T1", 18);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        pool = new MockDefaultPool(tokens);
        // Mint some tokens to the pool
        token0.mint(address(pool), 100 ether);
        token1.mint(address(pool), 120 ether);
    }

    function test_constructor() public {
        assertEq(address(router.fastBridge()), address(fastBridge));
        assertEq(router.owner(), owner);
    }

    function test_bridge_withoutOriginSwap() public {
        // TODO
    }

    function test_bridge_withOriginSwap() public {
        // TODO
    }

    function test_getOriginAmountOut() public {
        // TODO
    }
}
