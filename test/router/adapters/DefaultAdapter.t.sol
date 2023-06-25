// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultAdapter} from "../../../contracts/router/adapters/DefaultAdapter.sol";
// prettier-ignore
import {
    MsgValueIncorrect,
    PoolNotFound,
    TokenAddressMismatch,
    TokensIdentical
} from "../../../contracts/router/libs/Errors.sol";
import {Action, DefaultParams} from "../../../contracts/router/libs/Structs.sol";

import {BaseTest, MockDefaultPool, MockERC20} from "../BaseTest.t.sol";

contract DefaultAdapterHarness is DefaultAdapter {
    /// @notice Exposes the internal function `_getPoolTokens`
    function getPoolTokens(address pool) external view returns (address[] memory tokens) {
        return _getPoolTokens(pool);
    }

    /// @notice Exposes the internal function `_getPoolTokenIndex`
    function getPoolSwapQuote(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        return _getPoolSwapQuote(pool, tokenIndexFrom, tokenIndexTo, amountIn);
    }
}

contract DefaultAdapterTest is BaseTest {
    DefaultAdapterHarness public adapter;

    function setUp() public override {
        super.setUp();

        adapter = new DefaultAdapterHarness();
    }

    function testAdapterActionSwapTokenToTokenDiffDecimals() public {
        checkAdapterSwap(address(nusdPool), address(dai), 1 * 10**18, address(usdc));
        checkAdapterSwap(address(nusdPool), address(usdc), 1 * 10**6, address(dai));
    }

    function testAdapterActionSwapTokenToTokenSameDecimals() public {
        checkAdapterSwap(address(nusdPool), address(usdc), 1 * 10**6, address(usdt));
        checkAdapterSwap(address(nusdPool), address(usdt), 1 * 10**6, address(usdc));
    }

    function testAdapterActionSwapTokenToTokenFromWETH() public {
        checkAdapterSwap(address(nethPool), address(weth), 1 * 10**18, address(neth));
    }

    function testAdapterActionSwapTokenToTokenToWETH() public {
        checkAdapterSwap(address(nethPool), address(neth), 1 * 10**18, address(weth));
    }

    function testAdapterActionSwapETHToToken() public {
        checkAdapterSwap(address(nethPool), ETH, 1 * 10**18, address(neth));
    }

    function testAdapterActionSwapTokenToETH() public {
        checkAdapterSwap(address(nethPool), address(neth), 1 * 10**18, ETH);
    }

    function testAdapterActionAddLiquidityDiffDecimals() public {
        checkAdapterAddLiquidity(address(usdc), 1 * 10**6);
        checkAdapterAddLiquidity(address(usdt), 1 * 10**6);
    }

    function testAdapterActionAddLiquiditySameDecimals() public {
        checkAdapterAddLiquidity(address(dai), 1 * 10**18);
    }

    function testAdapterActionRemoveLiquidityDiffDecimals() public {
        checkAdapterRemoveLiquidity(1 * 10**6, address(usdc));
        checkAdapterRemoveLiquidity(1 * 10**6, address(usdt));
    }

    function testAdapterActionRemoveLiquiditySameDecimals() public {
        checkAdapterRemoveLiquidity(1 * 10**18, address(dai));
    }

    function testAdapterActionHandleEthWrap() public {
        checkHandleEth({amountIn: 10**18, wrapETH: true});
    }

    function testAdapterActionHandleEthUnwrap() public {
        checkHandleEth({amountIn: 10**18, wrapETH: false});
    }

    // ════════════════════════════════════════════ TESTS: SWAP REVERTS ════════════════════════════════════════════════

    function testAdapterActionSwapRevertsWhenTokensIdentical() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 0})
        );
        vm.expectRevert(TokensIdentical.selector);
        adapter.adapterSwap(userRecipient, address(dai), 10**18, address(dai), rawParams);
    }

    function testAdapterActionSwapRevertsWhenPoolNotFound() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(0), tokenIndexFrom: 0, tokenIndexTo: 1})
        );
        vm.expectRevert(PoolNotFound.selector);
        adapter.adapterSwap(userRecipient, address(dai), 10**18, address(usdc), rawParams);
    }

    function testAdapterActionSwapRevertsWhenMsgValueLower() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nethPool), tokenIndexFrom: 1, tokenIndexTo: 0})
        );
        vm.expectRevert(MsgValueIncorrect.selector);
        adapter.adapterSwap{value: 10**18 - 1}(userRecipient, ETH, 10**18, address(neth), rawParams);
    }

    function testAdapterActionSwapRevertsWhenMsgValueHigher() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nethPool), tokenIndexFrom: 1, tokenIndexTo: 0})
        );
        vm.expectRevert(MsgValueIncorrect.selector);
        adapter.adapterSwap{value: 10**18 + 1}(userRecipient, ETH, 10**18, address(neth), rawParams);
    }

    function testAdapterActionSwapRevertsWhenMsgValueForERC20() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nethPool), tokenIndexFrom: 1, tokenIndexTo: 0})
        );
        vm.expectRevert(MsgValueIncorrect.selector);
        adapter.adapterSwap{value: 10**18}(userRecipient, address(weth), 10**18, address(neth), rawParams);
    }

    function testAdapterActionSwapRevertsWhenIncorrectTokenOut() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 1})
        );
        vm.expectRevert(TokenAddressMismatch.selector);
        // Should be usdc, not usdt
        adapter.adapterSwap(userRecipient, address(dai), 10**18, address(usdt), rawParams);
    }

    // ═══════════════════════════════════════ TESTS: ADD LIQUIDITY REVERTS ════════════════════════════════════════════

    function testAdapterActionAddLiquidityRevertsWhenTokensIdentical() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.AddLiquidity, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 0})
        );
        vm.expectRevert(TokensIdentical.selector);
        adapter.adapterSwap(userRecipient, address(dai), 10**18, address(dai), rawParams);
    }

    function testAdapterActionAddLiquidityRevertsWhenPoolNotFound() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.AddLiquidity, pool: address(0), tokenIndexFrom: 0, tokenIndexTo: 0xFF})
        );
        vm.expectRevert(PoolNotFound.selector);
        adapter.adapterSwap(userRecipient, address(dai), 10**18, address(nusd), rawParams);
    }

    function testAdapterActionAddLiquidityRevertsWhenMsgValueWithERC20() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.AddLiquidity, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 0xFF})
        );
        vm.expectRevert(MsgValueIncorrect.selector);
        adapter.adapterSwap{value: 10**18}(userRecipient, address(dai), 10**18, address(nusd), rawParams);
    }

    function testAdapterActionAddLiquidityRevertsWhenIncorrectTokenOut() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.AddLiquidity, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 0xFF})
        );
        vm.expectRevert(TokenAddressMismatch.selector);
        // Should be nusd, not usdt
        adapter.adapterSwap(userRecipient, address(dai), 10**18, address(usdt), rawParams);
    }

    // ══════════════════════════════════════ TESTS: REMOVE LIQUIDITY REVERTS ══════════════════════════════════════════

    function testAdapterActionRemoveLiquidityRevertsWhenTokensIdentical() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.RemoveLiquidity, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 0})
        );
        vm.expectRevert(TokensIdentical.selector);
        adapter.adapterSwap(userRecipient, address(dai), 10**18, address(dai), rawParams);
    }

    function testAdapterActionRemoveLiquidityRevertsWhenPoolNotFound() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.RemoveLiquidity, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0})
        );
        vm.expectRevert(PoolNotFound.selector);
        adapter.adapterSwap(userRecipient, address(nusd), 10**18, address(dai), rawParams);
    }

    function testAdapterActionRemoveLiquidityRevertsWhenMsgValueWithERC20() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.RemoveLiquidity,
                pool: address(nusdPool),
                tokenIndexFrom: 0xFF,
                tokenIndexTo: 0
            })
        );
        vm.expectRevert(MsgValueIncorrect.selector);
        adapter.adapterSwap{value: 10**18}(userRecipient, address(nusd), 10**18, address(dai), rawParams);
    }

    function testAdapterActionRemoveLiquidityRevertsWhenIncorrectTokenOut() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.RemoveLiquidity,
                pool: address(nusdPool),
                tokenIndexFrom: 0xFF,
                tokenIndexTo: 0
            })
        );
        vm.expectRevert(TokenAddressMismatch.selector);
        // Should be dai, not usdt
        adapter.adapterSwap(userRecipient, address(nusd), 10**18, address(usdt), rawParams);
    }

    // ═════════════════════════════════════════ TESTS: HANDLE ETH REVERTS ═════════════════════════════════════════════

    function testAdapterActionHandleEthRevertsWhenTokensIdentical() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
        );
        vm.expectRevert(TokensIdentical.selector);
        adapter.adapterSwap(userRecipient, address(weth), 10**18, address(weth), rawParams);
    }

    function testAdapterActionHandleEthRevertsWhenMsgValueLower() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
        );
        vm.expectRevert(MsgValueIncorrect.selector);
        adapter.adapterSwap{value: 10**18 - 1}(userRecipient, ETH, 10**18, address(weth), rawParams);
    }

    function testAdapterActionHandleEthRevertsWhenMsgValueHigher() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
        );
        vm.expectRevert(MsgValueIncorrect.selector);
        adapter.adapterSwap{value: 10**18 + 1}(userRecipient, ETH, 10**18, address(weth), rawParams);
    }

    function testAdapterActionHandleEthRevertsWhenMsgValueWithERC20() public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
        );
        vm.expectRevert(MsgValueIncorrect.selector);
        adapter.adapterSwap{value: 10**18}(userRecipient, address(weth), 10**18, ETH, rawParams);
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        assertEq(adapter.getPoolTokens(address(nethPool)), poolTokens[address(nethPool)]);
        assertEq(adapter.getPoolTokens(address(nusdPool)), poolTokens[address(nusdPool)]);
    }

    function testGetPoolSwapQuote() public {
        uint256 expectedAmountOut = nusdPool.calculateSwap(0, 1, 10**18);
        assertEq(adapter.getPoolSwapQuote(address(nusdPool), 0, 1, 10**18), expectedAmountOut);
    }

    function testGetPoolSwapQuoteReturnsZeroOnRevert() public {
        // Pool getter will revert when token indexes are out of range
        vm.expectRevert();
        nusdPool.calculateSwap(0, 4, 10**18);
        // Adapter should return 0 instead
        assertEq(adapter.getPoolSwapQuote(address(nusdPool), 0, 4, 10**18), 0);
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function checkAdapterSwap(
        address pool,
        address tokenIn,
        uint256 amountIn,
        address tokenOut
    ) public {
        // Test with external recipient
        checkAdapterSwap(pool, tokenIn, amountIn, tokenOut, userRecipient);
        // Test with self recipient
        checkAdapterSwap(pool, tokenIn, amountIn, tokenOut, address(adapter));
    }

    function checkAdapterSwap(
        address pool,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        address recipient
    ) public {
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.Swap,
                pool: pool,
                tokenIndexFrom: tokenToIndex[tokenIn],
                tokenIndexTo: tokenToIndex[tokenOut]
            })
        );
        uint256 expectedAmountOut = MockDefaultPool(pool).calculateSwap(
            tokenToIndex[tokenIn],
            tokenToIndex[tokenOut],
            amountIn
        );
        // Mint test tokens to adapter
        if (tokenIn != ETH) {
            MockERC20(tokenIn).mint(address(adapter), amountIn);
        } else {
            deal(user, amountIn);
        }
        uint256 msgValue = tokenIn == ETH ? amountIn : 0;
        vm.prank(user);
        adapter.adapterSwap{value: msgValue}(recipient, tokenIn, amountIn, tokenOut, rawParams);
        assertEq(balanceOf(tokenOut, recipient), expectedAmountOut);
        clearBalance(tokenOut, recipient);
    }

    function checkAdapterAddLiquidity(address tokenIn, uint256 amountIn) public {
        // Test with external recipient
        checkAdapterAddLiquidity(tokenIn, amountIn, userRecipient);
        // Test with self recipient
        checkAdapterAddLiquidity(tokenIn, amountIn, address(adapter));
    }

    function checkAdapterAddLiquidity(
        address tokenIn,
        uint256 amountIn,
        address recipient
    ) public {
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.AddLiquidity,
                pool: address(nusdPool),
                tokenIndexFrom: tokenToIndex[tokenIn],
                tokenIndexTo: 0xFF
            })
        );
        uint256[] memory amounts = new uint256[](3);
        amounts[tokenToIndex[tokenIn]] = amountIn;
        uint256 expectedAmountOut = nusdPool.calculateAddLiquidity(amounts);
        // Mint test tokens to adapter
        MockERC20(tokenIn).mint(address(adapter), amountIn);
        vm.prank(user);
        adapter.adapterSwap(recipient, tokenIn, amountIn, address(nusd), rawParams);
        assertEq(balanceOf(address(nusd), recipient), expectedAmountOut);
        clearBalance(address(nusd), recipient);
    }

    function checkAdapterRemoveLiquidity(uint256 amountIn, address tokenOut) public {
        // Test with external recipient
        checkAdapterRemoveLiquidity(amountIn, tokenOut, userRecipient);
        // Test with self recipient
        checkAdapterRemoveLiquidity(amountIn, tokenOut, address(adapter));
    }

    function checkAdapterRemoveLiquidity(
        uint256 amountIn,
        address tokenOut,
        address recipient
    ) public {
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.RemoveLiquidity,
                pool: address(nusdPool),
                tokenIndexFrom: 0xFF,
                tokenIndexTo: tokenToIndex[tokenOut]
            })
        );
        uint256 expectedAmountOut = nusdPool.calculateRemoveLiquidityOneToken(amountIn, tokenToIndex[tokenOut]);
        // Mint test tokens to adapter
        MockERC20(address(nusd)).mint(address(adapter), amountIn);
        vm.prank(user);
        adapter.adapterSwap(recipient, address(nusd), amountIn, tokenOut, rawParams);
        assertEq(balanceOf(tokenOut, recipient), expectedAmountOut);
        clearBalance(tokenOut, recipient);
    }

    function checkHandleEth(uint256 amountIn, bool wrapETH) public {
        // Test with external recipient
        checkHandleEth(amountIn, wrapETH, userRecipient);
        // Test with self recipient
        checkHandleEth(amountIn, wrapETH, address(adapter));
    }

    function checkHandleEth(
        uint256 amountIn,
        bool wrapETH,
        address recipient
    ) public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
        );
        uint256 expectedAmountOut = amountIn;
        address tokenIn = wrapETH ? address(weth) : ETH;
        address tokenOut = wrapETH ? ETH : address(weth);
        // Mint test tokens to adapter
        if (tokenIn != ETH) {
            MockERC20(tokenIn).mint(address(adapter), amountIn);
        } else {
            deal(user, amountIn);
        }
        uint256 msgValue = tokenIn == ETH ? amountIn : 0;
        vm.prank(user);
        adapter.adapterSwap{value: msgValue}(recipient, tokenIn, amountIn, tokenOut, rawParams);
        assertEq(balanceOf(tokenOut, recipient), expectedAmountOut);
        clearBalance(tokenOut, recipient);
    }
}
