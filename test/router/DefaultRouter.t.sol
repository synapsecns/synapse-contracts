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

import {MockTokenWithFee} from "../mocks/MockTokenWithFee.sol";
import {BaseTest, MockDefaultPool, MockERC20} from "./BaseTest.t.sol";

contract DefaultRouterHarness is DefaultRouter {
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

    function setUp() public override {
        super.setUp();
        router = new DefaultRouterHarness();
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

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function setFee(uint256 fee) public {
        MockTokenWithFee(address(usdt)).setFee(fee);
    }
}
