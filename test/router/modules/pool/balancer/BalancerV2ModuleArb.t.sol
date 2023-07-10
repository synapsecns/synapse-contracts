// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken, BalancerV2Module} from "../../../../../contracts/router/modules/pool/balancer/BalancerV2Module.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract BalancerV2ModuleArbTestFork is Test {
    LinkedPool public linkedPool;
    BalancerV2Module public balancerV2Module;

    // 2023-07-03
    uint256 public constant ARB_BLOCK_NUMBER = 107596120;

    // Balancer V2 Vault on Arbitrum
    address public constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    // Balancer V2 wstETH/ETH meta stable pool on Arbitrum
    address public constant BALANCER_V2_WSTETH_POOL = 0x36bf227d6BaC96e2aB1EbB5492ECec69C691943f;

    // Native wstETH on Arbitrum
    address public constant WSTETH = 0x5979D7b546E38E414F7E9822514be443A4800529;

    // Native WETH on Arbitrum
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address public user;

    function setUp() public {
        string memory arbRPC = vm.envString("ARBITRUM_API");
        vm.createSelectFork(arbRPC, ARB_BLOCK_NUMBER);

        balancerV2Module = new BalancerV2Module(BALANCER_V2_VAULT);
        linkedPool = new LinkedPool(WSTETH);
        user = makeAddr("User");

        vm.label(BALANCER_V2_WSTETH_POOL, "BalancerV2WSTETHPool");
        vm.label(WSTETH, "wstETH");
        vm.label(WETH, "WETH");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = balancerV2Module.getPoolTokens(BALANCER_V2_WSTETH_POOL);
        assertEq(tokens.length, 2);
        assertEq(tokens[0], WSTETH);
        assertEq(tokens[1], WETH);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: BALANCER_V2_WSTETH_POOL, poolModule: address(balancerV2Module)});
    }

    function testAddPool() public {
        addPool();
        assertEq(linkedPool.getToken(0), WSTETH);
        assertEq(linkedPool.getToken(1), WETH);
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

    function testSwapFromWSTETHtoWETH() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(WSTETH, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(WSTETH).balanceOf(user), 0);
        assertEq(IERC20(WETH).balanceOf(user), amountOut);
    }

    function testSwapFromWETHtoWSTETH() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(WETH, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(WETH).balanceOf(user), 0);
        assertEq(IERC20(WSTETH).balanceOf(user), amountOut);
    }

    /* TODO: if require delegatecall
    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        uniswapV3Module.poolSwap({
            pool: UNI_V3_USDC_POOL,
            tokenFrom: IndexedToken({index: 0, token: USDC}),
            tokenTo: IndexedToken({index: 1, token: USDC_E}),
            amountIn: 100 * 10**6
        });
    }
    */

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
