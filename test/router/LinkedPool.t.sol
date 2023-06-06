// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Action, LimitedToken, LinkedPool} from "../../contracts/router/LinkedPool.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockDefaultPool, MockDefaultPausablePool} from "../mocks/MockDefaultPausablePool.sol";

import {Test} from "forge-std/Test.sol";

// solhint-disable func-name-mixedcase
contract LinkedPoolTest is Test {
    uint256 public maskOnlySwap = Action.Swap.mask();
    uint256 public maskNoSwaps = type(uint256).max ^ Action.Swap.mask();

    MockERC20 public bridgeToken;
    MockERC20 public token0;
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;

    // Pool with Bridge token, Token0, Token1
    MockDefaultPausablePool public poolB01;
    // Pool with Bridge token, Token2
    MockDefaultPool public poolB2;
    // Pool with Token0, Token1
    MockDefaultPool public pool01;
    // Pool with Token0, Token2
    MockDefaultPool public pool02;
    // Pool with Token1, Token2, Token3
    MockDefaultPausablePool public pool123;

    // Pool with Bridge Token, Token0, Token1, Token2
    MockDefaultPool public poolB012;

    mapping(uint256 => address[]) public attachedPools;

    LinkedPool public swap;

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
            poolB01 = new MockDefaultPausablePool(tokens);
            setupPool(poolB01, tokens, 100_000);
            vm.label(address(poolB01), "[BT, T0, T1]");
        }
        {
            address[] memory tokens = new address[](2);
            tokens[0] = address(bridgeToken);
            tokens[1] = address(token2);
            poolB2 = new MockDefaultPool(tokens);
            setupPool(poolB2, tokens, 10_000);
            vm.label(address(poolB2), "[BT, T2]");
        }
        {
            address[] memory tokens = new address[](2);
            tokens[0] = address(token0);
            tokens[1] = address(token1);
            pool01 = new MockDefaultPool(tokens);
            setupPool(pool01, tokens, 1_000);
            vm.label(address(pool01), "[T0, T1]");
        }
        {
            address[] memory tokens = new address[](2);
            tokens[0] = address(token0);
            tokens[1] = address(token2);
            pool02 = new MockDefaultPool(tokens);
            setupPool(pool02, tokens, 100);
            vm.label(address(pool02), "[T0, T2]");
        }
        {
            address[] memory tokens = new address[](3);
            tokens[0] = address(token1);
            tokens[1] = address(token2);
            tokens[2] = address(token3);
            pool123 = new MockDefaultPausablePool(tokens);
            setupPool(pool123, tokens, 50_000);
            vm.label(address(pool123), "[T1, T2, T3]");
        }
        {
            address[] memory tokens = new address[](4);
            tokens[0] = address(bridgeToken);
            tokens[1] = address(token0);
            tokens[2] = address(token1);
            tokens[3] = address(token2);
            poolB012 = new MockDefaultPool(tokens);
            setupPool(poolB012, tokens, 20_000);
            vm.label(address(poolB012), "[BT, T0, T1, T2]");
        }
    }

    function simpleSetup() public {
        swap = new LinkedPool(address(bridgeToken));
    }

    function test_simpleSetup() public {
        simpleSetup();
        assertEq(swap.getToken(0), address(bridgeToken));
        assertEq(swap.owner(), address(this));
        assertEq(swap.tokenNodesAmount(), 1);
    }

    function addPool(
        uint256 nodeIndex,
        address poolAddress,
        uint256 tokensAmount
    ) public {
        swap.addPool(nodeIndex, poolAddress, poolModule, tokensAmount);
        attachedPools[nodeIndex].push(poolAddress);
    }

    function complexSetup() public {
        // 0: BT
        simpleSetup();
        // 0: BT + (1: T0, 2: T1)
        addPool(0, address(poolB01), 3);
        // 1: TO + (3: T1)
        addPool(1, address(pool01), 2);
        // 1: T0 + (4: T2)
        addPool(1, address(pool02), 2);
        // 0: BT + (5: T2)
        addPool(0, address(poolB2), 2);
        // 5: T2 + (6: T1, 7: T3)
        addPool(5, address(pool123), 3);
    }

    function test_complexSetup() public {
        complexSetup();
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

    function duplicatedPoolSetup() public {
        complexSetup();
        // 4: T2 + (8: T1, 9: T3)
        addPool(4, address(pool123), 3);
    }

    function test_duplicatedPoolSetup() public {
        duplicatedPoolSetup();
        assertEq(swap.tokenNodesAmount(), 10);
        assertEq(swap.getToken(8), address(token1));
        assertEq(swap.getToken(9), address(token3));
    }

    // Setup where pool with a bridge token is attached to a non-root node
    function bridgeTokenPoolAttachedSetup() public {
        complexSetup();
        // Should not add the bridge token to the tree more than once
        // 4: T2 + ([BT: ignored], 8: T0, 9: T1)
        addPool(4, address(poolB012), 4);
        assertEq(swap.tokenNodesAmount(), 10);
        assertEq(swap.getToken(8), address(token0));
        assertEq(swap.getToken(9), address(token1));
    }

    function compactSetup() public {
        // 0: BT
        simpleSetup();
        // 0: BT + (1: T2)
        addPool(0, address(poolB2), 2);
        // 1: T2 + (2: T0)
        addPool(1, address(pool02), 2);
    }

    function test_compactSetup() public {
        compactSetup();
        assertEq(swap.tokenNodesAmount(), 3);
        assertEq(swap.getToken(0), address(bridgeToken));
        assertEq(swap.getToken(1), address(token2));
        assertEq(swap.getToken(2), address(token0));
    }

    // ═══════════════════════════════════════════════ REVERT TESTS ════════════════════════════════════════════════════

    function test_addPool_revert_nodeNotInPool() public {
        complexSetup();
        // 1 is T0, which is not in pool123
        vm.expectRevert("Node token not found in the pool");
        swap.addPool(1, address(pool123), address(0), 3);
    }

    function test_addPool_revert_nodeIndexOutOfRange() public {
        complexSetup();
        uint256 tokensAmount = swap.tokenNodesAmount();
        vm.expectRevert("Out of range");
        swap.addPool(tokensAmount, address(pool123), address(0), 3);
    }

    function test_addPool_revert_emptyPoolAddress() public {
        complexSetup();
        vm.expectRevert("Pool address can't be zero");
        swap.addPool(0, address(0), address(0), 3);
    }

    function test_addPool_revert_alreadyAttached() public {
        complexSetup();
        // [BT, T0, T1] was already attached to the root node (0)
        vm.expectRevert("Pool already attached");
        swap.addPool(0, address(poolB01), address(0), 3);
        // [T1, T2, T3] was already attached to node with index 5
        vm.expectRevert("Pool already attached");
        swap.addPool(5, address(pool123), address(0), 3);
    }

    function test_addPool_revert_parentPool() public {
        complexSetup();
        // [T1, T2, T3] was already used to add node with indexes 6 and 7
        vm.expectRevert("Pool already on path to root");
        swap.addPool(6, address(pool123), address(0), 3);
        vm.expectRevert("Pool already on path to root");
        swap.addPool(7, address(pool123), address(0), 3);
    }

    function test_addPool_revert_poolUsedOnRootPath() public {
        complexSetup();
        // [BT, T0, T1] was already used to add node with indexes 1 and 2
        vm.expectRevert("Pool already on path to root");
        // Node 3 was added using pool01, but poolB01 is present on the root path
        swap.addPool(3, address(poolB01), address(0), 3);
    }

    function test_calculateSwap_returns0_tokenIdentical() public {
        complexSetup();
        uint256 tokensAmount = swap.tokenNodesAmount();
        for (uint8 i = 0; i < tokensAmount; ++i) {
            assertEq(swap.calculateSwap(i, i, 10**18), 0);
        }
    }

    function test_calculateSwap_returns0_tokenOutOfRange() public {
        complexSetup();
        uint8 tokensAmount = uint8(swap.tokenNodesAmount());
        for (uint8 i = 0; i < tokensAmount; ++i) {
            assertEq(swap.calculateSwap(i, tokensAmount, 10**18), 0);
            assertEq(swap.calculateSwap(tokensAmount, i, 10**18), 0);
        }
    }

    function test_getToken_revert_tokenOutOfRange() public {
        complexSetup();
        uint8 tokensAmount = uint8(swap.tokenNodesAmount());
        vm.expectRevert("Out of range");
        swap.getToken(tokensAmount);
    }

    function test_swap_revert_tokenIdentical() public {
        complexSetup();
        uint256 tokensAmount = swap.tokenNodesAmount();
        for (uint8 i = 0; i < tokensAmount; ++i) {
            vm.expectRevert("Swap not supported");
            swap.swap(i, i, 10**18, 0, type(uint256).max);
        }
    }

    function test_swap_revert_tokenOutOfRange() public {
        complexSetup();
        uint8 tokensAmount = uint8(swap.tokenNodesAmount());
        for (uint8 i = 0; i < tokensAmount; ++i) {
            vm.expectRevert("Swap not supported");
            swap.swap(i, tokensAmount, 10**18, 0, type(uint256).max);
            vm.expectRevert("Swap not supported");
            swap.swap(tokensAmount, i, 10**18, 0, type(uint256).max);
        }
    }

    function test_swap_revert_deadlineExceeded() public {
        uint256 currentTime = 1234567890;
        vm.warp(currentTime);
        complexSetup();
        uint8 tokensAmount = uint8(swap.tokenNodesAmount());
        for (uint8 i = 0; i < tokensAmount; ++i) {
            vm.expectRevert("Deadline not met");
            swap.swap(i, (i + 1) % tokensAmount, 10**18, 0, currentTime - 1);
        }
    }

    function test_swap_revert_minDyNotMet() public {
        complexSetup();
        uint256 amountIn = 10**18;
        uint256 amountOut = swap.calculateSwap(0, 1, amountIn);
        prepareUser(address(bridgeToken), amountIn);
        vm.expectRevert("Swap didn't result in min tokens");
        vm.prank(user);
        swap.swap(0, 1, amountIn, amountOut + 1, type(uint256).max);
    }

    // ═══════════════════════════════════════════════ GETTERS TESTS ═══════════════════════════════════════════════════

    function test_getAttachedPools() public {
        duplicatedPoolSetup();
        uint256 tokensAmount = swap.tokenNodesAmount();
        for (uint8 i = 0; i < tokensAmount; ++i) {
            assertEq(swap.getAttachedPools(i), attachedPools[i]);
        }
    }

    function test_getTokenNodes() public {
        duplicatedPoolSetup();
        checkTokenNodes(address(bridgeToken));
        checkTokenNodes(address(token0));
        checkTokenNodes(address(token1));
        checkTokenNodes(address(token2));
        checkTokenNodes(address(token3));
    }

    function test_getTokenNodes_returnsEmpty_unknownToken(address token) public {
        vm.assume(
            token != address(bridgeToken) &&
                token != address(token0) &&
                token != address(token1) &&
                token != address(token2) &&
                token != address(token3)
        );
        duplicatedPoolSetup();
        assertEq(swap.getTokenNodes(token), new uint256[](0));
    }

    function checkTokenNodes(address token) public {
        uint256 tokensAmount = swap.tokenNodesAmount();
        uint256 nodesFound = 0;
        for (uint8 i = 0; i < tokensAmount; ++i) {
            if (swap.getToken(i) == token) ++nodesFound;
        }
        uint256[] memory tokenNodes = new uint256[](nodesFound);
        nodesFound = 0;
        for (uint8 i = 0; i < tokensAmount; ++i) {
            if (swap.getToken(i) == token) {
                tokenNodes[nodesFound++] = i;
            }
        }
        assertEq(swap.getTokenNodes(token), tokenNodes);
    }

    function test_getConnectedTokens_endWithRootNode() public {
        // Setup where only BT, T0 and T2 are added
        compactSetup();
        bool[] memory isConnected = swap.getConnectedTokens(createTokensIn(), address(bridgeToken));
        assertEq(isConnected.length, 10);
        // Only T0 and T2 with Action.Swap enabled should be true
        assertFalse(isConnected[0], "isConnected[0]"); // Swap enabled, but tokenIn == tokenOut
        assertFalse(isConnected[1], "isConnected[1]"); // Swap disabled
        assertTrue(isConnected[2], "isConnected[2]"); // Swap enabled, T0 -> BT exists
        assertFalse(isConnected[3], "isConnected[3]"); // Swap disabled
        assertFalse(isConnected[4], "isConnected[4]"); // Swap enabled, T1 -> BT does not exist
        assertFalse(isConnected[5], "isConnected[5]"); // Swap disabled
        assertTrue(isConnected[6], "isConnected[6]"); // Swap enabled, T2 -> BT exists
        assertFalse(isConnected[7], "isConnected[7]"); // Swap disabled
        assertFalse(isConnected[8], "isConnected[8]"); // Swap enabled T3 -> BT does not exist
        assertFalse(isConnected[9], "isConnected[9]"); // Swap disabled
    }

    function test_getConnectedTokens_endWithNonRootNode() public {
        // Setup where only BT, T0 and T2 are added
        compactSetup();
        bool[] memory isConnected = swap.getConnectedTokens(createTokensIn(), address(token0));
        assertEq(isConnected.length, 10);
        // Only BT with Action.Swap enabled should be true
        assertTrue(isConnected[0], "isConnected[0]"); // Swap enabled, T0 -> BT exists
        // Rest should be false (either tokenIn or tokenOut ned to be root)
        for (uint256 i = 1; i < 10; ++i) {
            assertFalse(isConnected[i]);
        }
    }

    function test_getConnectedTokens_endWithNonAddedToken() public {
        // Setup where only BT, T0 and T2 are added
        compactSetup();
        bool[] memory isConnected = swap.getConnectedTokens(createTokensIn(), address(token1));
        // Everything should be false
        for (uint256 i = 0; i < 10; ++i) {
            assertFalse(isConnected[i]);
        }
    }

    function createTokensIn() public view returns (LimitedToken[] memory tokens) {
        // Use every token twice: with `maskOnlySwap` and its counterpart
        tokens = new LimitedToken[](10);
        tokens[0] = LimitedToken({actionMask: maskOnlySwap, token: address(bridgeToken)});
        tokens[1] = LimitedToken({actionMask: maskNoSwaps, token: address(bridgeToken)});
        tokens[2] = LimitedToken({actionMask: maskOnlySwap, token: address(token0)});
        tokens[3] = LimitedToken({actionMask: maskNoSwaps, token: address(token0)});
        tokens[4] = LimitedToken({actionMask: maskOnlySwap, token: address(token1)});
        tokens[5] = LimitedToken({actionMask: maskNoSwaps, token: address(token1)});
        tokens[6] = LimitedToken({actionMask: maskOnlySwap, token: address(token2)});
        tokens[7] = LimitedToken({actionMask: maskNoSwaps, token: address(token2)});
        tokens[8] = LimitedToken({actionMask: maskOnlySwap, token: address(token3)});
        tokens[9] = LimitedToken({actionMask: maskNoSwaps, token: address(token3)});
    }

    function test_findBestPath(
        uint8 tokenFrom,
        uint8 tokenTo,
        uint256 amount
    ) public {
        uint8 tokensAmount = 10;
        tokenFrom = tokenFrom % tokensAmount;
        tokenTo = tokenTo % tokensAmount;
        amount = 1 + (amount % 1000);
        duplicatedPoolSetup();
        require(swap.tokenNodesAmount() == tokensAmount, "Setup failed");
        address tokenIn = swap.getToken(tokenFrom);
        address tokenOut = swap.getToken(tokenTo);
        vm.assume(tokenIn != tokenOut);
        uint256 amountIn = amount * (10**MockERC20(tokenIn).decimals());
        (uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 amountOut) = swap.findBestPath(tokenIn, tokenOut, amountIn);
        assertEq(swap.getToken(tokenIndexFrom), tokenIn);
        assertEq(swap.getToken(tokenIndexTo), tokenOut);
        // Check all possible paths between tokenIn and tokenOut
        uint256 amountOutBest = 0;
        for (uint8 i = 0; i < tokensAmount; ++i) {
            if (swap.getToken(i) != tokenIn) continue;
            for (uint8 j = 0; j < tokensAmount; ++j) {
                if (swap.getToken(j) != tokenOut) continue;
                uint256 amountOutQuote = swap.calculateSwap(i, j, amountIn);
                if (amountOutQuote > amountOutBest) {
                    amountOutBest = amountOutQuote;
                }
            }
        }
        assertEq(amountOut, amountOutBest);
    }

    function test_findBestPath_returns0_identicalTokens() public {
        duplicatedPoolSetup();
        uint256 tokensAmount = swap.tokenNodesAmount();
        for (uint8 i = 0; i < tokensAmount; ++i) {
            address tokenIn = swap.getToken(i);
            for (uint8 j = 0; j < tokensAmount; ++j) {
                address tokenOut = swap.getToken(j);
                if (tokenIn != tokenOut) continue;
                (uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 amountOut) = swap.findBestPath(
                    tokenIn,
                    tokenOut,
                    10**18
                );
                assertEq(tokenIndexFrom, 0);
                assertEq(tokenIndexTo, 0);
                assertEq(amountOut, 0);
            }
        }
    }

    function test_findBestPath_returns0_unknownToken(address token) public {
        vm.assume(
            token != address(bridgeToken) &&
                token != address(token0) &&
                token != address(token1) &&
                token != address(token2) &&
                token != address(token3)
        );
        duplicatedPoolSetup();
        uint256 tokensAmount = swap.tokenNodesAmount();
        for (uint8 i = 0; i < tokensAmount; ++i) {
            address existingToken = swap.getToken(i);
            (uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 amountOut) = swap.findBestPath(
                existingToken,
                token,
                10**18
            );
            assertEq(tokenIndexFrom, 0);
            assertEq(tokenIndexTo, 0);
            assertEq(amountOut, 0);
            (tokenIndexFrom, tokenIndexTo, amountOut) = swap.findBestPath(token, existingToken, 10**18);
            assertEq(tokenIndexFrom, 0);
            assertEq(tokenIndexTo, 0);
            assertEq(amountOut, 0);
        }
    }

    function test_findBestPath_returns0_amountInZero() public {
        duplicatedPoolSetup();
        uint256 tokensAmount = swap.tokenNodesAmount();
        for (uint8 i = 0; i < tokensAmount; ++i) {
            address tokenIn = swap.getToken(i);
            for (uint8 j = 0; j < tokensAmount; ++j) {
                address tokenOut = swap.getToken(j);
                if (tokenIn == tokenOut) continue;
                (uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 amountOut) = swap.findBestPath(tokenIn, tokenOut, 0);
                assertEq(tokenIndexFrom, 0);
                assertEq(tokenIndexTo, 0);
                assertEq(amountOut, 0);
            }
        }
    }

    function test_calculateSwap_returns0_whenPoolReverts() public {
        // Force poolB01 to revert on calculateSwap(*, *, *)
        vm.mockCallRevert(
            address(poolB01),
            abi.encodeWithSelector(MockDefaultPool.calculateSwap.selector),
            "Mocked revert data"
        );
        complexSetup();
        // This goes through the pool that is going to revert
        uint256 amountOut = swap.calculateSwap(3, 7, 10**18);
        assertEq(amountOut, 0);
    }

    function test_calculateSwap_returnsNonZero_whenPoolPaused() public {
        complexSetup();
        // This goes through the pool that is going to be paused
        uint256 amountOutQuote = swap.calculateSwap(3, 7, 10**18);
        // Pause poolB01
        poolB01.setPaused(true);
        // Should return the same quote (ignoring the fact that pool is paused)
        assertEq(swap.calculateSwap(3, 7, 10**18), amountOutQuote);
    }

    function test_findBestPath_returns0_whenOnlyPathReverts() public {
        // Force pool123 to revert on calculateSwap(*, *, *)
        vm.mockCallRevert(
            address(pool123),
            abi.encodeWithSelector(MockDefaultPool.calculateSwap.selector),
            "Mocked revert data"
        );
        complexSetup();
        // All paths to/from T3 go through the reverting pool
        (uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 amountOut) = swap.findBestPath(
            address(token1),
            address(token3),
            10**18
        );
        assertEq(tokenIndexFrom, 0);
        assertEq(tokenIndexTo, 0);
        assertEq(amountOut, 0);
        (tokenIndexFrom, tokenIndexTo, amountOut) = swap.findBestPath(address(token3), address(token2), 10**18);
        assertEq(tokenIndexFrom, 0);
        assertEq(tokenIndexTo, 0);
        assertEq(amountOut, 0);
    }

    function test_findBestPath_returns0_whenOnlyPathPaused() public {
        complexSetup();
        // Pause pool123
        pool123.setPaused(true);
        // All paths to/from T3 go through the paused pool
        (uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 amountOut) = swap.findBestPath(
            address(token1),
            address(token3),
            10**18
        );
        assertEq(tokenIndexFrom, 0);
        assertEq(tokenIndexTo, 0);
        assertEq(amountOut, 0);
        (tokenIndexFrom, tokenIndexTo, amountOut) = swap.findBestPath(address(token3), address(token2), 10**18);
        assertEq(tokenIndexFrom, 0);
        assertEq(tokenIndexTo, 0);
        assertEq(amountOut, 0);
    }

    function test_findBestPath_returnsSomething_whenOnePathReverts() public {
        // Force poolB01 to revert on calculateSwap(*, *, *)
        vm.mockCallRevert(
            address(poolB01),
            abi.encodeWithSelector(MockDefaultPool.calculateSwap.selector),
            "Mocked revert data"
        );
        complexSetup();
        // The only remaining path between BT and T1 is BT -> T2 -> T1 via poolB2 and pool123
        (uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 amountOut) = swap.findBestPath(
            address(bridgeToken),
            address(token1),
            10**18
        );
        // [BT, T2]
        uint256 amountOutExpected = poolB2.calculateSwap(0, 1, 10**18);
        // [T1, T2, T3]
        amountOutExpected = pool123.calculateSwap(1, 0, amountOutExpected);
        assertEq(tokenIndexFrom, 0);
        assertEq(tokenIndexTo, 6);
        assertEq(amountOut, amountOutExpected);
    }

    function test_findBestPath_returnsSomething_whenOnePathPaused() public {
        complexSetup();
        // Pause poolB01
        poolB01.setPaused(true);
        // The only remaining path between BT and T1 is BT -> T2 -> T1 via poolB2 and pool123
        (uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 amountOut) = swap.findBestPath(
            address(bridgeToken),
            address(token1),
            10**18
        );
        // [BT, T2]
        uint256 amountOutExpected = poolB2.calculateSwap(0, 1, 10**18);
        // [T1, T2, T3]
        amountOutExpected = pool123.calculateSwap(1, 0, amountOutExpected);
        assertEq(tokenIndexFrom, 0);
        assertEq(tokenIndexTo, 6);
        assertEq(amountOut, amountOutExpected);
    }

    // ════════════════════════════════════════════════ SWAP TESTS ═════════════════════════════════════════════════════

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
        complexSetup();
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

    function test_swap_revert_poolPaused() public virtual {
        complexSetup();
        // Pause poolB01
        poolB01.setPaused(true);
        uint8 tokenFrom = 3;
        uint8 tokenTo = 7;
        uint256 amount = 100;
        // This goes through the paused pool
        address tokenIn = swap.getToken(tokenFrom);
        uint256 amountIn = amount * (10**MockERC20(tokenIn).decimals());
        prepareUser(tokenIn, amountIn);
        // Expect mock-specific revert message
        vm.expectRevert("Siesta time");
        vm.prank(user);
        swap.swap(tokenFrom, tokenTo, amountIn, 0, type(uint256).max);
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
        duplicatedPoolSetup();
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
        duplicatedPoolSetup();
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

    function test_swap_viaBestPath(
        uint8 tokenFrom,
        uint8 tokenTo,
        uint256 amount
    ) public {
        uint8 tokensAmount = 10;
        tokenFrom = tokenFrom % tokensAmount;
        tokenTo = tokenTo % tokensAmount;
        amount = 1 + (amount % 1000);
        duplicatedPoolSetup();
        require(swap.tokenNodesAmount() == tokensAmount, "Setup failed");
        address tokenIn = swap.getToken(tokenFrom);
        address tokenOut = swap.getToken(tokenTo);
        vm.assume(tokenIn != tokenOut);
        uint256 amountIn = amount * (10**MockERC20(tokenIn).decimals());
        (uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 amountOut) = swap.findBestPath(tokenIn, tokenOut, amountIn);
        require(amountOut > 0, "No path found when should've");
        prepareUser(tokenIn, amountIn);
        vm.prank(user);
        swap.swap(tokenIndexFrom, tokenIndexTo, amountIn, amountOut, block.timestamp);
        assertEq(MockERC20(tokenIn).balanceOf(user), 0);
        assertEq(MockERC20(tokenOut).balanceOf(user), amountOut);
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
        MockDefaultPool pool,
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
