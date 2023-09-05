// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken, UniswapV3SR02Module} from "../../../../../contracts/router/modules/pool/uniswap/UniswapV3SR02Module.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract UniswapV3SR02ModuleAvaxTestFork is Test {
    LinkedPool public linkedPool;
    UniswapV3SR02Module public uniswapV3SR02Module;

    // 2023-09-05
    uint256 public constant AVAX_BLOCK_NUMBER = 34800000;

    // Uniswap V3 SwapRouter02 on Avalanche
    address public constant UNI_V3_SWAP_ROUTER_02 = 0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE;

    // Eden's Uniswap V3 Static Quoter on Avalanche
    address public constant UNI_V3_STATIC_QUOTER = 0xc15804984E3e77B7f8A60E4553e2289c5fdeAe8B;

    // Uniswap V3 USDC/USDT pool on Avalanche
    address public constant UNI_V3_USDC_POOL = 0x804226cA4EDb38e7eF56D16d16E92dc3223347A0;

    // Native USDT on Avalanche
    address public constant USDT = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;

    // Native USDC on Avalanche
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    address public user;

    function setUp() public {
        string memory avaxRPC = vm.envString("AVALANCHE_API");
        vm.createSelectFork(avaxRPC, AVAX_BLOCK_NUMBER);

        uniswapV3SR02Module = new UniswapV3SR02Module(UNI_V3_SWAP_ROUTER_02, UNI_V3_STATIC_QUOTER);
        linkedPool = new LinkedPool(USDC, address(this));
        user = makeAddr("User");

        vm.label(UNI_V3_SWAP_ROUTER_02, "UniswapV3SwapRouter02");
        vm.label(UNI_V3_STATIC_QUOTER, "UniswapV3StaticQuoter");
        vm.label(UNI_V3_USDC_POOL, "UniswapV3USDCPool");
        vm.label(USDT, "USDT");
        vm.label(USDC, "USDC");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = uniswapV3SR02Module.getPoolTokens(UNI_V3_USDC_POOL);
        assertEq(tokens.length, 2);
        // USDT address is lexically smaller than USDC address
        assertEq(tokens[0], USDT);
        assertEq(tokens[1], USDC);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: UNI_V3_USDC_POOL, poolModule: address(uniswapV3SR02Module)});
    }

    function testAddPool() public {
        addPool();
        assertEq(linkedPool.getToken(0), USDC);
        assertEq(linkedPool.getToken(1), USDT);
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

    function testSwapFromUSDCtoUSDT() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC).balanceOf(user), 0);
        assertEq(IERC20(USDT).balanceOf(user), amountOut);
    }

    function testSwapFromUSDTtoUSDC() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDT, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDT).balanceOf(user), 0);
        assertEq(IERC20(USDC).balanceOf(user), amountOut);
    }

    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        uniswapV3SR02Module.poolSwap({
            pool: UNI_V3_USDC_POOL,
            tokenFrom: IndexedToken({index: 0, token: USDC}),
            tokenTo: IndexedToken({index: 1, token: USDT}),
            amountIn: 100 * 10**6
        });
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
