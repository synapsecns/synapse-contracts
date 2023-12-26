// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouter} from "../../contracts/rfq/FastBridgeRouter.sol";

import {MockFastBridge} from "../mocks/MockFastBridge.sol";

import {Test} from "forge-std/Test.sol";

contract FastBridgeRouterTest is Test {
    FastBridgeRouter public router;
    MockFastBridge public fastBridge;
    address owner;

    function setUp() public {
        owner = makeAddr("Owner");
        fastBridge = new MockFastBridge();
        router = new FastBridgeRouter(address(fastBridge), owner);
    }

    function test_constructor() public {
        assertEq(address(router.fastBridge()), address(fastBridge));
        assertEq(router.owner(), owner);
    }

    function test_bridge() public {
        // TODO
    }

    function test_getOriginAmountOut() public {
        // TODO
    }
}
