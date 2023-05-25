// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {UniversalSwap} from "../../contracts/router/UniversalSwap.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockSaddlePool} from "../mocks/MockSaddlePool.sol";

import {Test} from "forge-std/Test.sol";

// solhint-disable func-name-mixedcase
contract UniversalSwapTest is Test {
    MockERC20 public bridgeToken;
    MockERC20 public token0;
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;

    // Pool with Bridge token, Token0, Token1
    MockSaddlePool public poolB01;
    // Pool with Bridge token, Token2
    MockSaddlePool public poolB2;
    // Pool with Token0, Token1
    MockSaddlePool public pool01;
    // Pool with Token0, Token2
    MockSaddlePool public pool02;
    // Pool with Token1, Token2, Token3
    MockSaddlePool public pool123;

    UniversalSwap public swap;

    address public user;

    // Not assigned in this test, but could be assigned in a child test
    address public poolModule;

    function setUp() public virtual {
        user = makeAddr("User");

        bridgeToken = setupERC20("BT", 18);
        token0 = setupERC20("T0", 18);
        token1 = setupERC20("T1", 6);
        token2 = setupERC20("T2", 18);
        token3 = setupERC20("T3", 6);

        {
            address[] memory tokens = new address[](3);
            tokens[0] = address(bridgeToken);
            tokens[1] = address(token0);
            tokens[2] = address(token1);
            poolB01 = new MockSaddlePool(tokens);
            setupPool(poolB01, tokens, 100_000);
            vm.label(address(poolB01), "[BT, T0, T1]");
        }
        {
            address[] memory tokens = new address[](2);
            tokens[0] = address(bridgeToken);
            tokens[1] = address(token2);
            poolB2 = new MockSaddlePool(tokens);
            setupPool(poolB2, tokens, 10_000);
            vm.label(address(poolB2), "[BT, T2]");
        }
        {
            address[] memory tokens = new address[](2);
            tokens[0] = address(token0);
            tokens[1] = address(token1);
            pool01 = new MockSaddlePool(tokens);
            setupPool(pool01, tokens, 1_000);
            vm.label(address(pool01), "[T0, T1]");
        }
        {
            address[] memory tokens = new address[](2);
            tokens[0] = address(token0);
            tokens[1] = address(token2);
            pool02 = new MockSaddlePool(tokens);
            setupPool(pool02, tokens, 100);
            vm.label(address(pool02), "[T0, T2]");
        }
        {
            address[] memory tokens = new address[](3);
            tokens[0] = address(token1);
            tokens[1] = address(token2);
            tokens[2] = address(token3);
            pool123 = new MockSaddlePool(tokens);
            setupPool(pool123, tokens, 50_000);
            vm.label(address(pool123), "[T1, T2, T3]");
        }
    }

    function test_constructor() public {
        swap = new UniversalSwap(address(bridgeToken));
        assertEq(swap.getToken(0), address(bridgeToken));
        assertEq(swap.owner(), address(this));
        assertEq(swap.tokenNodesAmount(), 1);
    }

    function test_complexSetup() public {
        // 0: BT
        test_constructor();
        // 0: BT + (1: T0, 2: T1)
        swap.addPool(0, address(poolB01), poolModule, 3);
        // 1: TO + (3: T1)
        swap.addPool(1, address(pool01), poolModule, 2);
        // 1: T0 + (4: T2)
        swap.addPool(1, address(pool02), poolModule, 2);
        // 0: BT + (5: T2)
        swap.addPool(0, address(poolB2), poolModule, 2);
        // 5: T2 + (6: T1, 7: T3)
        swap.addPool(5, address(pool123), poolModule, 3);
        assertEq(swap.tokenNodesAmount(), 8);
        // Initial setup:
        assertEq(swap.getToken(0), address(bridgeToken));
        // First pool: poolB01
        assertEq(swap.getToken(1), address(token0));
        assertEq(swap.getToken(2), address(token1));
        // Second pool: pool01
        assertEq(swap.getToken(3), address(token1));
        // Third pool: pool02
        assertEq(swap.getToken(4), address(token2));
        // Fourth pool: poolB2
        assertEq(swap.getToken(5), address(token2));
        // Fifth pool: pool123
        assertEq(swap.getToken(6), address(token1));
        assertEq(swap.getToken(7), address(token3));
    }

    function test_duplicatedPool() public {
        test_complexSetup();
        // 4: T2 + (8: T1, 9: T3)
        swap.addPool(4, address(pool123), poolModule, 3);
        assertEq(swap.tokenNodesAmount(), 10);
        assertEq(swap.getToken(8), address(token1));
        assertEq(swap.getToken(9), address(token3));
    }

    function test_swap(
        uint8 tokenFrom,
        uint8 tokenTo,
        uint256 amount
    ) public {
        uint8 tokensAmount = 8;
        tokenFrom = tokenFrom % tokensAmount;
        tokenTo = tokenTo % tokensAmount;
        amount = amount % 1000;
        vm.assume(tokenFrom != tokenTo);
        vm.assume(amount > 0);
        test_complexSetup();
        require(swap.tokenNodesAmount() == tokensAmount, "Setup failed");
        address tokenIn = swap.getToken(tokenFrom);
        uint256 amountIn = amount * (10**MockERC20(tokenIn).decimals());
        prepareUser(tokenIn, amountIn);
        address tokenOut = swap.getToken(tokenTo);
        uint256 amountOut = swap.calculateSwap(tokenFrom, tokenTo, amountIn);
        vm.prank(user);
        swap.swap(tokenFrom, tokenTo, amountIn, amountOut, block.timestamp);
        if (tokenIn != tokenOut) assertEq(MockERC20(tokenIn).balanceOf(user), 0);
        assertEq(MockERC20(tokenOut).balanceOf(user), amountOut);
    }

    function test_calculateSwap_samePoolTwice(
        uint8 tokenFrom,
        uint8 tokenTo,
        uint256 amount
    ) public {
        uint8 tokensAmount = 10;
        tokenFrom = tokenFrom % tokensAmount;
        tokenTo = tokenTo % tokensAmount;
        amount = amount % 1000;
        vm.assume(tokenFrom != tokenTo);
        vm.assume(amount > 0);
        test_duplicatedPool();
        require(swap.tokenNodesAmount() == tokensAmount, "Setup failed");
        address tokenIn = swap.getToken(tokenFrom);
        uint256 amountIn = amount * (10**MockERC20(tokenIn).decimals());
        uint256 amountOut = swap.calculateSwap(tokenFrom, tokenTo, amountIn);
        // Swaps betweens nodes [6..7] and [8..9] contain pool123 twice, so quote should be zero
        if (tokenFrom >= 6 && tokenFrom <= 7 && tokenTo >= 8 && tokenTo <= 9) {
            assertEq(amountOut, 0);
        } else if (tokenFrom >= 8 && tokenFrom <= 9 && tokenTo >= 6 && tokenTo <= 7) {
            assertEq(amountOut, 0);
        } else {
            // Other quotes should be non-zero
            assertGt(amountOut, 0);
        }
    }

    function test_swap_samePoolTwice(
        uint8 tokenFrom,
        uint8 tokenTo,
        uint256 amount
    ) public {
        uint8 tokensAmount = 10;
        tokenFrom = tokenFrom % tokensAmount;
        tokenTo = tokenTo % tokensAmount;
        amount = amount % 1000;
        vm.assume(tokenFrom != tokenTo);
        vm.assume(amount > 0);
        test_duplicatedPool();
        require(swap.tokenNodesAmount() == tokensAmount, "Setup failed");
        address tokenIn = swap.getToken(tokenFrom);
        uint256 amountIn = amount * (10**MockERC20(tokenIn).decimals());
        prepareUser(tokenIn, amountIn);
        address tokenOut = swap.getToken(tokenTo);
        uint256 amountOut = swap.calculateSwap(tokenFrom, tokenTo, amountIn);
        vm.prank(user);
        if (amountOut == 0) vm.expectRevert("Can't use same pool twice");
        swap.swap(tokenFrom, tokenTo, amountIn, amountOut, block.timestamp);
        if (amountOut > 0) {
            if (tokenIn != tokenOut) assertEq(MockERC20(tokenIn).balanceOf(user), 0);
            assertEq(MockERC20(tokenOut).balanceOf(user), amountOut);
        }
    }

    function prepareUser(address token, uint256 amount) public {
        MockERC20(token).mint(user, amount);
        vm.prank(user);
        MockERC20(token).approve(address(swap), amount);
    }

    function setupERC20(string memory name, uint8 decimals) public returns (MockERC20 token) {
        token = new MockERC20(name, decimals);
        vm.label(address(token), name);
    }

    function setupPool(
        MockSaddlePool pool,
        address[] memory tokens,
        uint256 amountNoDecimals
    ) public {
        for (uint8 i = 0; i < tokens.length; ++i) {
            MockERC20 token = MockERC20(tokens[i]);
            uint256 amount = amountNoDecimals * (10**token.decimals());
            token.mint(address(pool), amount);
            // Create a small imbalance in the pool
            amountNoDecimals = (amountNoDecimals * 101) / 100;
        }
    }
}
