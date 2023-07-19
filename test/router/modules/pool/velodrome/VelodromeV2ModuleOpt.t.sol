// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken, VelodromeV2Module} from "../../../../../contracts/router/modules/pool/velodrome/VelodromeV2Module.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract VelodromeV2ModuleOptTestFork is Test {
    LinkedPool public linkedPool;
    VelodromeV2Module public velodromeV2Module;

    // 2023-07-11
    uint256 public constant OPT_BLOCK_NUMBER = 106753037;

    // Velodrome V2 OP/USDC pool on Optimism
    address public constant VEL_V2_OPUSDC_POOL = 0x0df083de449F75691fc5A36477a6f3284C269108;

    // Velodrome V2 Router on Optimism
    address public constant VEL_V2_ROUTER = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858;

    // Native USDC on Optimism
    address public constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;

    // Native OP on Optimism
    address public constant OP = 0x4200000000000000000000000000000000000042;

    address public user;

    function setUp() public {
        string memory optRPC = vm.envString("OPTIMISM_API");
        vm.createSelectFork(optRPC, OPT_BLOCK_NUMBER);

        velodromeV2Module = new VelodromeV2Module(VEL_V2_ROUTER);
        linkedPool = new LinkedPool(OP);
        user = makeAddr("User");

        vm.label(VEL_V2_OPUSDC_POOL, "VelodromeV2OPUSDCPool");
        vm.label(OP, "OP");
        vm.label(USDC, "USDC");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = velodromeV2Module.getPoolTokens(VEL_V2_OPUSDC_POOL);
        assertEq(tokens.length, 2);
        assertEq(tokens[0], OP);
        assertEq(tokens[1], USDC);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: VEL_V2_OPUSDC_POOL, poolModule: address(velodromeV2Module)});
    }

    function testAddPool() public {
        addPool();
        assertEq(linkedPool.getToken(0), OP);
        assertEq(linkedPool.getToken(1), USDC);
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

    function testSwapFromOPtoUSDC() public {
        addPool();
        uint256 amount = 100 * 10**18;
        prepareUser(OP, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(OP).balanceOf(user), 0);
        assertEq(IERC20(USDC).balanceOf(user), amountOut);
    }

    function testSwapFromUSDCtoOP() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC).balanceOf(user), 0);
        assertEq(IERC20(OP).balanceOf(user), amountOut);
    }

    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        velodromeV2Module.poolSwap({
            pool: VEL_V2_OPUSDC_POOL,
            tokenFrom: IndexedToken({index: 0, token: OP}),
            tokenTo: IndexedToken({index: 1, token: USDC}),
            amountIn: 100 * 10**18
        });
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
