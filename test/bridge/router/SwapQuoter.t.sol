// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../../contracts/bridge/router/SwapQuoter.sol";
import "../../utils/Utilities06.sol";

// solhint-disable func-name-mixedcase
contract SwapQuoterTest is Utilities06 {
    address internal constant ROUTER_MOCK = address(123456);
    address internal constant OWNER = address(1337);

    SwapQuoter internal quoter;

    address internal nEthPool;
    IERC20[] internal nEthTokens;
    ERC20 internal neth;
    ERC20 internal weth;

    address internal nUsdPool;
    IERC20[] internal nUsdTokens;
    ERC20 internal nusd;
    ERC20 internal dai;
    ERC20 internal usdc;
    ERC20 internal usdt;

    function setUp() public virtual override {
        super.setUp();

        // Deploy ETH tokens
        neth = deployERC20("nETH", 18);
        weth = deployERC20("WETH", 18);
        quoter = SwapQuoter(deploySwapQuoter(ROUTER_MOCK, address(weth), OWNER));
        // Deploy USD tokens
        nusd = deployERC20("nUSD", 18);
        dai = deployERC20("DAI", 18);
        usdc = deployERC20("USDC", 6);
        usdt = deployERC20("USDT", 6);

        {
            uint256[] memory amounts = new uint256[](2);
            nEthTokens.push(IERC20(neth));
            nEthTokens.push(IERC20(weth));
            amounts[0] = 1000;
            amounts[1] = 1100;
            nEthPool = deployPoolWithLiquidity(nEthTokens, amounts);
            vm.label(nEthPool, "nETH Pool");
        }
        {
            uint256[] memory amounts = new uint256[](4);
            nUsdTokens.push(IERC20(nusd));
            nUsdTokens.push(IERC20(dai));
            nUsdTokens.push(IERC20(usdc));
            nUsdTokens.push(IERC20(usdt));
            amounts[0] = 1000;
            amounts[1] = 1050;
            amounts[2] = 1100;
            amounts[3] = 1150;
            nUsdPool = deployPoolWithLiquidity(nUsdTokens, amounts);
            vm.label(nUsdPool, "nUSD Pool");
        }
    }

    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal virtual returns (address) {
        return address(new SwapQuoter(router_, weth_, owner));
    }

    function test_setUp() public {
        assertEq(quoter.owner(), OWNER, "!owner");

        assertEq(address(ISwap(nEthPool).getToken(0)), address(neth), "!neth");
        assertEq(address(ISwap(nEthPool).getToken(1)), address(weth), "!weth");

        assertEq(address(ISwap(nUsdPool).getToken(0)), address(nusd), "!nusd");
        assertEq(address(ISwap(nUsdPool).getToken(1)), address(dai), "!dai");
        assertEq(address(ISwap(nUsdPool).getToken(2)), address(usdc), "!usdc");
        assertEq(address(ISwap(nUsdPool).getToken(3)), address(usdt), "!usdt");
    }

    function addPool(
        address, // bridgeToken
        address pool
    ) public virtual {
        vm.prank(OWNER);
        quoter.addPool(pool);
    }

    function removePool(address, address pool) public virtual {
        vm.prank(OWNER);
        quoter.removePool(pool);
    }

    function addedEthPool() public view virtual returns (address) {
        return nEthPool;
    }

    function addedUsdPool() public view virtual returns (address) {
        return nUsdPool;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           TESTS: ADD POOL                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_addPool() public {
        addPool(address(neth), nEthPool);
        addPool(address(nusd), nUsdPool);
        _checkAddedPools();
    }

    function test_addPools() public {
        address[] memory pools = new address[](2);
        pools[0] = addedEthPool();
        pools[1] = addedUsdPool();
        vm.prank(OWNER);
        quoter.addPools(pools);
        _checkAddedPools();
    }

    function test_addPool_revert_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        expectOnlyOwnerRevert();
        vm.prank(caller);
        quoter.addPool(address(0));
    }

    function test_addPools_revert_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        expectOnlyOwnerRevert();
        vm.prank(caller);
        quoter.addPools(new address[](0));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          TESTS: REMOVE POOL                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_removePool() public {
        test_addPool();
        removePool(address(neth), nEthPool);
        // Usd quotes should remain intact
        uint256 allActions = type(uint256).max;
        _testSwap(addedUsdPool(), nUsdTokens, allActions);
        // Eth quotes should disappear
        _checkEmptyQuery(address(neth), address(weth), 10**18, allActions);
        _checkEmptyQuery(address(neth), UniversalToken.ETH_ADDRESS, 10**18, allActions);
        _checkEmptyQuery(address(weth), address(neth), 10**18, allActions);
        _checkEmptyQuery(UniversalToken.ETH_ADDRESS, address(neth), 10**18, allActions);
    }

    function test_removePool_revert_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        expectOnlyOwnerRevert();
        vm.prank(caller);
        quoter.removePool(address(0));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         TESTS: CHECK QUOTES                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_getAmountOut_swap(uint256 actionMask) public {
        test_addPools();
        // Check swap quotes with ETH
        nEthTokens[1] = IERC20(UniversalToken.ETH_ADDRESS);
        _testSwap(addedEthPool(), nEthTokens, actionMask);
        // Check swap quotes with WETH
        nEthTokens[1] = weth;
        _testSwap(addedEthPool(), nEthTokens, actionMask);
        // Check swap quotes for USD tokens
        _testSwap(addedUsdPool(), nUsdTokens, actionMask);
    }

    function test_getAmountOut_handleETH_noPools(uint256 actionMask) public {
        // Should be able to find the path without any pools
        _testHandleEth(UniversalToken.ETH_ADDRESS, address(weth), actionMask);
        _testHandleEth(address(weth), UniversalToken.ETH_ADDRESS, actionMask);
    }

    function test_getAmountOut_handleETH_withPools(uint256 actionMask) public {
        test_addPools();
        test_getAmountOut_handleETH_noPools(actionMask);
    }

    function test_getAmountOut_noPath(uint256 actionMask) public {
        test_addPools();
        // Check "no path" with ETH
        nEthTokens[1] = IERC20(UniversalToken.ETH_ADDRESS);
        _testNoPath(nEthTokens, nUsdTokens, actionMask);
        // Check "no path" with WETH
        nEthTokens[1] = weth;
        _testNoPath(nEthTokens, nUsdTokens, actionMask);
    }

    function _testSwap(
        address pool,
        IERC20[] memory tokens,
        uint256 actionMask
    ) internal {
        for (uint8 i = 0; i < tokens.length; ++i) {
            address tokenIn = address(tokens[i]);
            uint256 amountIn = _getAmountIn(tokenIn);
            for (uint8 j = 0; j < tokens.length; ++j) {
                address tokenOut = address(tokens[j]);
                if (i == j) {
                    // tokenIn -> tokenIn is always available regardless of actionMask
                    _checkSameTokenQuery(tokenIn, tokenOut, amountIn, actionMask);
                } else if (_includes(actionMask, Action.Swap)) {
                    // Swap is included in the actionMask
                    uint256 expectedAmountOut = ISwap(pool).calculateSwap(i, j, amountIn);
                    SynapseParams memory expectedParams = SynapseParams(Action.Swap, pool, i, j);
                    _checkActionQuery(tokenIn, tokenOut, amountIn, actionMask, expectedAmountOut, expectedParams);
                } else {
                    // Swap is excluded from the actionMask
                    _checkEmptyQuery(tokenIn, tokenOut, amountIn, actionMask);
                }
            }
        }
    }

    function _testHandleEth(
        address tokenIn,
        address tokenOut,
        uint256 actionMask
    ) internal {
        uint256 amountIn = _getAmountIn(tokenIn);
        if (_includes(actionMask, Action.HandleEth)) {
            // HandleEth is included in the actionMask
            uint256 expectedAmountOut = amountIn;
            SynapseParams memory expectedParams = SynapseParams(
                Action.HandleEth,
                address(0),
                type(uint8).max,
                type(uint8).max
            );
            _checkActionQuery(tokenIn, tokenOut, amountIn, actionMask, expectedAmountOut, expectedParams);
        } else {
            // HandleEth is excluded from the actionMask
            _checkEmptyQuery(tokenIn, tokenOut, amountIn, actionMask);
        }
    }

    function _testNoPath(
        IERC20[] memory tokensA,
        IERC20[] memory tokensB,
        uint256 actionMask
    ) internal {
        for (uint256 i = 0; i < tokensA.length; ++i) {
            address tokenA = address(tokensA[i]);
            uint256 amountInA = _getAmountIn(tokenA);
            for (uint256 j = 0; j < tokensB.length; ++j) {
                address tokenB = address(tokensB[i]);
                uint256 amountInB = _getAmountIn(tokenB);
                _checkEmptyQuery(tokenA, tokenB, amountInA, actionMask);
                _checkEmptyQuery(tokenB, tokenA, amountInB, actionMask);
            }
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _checkAddedPools() internal {
        // Check: poolsAmount()
        assertEq(quoter.poolsAmount(), 2, "!poolsAmount");
        // Check: allPools()
        Pool[] memory pools = quoter.allPools();
        assertEq(pools.length, 2, "!pools.length");
        assertEq(pools[0].pool, addedEthPool(), "!pools[0]");
        assertEq(pools[1].pool, addedUsdPool(), "!pools[1]");
        // Check: poolTokens(nEthPool)
        {
            PoolToken[] memory tokens = quoter.poolTokens(addedEthPool());
            assertEq(tokens.length, 2, "!poolTokens(neth).length");
            assertEq(tokens[0].token, address(neth), "!poolTokens(neth)[0]");
            assertEq(tokens[1].token, address(weth), "!poolTokens(neth)[1]");
            assertFalse(tokens[0].isWeth, "!poolTokens(neth)[0].isWeth");
            assertTrue(tokens[1].isWeth, "!poolTokens(neth)[1].isWeth");
        }
        // Check: poolTokens(nUsdPool)
        {
            PoolToken[] memory tokens = quoter.poolTokens(addedUsdPool());
            assertEq(tokens.length, 4, "!poolTokens(nusd).length");
            assertEq(tokens[0].token, address(nusd), "!poolTokens(nusd)[0]");
            assertEq(tokens[1].token, address(dai), "!poolTokens(nusd)[1]");
            assertEq(tokens[2].token, address(usdc), "!poolTokens(nusd)[2]");
            assertEq(tokens[3].token, address(usdt), "!poolTokens(nusd)[3]");
            assertFalse(tokens[0].isWeth, "!poolTokens(nusd)[0].isWeth");
            assertFalse(tokens[1].isWeth, "!poolTokens(nusd)[1].isWeth");
            assertFalse(tokens[2].isWeth, "!poolTokens(nusd)[2].isWeth");
            assertFalse(tokens[3].isWeth, "!poolTokens(nusd)[3].isWeth");
        }
    }

    function _checkEmptyQuery(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 actionMask
    ) internal {
        SwapQuery memory query = quoter.getAmountOut(LimitedToken(actionMask, tokenIn), tokenOut, amountIn);
        SwapQuery memory emptyQuery;
        emptyQuery.tokenOut = tokenOut;
        _compareQueries(query, emptyQuery);
        assertEq(query.rawParams, new bytes(0), "empty: !rawParams");
    }

    function _checkSameTokenQuery(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 actionMask
    ) internal {
        SwapQuery memory query = quoter.getAmountOut(LimitedToken(actionMask, tokenIn), tokenOut, amountIn);
        SwapQuery memory sameTokenQuery;
        sameTokenQuery.tokenOut = tokenIn;
        sameTokenQuery.minAmountOut = amountIn;
        sameTokenQuery.deadline = type(uint256).max;
        _compareQueries(query, sameTokenQuery);
        assertEq(query.rawParams, new bytes(0), "sameToken: !rawParams");
    }

    function _checkActionQuery(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 actionMask,
        uint256 expectedAmountOut,
        SynapseParams memory expectedParams
    ) internal {
        SwapQuery memory query = quoter.getAmountOut(LimitedToken(actionMask, tokenIn), tokenOut, amountIn);
        _compareQueries(query, _expectedQuery(tokenOut, expectedAmountOut));
        SynapseParams memory params = abi.decode(query.rawParams, (SynapseParams));
        _compareParams(params, expectedParams);
    }

    function _compareQueries(SwapQuery memory a, SwapQuery memory b) internal {
        assertEq(a.swapAdapter, b.swapAdapter, "!swapAdapter");
        assertEq(a.tokenOut, b.tokenOut, "!tokenOut");
        assertEq(a.minAmountOut, b.minAmountOut, "!minAmountOut");
        assertEq(a.deadline, b.deadline, "!deadline");
    }

    function _compareParams(SynapseParams memory a, SynapseParams memory b) internal {
        assertEq(a.pool, b.pool, "!pool");
        assertEq(uint256(a.action), uint256(b.action), "!action");
        assertEq(uint256(a.tokenIndexFrom), uint256(b.tokenIndexFrom), "!tokenIndexFrom");
        assertEq(uint256(a.tokenIndexTo), uint256(b.tokenIndexTo), "!tokenIndexTo");
    }

    function _getAmountIn(address token) internal view returns (uint256) {
        if (token == UniversalToken.ETH_ADDRESS) return 10**18;
        return 10**uint256(ERC20(token).decimals());
    }

    function _includes(uint256 actionMask, Action action) internal pure returns (bool) {
        return actionMask & (1 << uint256(action)) != 0;
    }

    function _expectedQuery(address tokenOut, uint256 amountOut) internal pure returns (SwapQuery memory) {
        return
            SwapQuery({
                swapAdapter: ROUTER_MOCK,
                tokenOut: tokenOut,
                minAmountOut: amountOut,
                deadline: type(uint256).max,
                rawParams: bytes("") // these are checked separately
            });
    }
}
