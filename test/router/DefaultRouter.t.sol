// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultRouter} from "../../contracts/router/DefaultRouter.sol";
// prettier-ignore
import {
    DeadlineExceeded,
    InsufficientOutputAmount,
    MsgValueIncorrect,
    TokenNotContract,
    TokenNotETH
} from "../../contracts/router/libs/Errors.sol";
import {Action, DefaultParams, SwapQuery} from "../../contracts/router/libs/Structs.sol";

import {FlakyAdapter} from "./harnesses/FlakyAdapter.sol";

import {MockTokenWithFee} from "../mocks/MockTokenWithFee.sol";
import {BaseTest, MockDefaultPool, MockERC20} from "./BaseTest.t.sol";

// solhint-disable not-rely-on-time
contract DefaultRouterHarness is DefaultRouter {
    function doSwap(
        address recipient,
        address tokenIn,
        uint256 amountIn,
        SwapQuery memory query
    ) external payable returns (address tokenOut, uint256 amountOut) {
        return _doSwap(recipient, tokenIn, amountIn, query);
    }

    function pullToken(
        address recipient,
        address token,
        uint256 amount
    ) external payable returns (uint256 amountPulled) {
        return _pullToken(recipient, token, amount);
    }
}

contract DefaultRouterTest is BaseTest {
    DefaultRouterHarness public router;
    FlakyAdapter public flakyAdapter;

    function setUp() public override {
        super.setUp();
        router = new DefaultRouterHarness();
        flakyAdapter = new FlakyAdapter();
    }

    function deployUsdTokens() public virtual override {
        dai = new MockERC20("DAI", 18);
        usdc = new MockERC20("USDC", 6);
        MockTokenWithFee usdt_ = new MockTokenWithFee("USDT", "USDT", 6, 0);
        usdt = MockERC20(address(usdt_));
    }

    // ══════════════════════════════════════════════ TESTS: PULLING ═══════════════════════════════════════════════════

    function testPullTokenERC20RecipientSelf() public {
        uint256 amount = 10**18;
        usdc.mint(user, amount);
        vm.prank(user);
        usdc.approve(address(router), amount);
        vm.prank(user);
        uint256 amountPulled = router.pullToken(address(router), address(usdc), amount);
        assertEq(amountPulled, amount);
        assertEq(usdc.balanceOf(address(router)), amount);
    }

    function testPullTokenERC20RecipientExternal() public {
        uint256 amount = 10**18;
        usdc.mint(user, amount);
        vm.prank(user);
        usdc.approve(address(router), amount);
        vm.prank(user);
        uint256 amountPulled = router.pullToken(userRecipient, address(usdc), amount);
        assertEq(amountPulled, amount);
        assertEq(usdc.balanceOf(address(userRecipient)), amount);
    }

    function testPullTokenERC20WithFeeRecipientSelf() public {
        // set fee to 1%
        setFee(10**16);
        uint256 amount = 10**18;
        uint256 amountAfterFee = amount - (amount / 100);
        usdt.mint(user, amount);
        vm.prank(user);
        usdt.approve(address(router), amount);
        vm.prank(user);
        uint256 amountPulled = router.pullToken(address(router), address(usdt), amount);
        assertEq(amountPulled, amountAfterFee);
        assertEq(usdt.balanceOf(address(router)), amountAfterFee);
    }

    function testPullTokenERC20WithFeeRecipientExternal() public {
        // set fee to 1%
        setFee(10**16);
        uint256 amount = 10**18;
        uint256 amountAfterFee = amount - (amount / 100);
        usdt.mint(user, amount);
        vm.prank(user);
        usdt.approve(address(router), amount);
        vm.prank(user);
        uint256 amountPulled = router.pullToken(userRecipient, address(usdt), amount);
        assertEq(amountPulled, amountAfterFee);
        assertEq(usdt.balanceOf(address(userRecipient)), amountAfterFee);
    }

    function testPullTokenERC20RevertsWhenMsgValueSupplied() public {
        uint256 amount = 10**18;
        deal(user, amount);
        usdc.mint(user, amount);
        vm.prank(user);
        usdc.approve(address(router), amount);
        vm.expectRevert(TokenNotETH.selector);
        vm.prank(user);
        router.pullToken{value: amount}(address(router), address(usdc), amount);
    }

    function testPullTokenERC20RevertsWhenNotContract() public {
        vm.expectRevert(TokenNotContract.selector);
        vm.prank(user);
        // pass EOA as token address
        router.pullToken(address(router), address(userRecipient), 10**18);
    }

    function testPullTokenETHRecipientSelf() public {
        uint256 amount = 10**18;
        deal(user, amount);
        vm.prank(user);
        uint256 amountPulled = router.pullToken{value: amount}(address(router), ETH, amount);
        assertEq(amountPulled, amount);
        assertEq(address(router).balance, amount);
    }

    function testPullTokenETHRecipientExternal() public {
        uint256 amount = 10**18;
        deal(user, amount);
        vm.prank(user);
        uint256 amountPulled = router.pullToken{value: amount}(userRecipient, ETH, amount);
        assertEq(amountPulled, amount);
        // pullToken does not forward ETH to recipient, this is done in the next external call
        assertEq(address(router).balance, amount);
    }

    function testPullTokenETHRevertsWhenMsgValueZero() public {
        vm.expectRevert(TokenNotContract.selector);
        vm.prank(user);
        router.pullToken{value: 0}(address(router), ETH, 10**18);
    }

    function testPullTokenETHRevertsWhenMsgValueLower() public {
        uint256 amount = 10**18;
        deal(user, amount - 1);
        deal(address(router), 1);
        vm.expectRevert(MsgValueIncorrect.selector);
        vm.prank(user);
        router.pullToken{value: amount - 1}(address(router), ETH, amount);
    }

    function testPullTokenETHRevertsWhenMsgValueHigher() public {
        uint256 amount = 10**18;
        deal(user, amount + 1);
        vm.expectRevert(MsgValueIncorrect.selector);
        vm.prank(user);
        router.pullToken{value: amount + 1}(address(router), ETH, amount);
    }

    // ═══════════════════════════════════════════════ TESTS: SWAPS ════════════════════════════════════════════════════

    function testAdapterActionSwapTokenToToken() public {
        checkAdapterActionSwapTokenToToken(address(router));
    }

    function testAdapterActionSwapTokenToTokenUsingFlakyAdapter() public {
        checkAdapterActionSwapTokenToToken(address(flakyAdapter));
    }

    function checkAdapterActionSwapTokenToToken(address routerAdapter) public {
        // DAI (0) -> USDC (1) swap
        uint256 amount = 10**18;
        uint256 expectedAmountOut = nusdPool.calculateSwap(0, 1, amount);
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 1})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(usdc),
            minAmountOut: expectedAmountOut,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(dai), spender: address(router), amount: amount});
        vm.prank(user);
        (address tokenOut, uint256 amountOut) = router.doSwap({
            recipient: userRecipient,
            tokenIn: address(dai),
            amountIn: amount,
            query: query
        });
        assertEq(tokenOut, address(usdc));
        assertEq(amountOut, expectedAmountOut);
        assertEq(usdc.balanceOf(address(userRecipient)), expectedAmountOut);
    }

    function testAdapterActionSwapTokenWithFeeToToken() public {
        checkAdapterActionSwapTokenWithFeeToToken(address(router));
    }

    function testAdapterActionSwapTokenWithFeeToTokenUsingFlakyAdapter() public {
        checkAdapterActionSwapTokenWithFeeToToken(address(flakyAdapter));
    }

    function checkAdapterActionSwapTokenWithFeeToToken(address routerAdapter) public {
        // Set fee to 1%
        setFee(10**16);
        // USDT (2) -> USDC (1) swap
        uint256 amount = 10**6;
        uint256 amountAfterFee = amount - (amount / 100);
        uint256 expectedAmountOut = nusdPool.calculateSwap(2, 1, amountAfterFee);
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nusdPool), tokenIndexFrom: 2, tokenIndexTo: 1})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(usdc),
            minAmountOut: expectedAmountOut,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(usdt), spender: address(router), amount: amount});
        vm.prank(user);
        (address tokenOut, uint256 amountOut) = router.doSwap({
            recipient: userRecipient,
            tokenIn: address(usdt),
            amountIn: amount,
            query: query
        });
        assertEq(tokenOut, address(usdc));
        assertEq(amountOut, expectedAmountOut);
        assertEq(usdc.balanceOf(address(userRecipient)), expectedAmountOut);
    }

    function testAdapterActionSwapTokenToETH() public {
        checkAdapterActionSwapTokenToETH(address(router));
    }

    function testAdapterActionSwapTokenToETHUsingFlakyAdapter() public {
        checkAdapterActionSwapTokenToETH(address(flakyAdapter));
    }

    function checkAdapterActionSwapTokenToTokenWithFee(address routerAdapter) public {
        // Set fee to 1%
        setFee(10**16);
        // DAI (0) -> USDT (2) swap
        uint256 amount = 10**18;
        uint256 amountOutBeforeFee = nusdPool.calculateSwap(0, 2, amount);
        // First time fee is applied when swap is performed, and tokens are sent to the Adapter
        uint256 amountOutPostSwap = amountOutBeforeFee - (amountOutBeforeFee / 100);
        // Second time fee is applied when tokens are sent to the recipient
        uint256 expectedAmountOut = amountOutPostSwap - (amountOutPostSwap / 100);
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 2})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(usdt),
            minAmountOut: expectedAmountOut,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(dai), spender: address(router), amount: amount});
        vm.prank(user);
        (address tokenOut, uint256 amountOut) = router.doSwap({
            recipient: userRecipient,
            tokenIn: address(dai),
            amountIn: amount,
            query: query
        });
        assertEq(tokenOut, address(usdt));
        // NOTE: this will return the amount of tokens "sent" to recipient
        assertEq(amountOut, amountOutPostSwap);
        // However, the recipient will receive less due to the fee
        assertEq(usdt.balanceOf(address(userRecipient)), expectedAmountOut);
    }

    function checkAdapterActionSwapTokenToETH(address routerAdapter) public {
        // nETH(0) -> ETH (1) swap
        uint256 amount = 10**18;
        uint256 expectedAmountOut = nethPool.calculateSwap(0, 1, amount);
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nethPool), tokenIndexFrom: 0, tokenIndexTo: 1})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: ETH,
            minAmountOut: expectedAmountOut,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(neth), spender: address(router), amount: amount});
        vm.prank(user);
        (address tokenOut, uint256 amountOut) = router.doSwap({
            recipient: userRecipient,
            tokenIn: address(neth),
            amountIn: amount,
            query: query
        });
        assertEq(tokenOut, ETH);
        assertEq(amountOut, expectedAmountOut);
        assertEq(address(userRecipient).balance, expectedAmountOut);
    }

    function testAdapterActionSwapETHToToken() public {
        checkAdapterActionSwapETHToToken(address(router));
    }

    function testAdapterActionSwapETHToTokenUsingFlakyAdapter() public {
        checkAdapterActionSwapETHToToken(address(flakyAdapter));
    }

    function checkAdapterActionSwapETHToToken(address routerAdapter) public {
        // ETH (1) -> nETH(0) swap
        uint256 amount = 10**18;
        uint256 expectedAmountOut = nethPool.calculateSwap(1, 0, amount);
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nethPool), tokenIndexFrom: 1, tokenIndexTo: 0})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(neth),
            minAmountOut: expectedAmountOut,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        deal(user, amount);
        vm.prank(user);
        (address tokenOut, uint256 amountOut) = router.doSwap{value: amount}({
            recipient: userRecipient,
            tokenIn: ETH,
            amountIn: amount,
            query: query
        });
        assertEq(tokenOut, address(neth));
        assertEq(amountOut, expectedAmountOut);
        assertEq(neth.balanceOf(address(userRecipient)), expectedAmountOut);
    }

    function testAdapterActionSwapRevertsWhenDeadlineExceeded() public {
        checkAdapterActionSwapRevertsWhenDeadlineExceeded(address(router));
    }

    function testAdapterActionSwapRevertsWhenDeadlineExceededUsingFlakyAdapter() public {
        checkAdapterActionSwapRevertsWhenDeadlineExceeded(address(flakyAdapter));
    }

    function checkAdapterActionSwapRevertsWhenDeadlineExceeded(address routerAdapter) public {
        // DAI (0) -> USDC (1) swap
        uint256 amount = 10**18;
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 1})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(usdc),
            minAmountOut: 0,
            deadline: block.timestamp - 1,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(dai), spender: address(router), amount: amount});
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(user);
        router.doSwap({recipient: userRecipient, tokenIn: address(dai), amountIn: amount, query: query});
    }

    function testAdapterActionSwapRevertsWhenInsufficientOutputAmount() public {
        checkAdapterActionSwapRevertsWhenInsufficientOutputAmount(address(router));
    }

    function testAdapterActionSwapRevertsWhenInsufficientOutputAmountUsingFlakyAdapter() public {
        checkAdapterActionSwapRevertsWhenInsufficientOutputAmount(address(flakyAdapter));
    }

    function checkAdapterActionSwapRevertsWhenInsufficientOutputAmount(address routerAdapter) public {
        // DAI (0) -> USDC (1) swap
        uint256 amount = 10**18;
        uint256 expectedAmountOut = nusdPool.calculateSwap(0, 1, amount);
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.Swap, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 1})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(usdc),
            minAmountOut: expectedAmountOut + 1,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(dai), spender: address(router), amount: amount});
        vm.expectRevert(InsufficientOutputAmount.selector);
        vm.prank(user);
        router.doSwap({recipient: userRecipient, tokenIn: address(dai), amountIn: amount, query: query});
    }

    // ══════════════════════════════════════════ TESTS: ADDING LIQUIDITY ══════════════════════════════════════════════

    function testAdapterActionAddLiquidity() public {
        checkAdapterActionAddLiquidity(address(router));
    }

    function testAdapterActionAddLiquidityUsingFlakyAdapter() public {
        checkAdapterActionAddLiquidity(address(flakyAdapter));
    }

    function checkAdapterActionAddLiquidity(address routerAdapter) public {
        // DAI (0) -> nUSD (0xFF) add liquidity
        uint256 amount = 10**18;
        uint256 expectedAmountOut = calculateAddLiquidity(address(dai), amount);
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.AddLiquidity, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 0xFF})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(nusd),
            minAmountOut: expectedAmountOut,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(dai), spender: address(router), amount: amount});
        vm.prank(user);
        (address tokenOut, uint256 amountOut) = router.doSwap({
            recipient: userRecipient,
            tokenIn: address(dai),
            amountIn: amount,
            query: query
        });
        assertEq(tokenOut, address(nusd));
        assertEq(amountOut, expectedAmountOut);
        assertEq(nusd.balanceOf(address(userRecipient)), expectedAmountOut);
    }

    function testAdapterActionAddLiquidityRevertsWhenDeadlineExceeded() public {
        checkAdapterActionAddLiquidityRevertsWhenDeadlineExceeded(address(router));
    }

    function testAdapterActionAddLiquidityRevertsWhenDeadlineExceededUsingFlakyAdapter() public {
        checkAdapterActionAddLiquidityRevertsWhenDeadlineExceeded(address(flakyAdapter));
    }

    function checkAdapterActionAddLiquidityRevertsWhenDeadlineExceeded(address routerAdapter) public {
        // DAI (0) -> nUSD (0xFF) add liquidity
        uint256 amount = 10**18;
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.AddLiquidity, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 0xFF})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(nusd),
            minAmountOut: 0,
            deadline: block.timestamp - 1,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(dai), spender: address(router), amount: amount});
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(user);
        router.doSwap({recipient: userRecipient, tokenIn: address(dai), amountIn: amount, query: query});
    }

    function testAdapterActionAddLiquidityRevertsWhenInsufficientOutputAmount() public {
        checkAdapterActionAddLiquidityRevertsWhenInsufficientOutputAmount(address(router));
    }

    function testAdapterActionAddLiquidityRevertsWhenInsufficientOutputAmountUsingFlakyAdapter() public {
        checkAdapterActionAddLiquidityRevertsWhenInsufficientOutputAmount(address(flakyAdapter));
    }

    function checkAdapterActionAddLiquidityRevertsWhenInsufficientOutputAmount(address routerAdapter) public {
        // DAI (0) -> nUSD (0xFF) add liquidity
        uint256 amount = 10**18;
        uint256 expectedAmountOut = calculateAddLiquidity(address(dai), amount);
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.AddLiquidity, pool: address(nusdPool), tokenIndexFrom: 0, tokenIndexTo: 0xFF})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(nusd),
            minAmountOut: expectedAmountOut + 1,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(dai), spender: address(router), amount: amount});
        vm.expectRevert(InsufficientOutputAmount.selector);
        vm.prank(user);
        router.doSwap({recipient: userRecipient, tokenIn: address(dai), amountIn: amount, query: query});
    }

    // ═════════════════════════════════════════ TESTS: REMOVING LIQUIDITY ═════════════════════════════════════════════

    function testAdapterActionRemoveLiquidity() public {
        checkAdapterActionRemoveLiquidity(address(router));
    }

    function testAdapterActionRemoveLiquidityUsingFlakyAdapter() public {
        checkAdapterActionRemoveLiquidity(address(flakyAdapter));
    }

    function checkAdapterActionRemoveLiquidity(address routerAdapter) public {
        // nUSD (0xFF) -> DAI (0) remove liquidity
        uint256 amount = 10**18;
        uint256 expectedAmountOut = nusdPool.calculateRemoveLiquidityOneToken(amount, 0);
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.RemoveLiquidity,
                pool: address(nusdPool),
                tokenIndexFrom: 0xFF,
                tokenIndexTo: 0
            })
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(dai),
            minAmountOut: expectedAmountOut,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(nusd), spender: address(router), amount: amount});
        vm.prank(user);
        (address tokenOut, uint256 amountOut) = router.doSwap({
            recipient: userRecipient,
            tokenIn: address(nusd),
            amountIn: amount,
            query: query
        });
        assertEq(tokenOut, address(dai));
        assertEq(amountOut, expectedAmountOut);
        assertEq(dai.balanceOf(address(userRecipient)), expectedAmountOut);
    }

    function testAdapterActionRemoveLiquidityRevertsWhenDeadlineExceeded() public {
        checkAdapterActionRemoveLiquidityRevertsWhenDeadlineExceeded(address(router));
    }

    function testAdapterActionRemoveLiquidityRevertsWhenDeadlineExceededUsingFlakyAdapter() public {
        checkAdapterActionRemoveLiquidityRevertsWhenDeadlineExceeded(address(flakyAdapter));
    }

    function checkAdapterActionRemoveLiquidityRevertsWhenDeadlineExceeded(address routerAdapter) public {
        // nUSD (0xFF) -> DAI (0) remove liquidity
        uint256 amount = 10**18;
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.RemoveLiquidity,
                pool: address(nusdPool),
                tokenIndexFrom: 0xFF,
                tokenIndexTo: 0
            })
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(dai),
            minAmountOut: 0,
            deadline: block.timestamp - 1,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(nusd), spender: address(router), amount: amount});
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(user);
        router.doSwap({recipient: userRecipient, tokenIn: address(nusd), amountIn: amount, query: query});
    }

    function testAdapterActionRemoveLiquidityRevertsWhenInsufficientOutputAmount() public {
        checkAdapterActionRemoveLiquidityRevertsWhenInsufficientOutputAmount(address(router));
    }

    function testAdapterActionRemoveLiquidityRevertsWhenInsufficientOutputAmountUsingFlakyAdapter() public {
        checkAdapterActionRemoveLiquidityRevertsWhenInsufficientOutputAmount(address(flakyAdapter));
    }

    function checkAdapterActionRemoveLiquidityRevertsWhenInsufficientOutputAmount(address routerAdapter) public {
        // nUSD (0xFF) -> DAI (0) remove liquidity
        uint256 amount = 10**18;
        uint256 expectedAmountOut = nusdPool.calculateRemoveLiquidityOneToken(amount, 0);
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.RemoveLiquidity,
                pool: address(nusdPool),
                tokenIndexFrom: 0xFF,
                tokenIndexTo: 0
            })
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(dai),
            minAmountOut: expectedAmountOut + 1,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(nusd), spender: address(router), amount: amount});
        vm.expectRevert(InsufficientOutputAmount.selector);
        vm.prank(user);
        router.doSwap({recipient: userRecipient, tokenIn: address(nusd), amountIn: amount, query: query});
    }

    // ════════════════════════════════════════════ TESTS: ETH <> WETH ═════════════════════════════════════════════════

    function testAdapterActionHandleEthWrap() public {
        checkAdapterActionHandleEthWrap(address(router));
    }

    function testAdapterActionHandleEthWrapUsingFlakyAdapter() public {
        checkAdapterActionHandleEthWrap(address(flakyAdapter));
    }

    function checkAdapterActionHandleEthWrap(address routerAdapter) public {
        // Wrap native ETH into WETH
        uint256 amount = 10**18;
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: address(weth),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        deal(user, amount);
        vm.prank(user);
        (address tokenOut, uint256 amountOut) = router.doSwap{value: amount}({
            recipient: userRecipient,
            tokenIn: ETH,
            amountIn: amount,
            query: query
        });
        assertEq(tokenOut, address(weth));
        assertEq(amountOut, amount);
        assertEq(weth.balanceOf(address(userRecipient)), amount);
    }

    function testAdapterActionHandleEthUnwrap() public {
        checkAdapterActionHandleEthUnwrap(address(router));
    }

    function testAdapterActionHandleEthUnwrapUsingFlakyAdapter() public {
        checkAdapterActionHandleEthUnwrap(address(flakyAdapter));
    }

    function checkAdapterActionHandleEthUnwrap(address routerAdapter) public {
        // Unwrap WETH into native ETH
        uint256 amount = 10**18;
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: ETH,
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(weth), spender: address(router), amount: amount});
        vm.prank(user);
        (address tokenOut, uint256 amountOut) = router.doSwap({
            recipient: userRecipient,
            tokenIn: address(weth),
            amountIn: amount,
            query: query
        });
        assertEq(tokenOut, ETH);
        assertEq(amountOut, amount);
        assertEq(address(userRecipient).balance, amount);
    }

    function testAdapterActionHandleEthRevertsWhenDeadlineExceeded() public {
        checkAdapterActionHandleEthRevertsWhenDeadlineExceeded(address(router));
    }

    function testAdapterActionHandleEthRevertsWhenDeadlineExceededUsingFlakyAdapter() public {
        checkAdapterActionHandleEthRevertsWhenDeadlineExceeded(address(flakyAdapter));
    }

    function checkAdapterActionHandleEthRevertsWhenDeadlineExceeded(address routerAdapter) public {
        // Unwrap WETH into native ETH
        uint256 amount = 10**18;
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: ETH,
            minAmountOut: amount,
            deadline: block.timestamp - 1,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(weth), spender: address(router), amount: amount});
        vm.expectRevert(DeadlineExceeded.selector);
        vm.prank(user);
        router.doSwap({recipient: userRecipient, tokenIn: address(weth), amountIn: amount, query: query});
    }

    function testAdapterActionHandleEthRevertsWhenInsufficientOutputAmount() public {
        checkAdapterActionHandleEthRevertsWhenInsufficientOutputAmount(address(router));
    }

    function testAdapterActionHandleEthRevertsWhenInsufficientOutputAmountUsingFlakyAdapter() public {
        checkAdapterActionHandleEthRevertsWhenInsufficientOutputAmount(address(flakyAdapter));
    }

    function checkAdapterActionHandleEthRevertsWhenInsufficientOutputAmount(address routerAdapter) public {
        // Unwrap WETH into native ETH
        uint256 amount = 10**18;
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
        );
        SwapQuery memory query = SwapQuery({
            routerAdapter: routerAdapter,
            tokenOut: ETH,
            minAmountOut: amount + 1,
            deadline: block.timestamp,
            rawParams: rawParams
        });
        mintToUserAndApprove({token: address(weth), spender: address(router), amount: amount});
        vm.expectRevert(InsufficientOutputAmount.selector);
        vm.prank(user);
        router.doSwap({recipient: userRecipient, tokenIn: address(weth), amountIn: amount, query: query});
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function setFee(uint256 fee) public {
        MockTokenWithFee(address(usdt)).setFee(fee);
    }
}
