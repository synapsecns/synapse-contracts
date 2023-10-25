// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../../../utils/IntegrationUtils.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken, CurveV1Module} from "../../../../../contracts/router/modules/pool/curve/CurveV1Module.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract CurveV1ModuleBaseTestFork is IntegrationUtils {
    LinkedPool public linkedPool;
    CurveV1Module public curveV1Module;

    // 2023-10-25
    uint256 public constant BASE_BLOCK_NUMBER = 5729000;

    // Curve V1 USDC/USDcB/axlUSDC/crvUSD pool (4pool) on Base
    address public constant CURVE_V1_4POOL = 0xf6C5F01C7F3148891ad0e19DF78743D31E390D1f;

    // Native USDC on Base
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Base-Bridged USDC on Base
    address public constant USD_B_C = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;

    // Axelar-wrapped USDC on Base
    address public constant AXL_USDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;

    // Base-Bridged crvUSD on Base
    address public constant CRV_USD = 0x417Ac0e078398C154EdFadD9Ef675d30Be60Af93;

    address public user;

    constructor() IntegrationUtils("base", "CurveV1Module", BASE_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        curveV1Module = new CurveV1Module();
        linkedPool = new LinkedPool(USDC, address(this));
        user = makeAddr("User");

        vm.label(CURVE_V1_4POOL, "CurveV1Pool");
        vm.label(USDC, "USDC");
        vm.label(USD_B_C, "USDbC");
        vm.label(AXL_USDC, "axlUSDC");
        vm.label(CRV_USD, "crvUSD");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = curveV1Module.getPoolTokens(CURVE_V1_4POOL);
        assertEq(tokens.length, 4);
        assertEq(tokens[0], USDC);
        assertEq(tokens[1], USD_B_C);
        assertEq(tokens[2], AXL_USDC);
        assertEq(tokens[3], CRV_USD);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: CURVE_V1_4POOL, poolModule: address(curveV1Module)});
    }

    function testAddPool() public {
        addPool();
        assertEq(linkedPool.getToken(0), USDC);
        assertEq(linkedPool.getToken(1), USD_B_C);
        assertEq(linkedPool.getToken(2), AXL_USDC);
        assertEq(linkedPool.getToken(3), CRV_USD);
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

    function testSwapFromUSDCtoUSDbC() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC).balanceOf(user), 0);
        assertEq(IERC20(USD_B_C).balanceOf(user), amountOut);
    }

    function testSwapFromUSDbCtoUSDC() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USD_B_C, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USD_B_C).balanceOf(user), 0);
        assertEq(IERC20(USDC).balanceOf(user), amountOut);
    }

    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        curveV1Module.poolSwap({
            pool: CURVE_V1_4POOL,
            tokenFrom: IndexedToken({index: 0, token: USDC}),
            tokenTo: IndexedToken({index: 1, token: USD_B_C}),
            amountIn: 100 * 10**6
        });
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
