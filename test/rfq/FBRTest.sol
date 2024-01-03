// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouter, IFastBridge, SwapQuery} from "../../contracts/rfq/FastBridgeRouter.sol";
import {Action, DefaultParams} from "../../contracts/router/libs/Structs.sol";

import {MockFastBridge} from "../mocks/MockFastBridge.sol";
import {MockDefaultPool} from "../mocks/MockDefaultPool.sol";

import {Test} from "forge-std/Test.sol";

abstract contract FBRTest is Test {
    uint256 constant RFQ_DEADLINE = 12 hours;
    address constant TOKEN_OUT = address(1337);
    uint256 constant FIXED_FEE = 0.01 ether;
    uint32 constant DST_CHAIN_ID = 420;

    FastBridgeRouter public router;
    MockFastBridge public fastBridge;
    address owner;

    MockDefaultPool public pool;

    address user;
    address recipient;

    function setUp() public virtual {
        owner = makeAddr("Owner");
        recipient = makeAddr("Recipient");
        user = makeAddr("User");
        fastBridge = new MockFastBridge();
        router = new FastBridgeRouter(address(fastBridge), owner);
    }

    function test_constructor() public {
        assertEq(address(router.fastBridge()), address(fastBridge));
        assertEq(router.owner(), owner);
    }

    function getOriginSwapParams(uint8 tokenIndexFrom, uint8 tokenIndexTo) public view returns (bytes memory) {
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: address(pool),
            tokenIndexFrom: tokenIndexFrom,
            tokenIndexTo: tokenIndexTo
        });
        return abi.encode(params);
    }

    function getOriginHandleETHParams() public pure returns (bytes memory) {
        DefaultParams memory params = DefaultParams({
            action: Action.HandleEth,
            pool: address(0),
            tokenIndexFrom: 0xFF,
            tokenIndexTo: 0xFF
        });
        return abi.encode(params);
    }

    function getDestQueryNoRebate(uint256 amount) public view returns (SwapQuery memory destQuery) {
        destQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: TOKEN_OUT,
            minAmountOut: amount - FIXED_FEE,
            deadline: block.timestamp + RFQ_DEADLINE,
            rawParams: ""
        });
    }

    function getDestQueryWithRebate(uint256 amount) public view returns (SwapQuery memory destQuery) {
        destQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: TOKEN_OUT,
            minAmountOut: amount - FIXED_FEE,
            deadline: block.timestamp + RFQ_DEADLINE,
            // TODO: encode "With gas rebate on destination chain"
            rawParams: ""
        });
    }

    function getExpectedBridgeParams(
        address originToken,
        uint256 originAmount,
        bool sendChainGas
    ) public view returns (IFastBridge.BridgeParams memory expectedParams) {
        expectedParams = IFastBridge.BridgeParams({
            dstChainId: DST_CHAIN_ID,
            sender: user,
            to: recipient,
            originToken: originToken,
            destToken: TOKEN_OUT,
            originAmount: originAmount,
            destAmount: originAmount - FIXED_FEE,
            sendChainGas: sendChainGas,
            deadline: block.timestamp + RFQ_DEADLINE
        });
    }

    function checkQueryNoAction(
        SwapQuery memory query,
        address token,
        uint256 amount
    ) internal {
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, token);
        assertEq(query.minAmountOut, amount);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, "");
    }

    function checkQueryWithAction(
        SwapQuery memory query,
        address token,
        uint256 amount,
        bytes memory rawParams
    ) internal {
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, token);
        assertEq(query.minAmountOut, amount);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, rawParams);
    }
}
