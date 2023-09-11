// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {IndexedToken, LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {TraderJoeV21Module} from "../../../../../contracts/router/modules/pool/traderjoe/TraderJoeV21Module.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract TraderJoeV21ModuleAvaxTestFork is Test {
    LinkedPool public linkedPool;
    TraderJoeV21Module public traderJoeModule;

    // 2023-09-05
    uint256 public constant AVAX_BLOCK_NUMBER = 34807165;

    // Trader Joe V2.1 Router on Avalanche
    address public constant LB_ROUTER = 0xb4315e873dBcf96Ffd0acd8EA43f689D8c20fB30;

    // Trader Joe V2.1 USDT/USDC Pool on Avalanche
    address public constant LB_POOL = 0x9B2Cc8E6a2Bbb56d6bE4682891a91B0e48633c72;

    // Native USDT on Avalanche
    address public constant USDT = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;

    // Native USDC on Avalanche
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    address public user;

    function setUp() public {
        string memory avaxRPC = vm.envString("AVALANCHE_API");
        vm.createSelectFork(avaxRPC, AVAX_BLOCK_NUMBER);

        traderJoeModule = new TraderJoeV21Module(LB_ROUTER);
        linkedPool = new LinkedPool(USDT, address(this));
        user = makeAddr("User");

        vm.label(LB_ROUTER, "LBRouter");
        vm.label(LB_POOL, "LBPool");

        vm.label(USDT, "USDT");
        vm.label(USDC, "USDC");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = traderJoeModule.getPoolTokens(LB_POOL);
        assertEq(tokens.length, 2);

        assertEq(tokens[0], USDT);
        assertEq(tokens[1], USDC);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: LB_POOL, poolModule: address(traderJoeModule)});
    }

    function testAddPool() public {
        addPool();

        assertEq(linkedPool.getToken(0), USDT);
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

    function testSwapFromUSDTtoUSDC() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDT, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDT).balanceOf(user), 0);
        assertEq(IERC20(USDC).balanceOf(user), amountOut);
    }

    function testSwapFromUSDCtoUSDT() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC).balanceOf(user), 0);
        assertEq(IERC20(USDT).balanceOf(user), amountOut);
    }

    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        traderJoeModule.poolSwap({
            pool: LB_POOL,
            tokenFrom: IndexedToken({index: 0, token: USDT}),
            tokenTo: IndexedToken({index: 1, token: USDC}),
            amountIn: 100 * 10**6
        });
    }

    function testGetPoolQuoteRevertsWhenTokensNotInPool() public {
        vm.expectRevert("tokens not in pool");
        traderJoeModule.getPoolQuote({
            pool: LB_POOL,
            tokenFrom: IndexedToken({index: 0, token: address(0xA)}),
            tokenTo: IndexedToken({index: 1, token: USDC}),
            amountIn: 100 * 10**6,
            probePaused: false
        });

        vm.expectRevert("tokens not in pool");
        traderJoeModule.getPoolQuote({
            pool: LB_POOL,
            tokenFrom: IndexedToken({index: 0, token: USDT}),
            tokenTo: IndexedToken({index: 1, token: address(0xA)}),
            amountIn: 100 * 10**6,
            probePaused: false
        });

        vm.expectRevert("tokens not in pool");
        traderJoeModule.getPoolQuote({
            pool: LB_POOL,
            tokenFrom: IndexedToken({index: 0, token: address(0xA)}),
            tokenTo: IndexedToken({index: 1, token: address(0xB)}),
            amountIn: 100 * 10**6,
            probePaused: false
        });
    }

    function testGetPoolQuoteReturnsZeroWhenAmountInLeft() public {
        uint256 amountOut = traderJoeModule.getPoolQuote({
            pool: LB_POOL,
            tokenFrom: IndexedToken({index: 0, token: USDT}),
            tokenTo: IndexedToken({index: 1, token: USDC}),
            amountIn: 10**18,
            probePaused: false
        });
        assertEq(amountOut, 0);
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
