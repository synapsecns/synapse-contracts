// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../../../utils/IntegrationUtils.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken, UniswapV3Module} from "../../../../../contracts/router/modules/pool/uniswap/UniswapV3Module.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract UniswapV3ModuleEthTestFork is IntegrationUtils {
    using SafeERC20 for IERC20;

    LinkedPool public linkedPool;
    UniswapV3Module public uniswapV3Module;

    // 2023-11-03
    uint256 public constant ETH_BLOCK_NUMBER = 18490000;

    // Uniswap V3 Router on Ethereum
    address public constant UNI_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    // Eden's Uniswap V3 Static Quoter on Ethereum
    address public constant UNI_V3_STATIC_QUOTER = 0xc80f61d1bdAbD8f5285117e1558fDDf8C64870FE;
    // Uniswap V3 USDC/USDT pool on Ethereum
    address public constant UNI_V3_USDC_POOL = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6;

    // Native USDC on Ethereum
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // Native USDT on Ethereum
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address public user;

    constructor() IntegrationUtils("mainnet", "UniswapV3Module", ETH_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        uniswapV3Module = new UniswapV3Module(UNI_V3_ROUTER, UNI_V3_STATIC_QUOTER);
        linkedPool = new LinkedPool(USDC, address(this));
        user = makeAddr("User");

        vm.label(UNI_V3_ROUTER, "UniswapV3Router");
        vm.label(UNI_V3_STATIC_QUOTER, "UniswapV3StaticQuoter");
        vm.label(UNI_V3_USDC_POOL, "UniswapV3USDCPool");
        vm.label(USDC, "USDC");
        vm.label(USDT, "USDT");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = uniswapV3Module.getPoolTokens(UNI_V3_USDC_POOL);
        assertEq(tokens.length, 2);
        assertEq(tokens[0], USDC);
        assertEq(tokens[1], USDT);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: UNI_V3_USDC_POOL, poolModule: address(uniswapV3Module)});
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
        uniswapV3Module.poolSwap({
            pool: UNI_V3_USDC_POOL,
            tokenFrom: IndexedToken({index: 0, token: USDC}),
            tokenTo: IndexedToken({index: 1, token: USDT}),
            amountIn: 100 * 10**6
        });
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.startPrank(user);
        IERC20(token).safeApprove(address(linkedPool), amount);
        vm.stopPrank();
    }
}
