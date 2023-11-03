// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../../../utils/IntegrationUtils.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken, CurveV1Module} from "../../../../../contracts/router/modules/pool/curve/CurveV1Module.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract CurveV1ModuleEthTestFork is IntegrationUtils {
    LinkedPool public linkedPool;
    CurveV1Module public curveV1Module;

    // 2023-11-03
    uint256 public constant ETH_BLOCK_NUMBER = 18490000;

    // Curve V1 FRAX/USDC pool (2pool) on Ethereum
    address public constant CURVE_V1_FRAX_POOL = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    // Native USDC on Ethereum
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // Native FRAX on Ethereum
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

    address public user;

    constructor() IntegrationUtils("mainnet", "CurveV1Module", ETH_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        curveV1Module = new CurveV1Module();
        linkedPool = new LinkedPool(USDC, address(this));
        user = makeAddr("User");

        vm.label(CURVE_V1_FRAX_POOL, "CurveV12Pool");
        vm.label(USDC, "USDC");
        vm.label(FRAX, "USDC.e");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = curveV1Module.getPoolTokens(CURVE_V1_FRAX_POOL);
        assertEq(tokens.length, 2);
        assertEq(tokens[0], FRAX);
        assertEq(tokens[1], USDC);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: CURVE_V1_FRAX_POOL, poolModule: address(curveV1Module)});
    }

    function testAddPool() public {
        addPool();
        assertEq(linkedPool.getToken(0), USDC);
        assertEq(linkedPool.getToken(1), FRAX);
    }

    // ════════════════════════════════════════════════ TESTS: SWAP ════════════════════════════════════════════════════

    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 amount
    ) public returns (uint256 amountOut) {
        vm.prank(user);
        amountOut = linkedPool.swap({
            nodeIndexFrom: tokenIndexFrom,
            nodeIndexTo: tokenIndexTo,
            dx: amount,
            minDy: 0,
            deadline: type(uint256).max
        });
    }

    function testSwapFromUSDCtoFRAX() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC).balanceOf(user), 0);
        assertEq(IERC20(FRAX).balanceOf(user), amountOut);
    }

    function testSwapFromFRAXtoUSDC() public {
        addPool();
        uint256 amount = 100 * 10**18;
        prepareUser(FRAX, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(FRAX).balanceOf(user), 0);
        assertEq(IERC20(USDC).balanceOf(user), amountOut);
    }

    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        curveV1Module.poolSwap({
            pool: CURVE_V1_FRAX_POOL,
            tokenFrom: IndexedToken({index: 0, token: USDC}),
            tokenTo: IndexedToken({index: 1, token: FRAX}),
            amountIn: 100 * 10**6
        });
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
