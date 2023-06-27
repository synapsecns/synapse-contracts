// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {LinkedPool} from "../../../../contracts/router/LinkedPool.sol";
import {UniswapV3Module} from "../../../../contracts/router/pools/uniswap/UniswapV3Module.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract UniswapV3ModuleArbTestFork is Test {
    LinkedPool public linkedPool;
    UniswapV3Module public uniswapV3Module;

    // 2023-06-27
    uint256 public constant ARB_BLOCK_NUMBER = 105400000;

    // Uniswap V3 Router on Arbitrum
    address public constant UNI_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    // Uniswap V3 USDC/USDC.e pool on Arbitrum
    address public constant UNI_V3_USDC_POOL = 0x8e295789c9465487074a65b1ae9Ce0351172393f;

    // Bridged USDC (USDC.e) on Arbitrum
    address public constant USDC_E = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    // Native USDC on Arbitrum
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address public user;

    function setUp() public {
        string memory arbRPC = vm.envString("ARBITRUM_API");
        vm.createSelectFork(arbRPC, ARB_BLOCK_NUMBER);

        uniswapV3Module = new UniswapV3Module(UNI_V3_ROUTER);
        linkedPool = new LinkedPool(USDC);
        user = makeAddr("User");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = uniswapV3Module.getPoolTokens(UNI_V3_USDC_POOL);
        assertEq(tokens.length, 2);
        assertEq(tokens[0], USDC);
        assertEq(tokens[1], USDC_E);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: UNI_V3_USDC_POOL, poolModule: address(uniswapV3Module)});
    }

    function testAddPool() public {
        addPool();
        assertEq(linkedPool.getToken(0), USDC);
        assertEq(linkedPool.getToken(1), USDC_E);
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

    function testSwapFromUSDCtoUSDCe() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC, amount);
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(IERC20(USDC).balanceOf(user), 0);
        assertEq(IERC20(USDC_E).balanceOf(user), amountOut);
    }

    function testSwapFromUSDCetoUSDC() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC_E, amount);
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(IERC20(USDC_E).balanceOf(user), 0);
        assertEq(IERC20(USDC).balanceOf(user), amountOut);
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
