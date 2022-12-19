// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../../../contracts/bridge/wrappers/zap/SwapQuoter.sol";
import "../../../utils/Utilities06.sol";

// solhint-disable func-name-mixedcase
contract SwapQuoterTest is Utilities06 {
    address internal constant ZAP_MOCK = address(123456);
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

    function setUp() public override {
        super.setUp();

        quoter = new SwapQuoter(ZAP_MOCK);
        // Deploy ETH tokens
        neth = deployERC20("nETH", 18);
        weth = deployERC20("WETH", 18);
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

        quoter.transferOwnership(OWNER);
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

    function test_addPool() public {
        vm.prank(OWNER);
        quoter.addPool(nEthPool);
        vm.prank(OWNER);
        quoter.addPool(nUsdPool);
        _checkAddedPools();
    }

    function test_addPools() public {
        address[] memory pools = new address[](2);
        pools[0] = nEthPool;
        pools[1] = nUsdPool;
        vm.prank(OWNER);
        quoter.addPools(pools);
        _checkAddedPools();
    }

    function test_getAmountOut_nETH() public {
        test_addPools();
        _checkQuotes(ISwap(nEthPool), nEthTokens);
    }

    function test_getAmountOut_nUSD() public {
        test_addPools();
        _checkQuotes(ISwap(nUsdPool), nUsdTokens);
    }

    function test_getAmountOut_noPath() public {
        test_addPools();
        for (uint256 i = 0; i < nEthTokens.length; ++i) {
            address tokenIn = address(nEthTokens[i]);
            uint256 amountIn = 10**uint256(ERC20(tokenIn).decimals());
            for (uint256 j = 0; j < nUsdTokens.length; ++j) {
                address tokenOut = address(nUsdTokens[j]);
                uint256 amountOut = 10**uint256(ERC20(tokenOut).decimals());
                // Check tokenIn -> tokenOut: should not exist
                _checkEmptyQuery(quoter.getAmountOut(tokenIn, tokenOut, amountIn));
                // Check tokenOut -> tokenIn: should not exist
                _checkEmptyQuery(quoter.getAmountOut(tokenOut, tokenIn, amountOut));
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
        address[] memory pools = quoter.allPools();
        assertEq(pools.length, 2, "!pools.length");
        assertEq(pools[0], nEthPool, "!pools[0]");
        assertEq(pools[1], nUsdPool, "!pools[1]");
        // Check: poolTokens(nEthPool)
        {
            address[] memory tokens = quoter.poolTokens(nEthPool);
            assertEq(tokens.length, 2, "!poolTokens(neth).length");
            assertEq(tokens[0], address(neth), "!poolTokens(neth)[0]");
            assertEq(tokens[1], address(weth), "!poolTokens(neth)[1]");
        }
        // Check: poolTokens(nUsdPool)
        {
            address[] memory tokens = quoter.poolTokens(nUsdPool);
            assertEq(tokens.length, 4, "!poolTokens(nusd).length");
            assertEq(tokens[0], address(nusd), "!poolTokens(nusd)[0]");
            assertEq(tokens[1], address(dai), "!poolTokens(nusd)[1]");
            assertEq(tokens[2], address(usdc), "!poolTokens(nusd)[2]");
            assertEq(tokens[3], address(usdt), "!poolTokens(nusd)[3]");
        }
    }

    function _checkQuotes(ISwap pool, IERC20[] memory tokens) internal {
        uint256 amount = tokens.length;
        for (uint8 i = 0; i < amount; ++i) {
            address tokenIn = address(tokens[i]);
            uint256 amountIn = 10**uint256(ERC20(tokenIn).decimals());
            for (uint8 j = 0; j < amount; ++j) {
                address tokenOut = address(tokens[j]);
                SwapQuery memory query = quoter.getAmountOut(tokenIn, tokenOut, amountIn);
                if (i == j) {
                    _checkEqualTokensQuery(query, tokenIn, amountIn);
                } else {
                    assertEq(query.swapAdapter, ZAP_MOCK, "i != j: !swapAdapter");
                    assertEq(query.tokenOut, tokenOut, "i != j: !tokenOut");
                    assertEq(query.minAmountOut, pool.calculateSwap(i, j, amountIn), "i != j: !minAmountOut");
                    assertEq(query.deadline, type(uint256).max, "i != j: !deadline");
                    SynapseParams memory params = abi.decode(query.rawParams, (SynapseParams));
                    assertEq(params.pool, address(pool), "i != j: params.pool");
                    assertEq(params.tokenIndexFrom, uint256(i), "i != j: params.tokenIndexFrom");
                    assertEq(params.tokenIndexTo, uint256(j), "i != j: params.tokenIndexTo");
                }
            }
        }
    }

    function _checkEmptyQuery(SwapQuery memory query) internal {
        assertEq(query.swapAdapter, address(0), "empty: !swapAdapter");
        assertEq(query.tokenOut, address(0), "empty: !tokenOut");
        assertEq(query.minAmountOut, 0, "empty: !minAmountOut");
        assertEq(query.deadline, 0, "empty: !deadline");
        assertEq(query.rawParams, new bytes(0), "empty: !rawParams");
    }

    function _checkEqualTokensQuery(
        SwapQuery memory query,
        address tokenIn,
        uint256 amountIn
    ) internal {
        assertEq(query.swapAdapter, address(0), "equal: !swapAdapter");
        assertEq(query.tokenOut, tokenIn, "equal: !tokenOut");
        assertEq(query.minAmountOut, amountIn, "equal: !minAmountOut");
        assertEq(query.deadline, 0, "equal: !deadline");
        assertEq(query.rawParams, new bytes(0), "equal: !rawParams");
    }
}
