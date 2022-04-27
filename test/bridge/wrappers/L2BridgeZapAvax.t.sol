// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./L2BridgeZapTest.sol";

contract L2ZapTestAvax is L2BridgeZapTest {
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public constant BRIDGE = 0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE;

    address public constant NUSD = 0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46;
    address public constant NETH = 0x19E1ae0eE35c0404f835521146206595d37981ae;

    address public constant SYN = 0x1f1E7c893855525b303f99bDF5c3c05Be09ca251;

    // DAI.e
    address public constant DAI = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;

    // WETH.e
    address public constant WETH = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;

    address public constant NUSD_POOL =
        0xED2a7edd7413021d440b09D654f3b87712abAB66;

    // Wrapper for Aave pool
    address public constant NETH_POOL =
        0xdd60483Ace9B215a7c019A44Be2F22Aa9982652E;

    constructor() L2BridgeZapTest() {
        IERC20(NUSD).approve(address(zap), MAX_UINT256);
        IERC20(NETH).approve(address(zap), MAX_UINT256);
        IERC20(WETH).approve(address(zap), MAX_UINT256);
        IERC20(DAI).approve(address(zap), MAX_UINT256);
        IERC20(SYN).approve(address(zap), MAX_UINT256);
    }

    function _deployZap() internal override returns (address _zap) {
        address[] memory swaps = new address[](2);
        address[] memory tokens = new address[](2);

        swaps[0] = NUSD_POOL;
        tokens[0] = NUSD;

        swaps[1] = NETH_POOL;
        tokens[1] = NETH;

        _zap = deployCode(
            "L2BridgeZap.sol",
            abi.encode(WAVAX, swaps, tokens, BRIDGE)
        );
    }

    function testDeposit(uint64 amount) public {
        // We're using token that 100% wasn't pre-approved in Zap
        vm.assume(amount > 0);
        deal(SYN, user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenDeposit(user, 1, IERC20(SYN), amount);
        zap.deposit(user, 1, IERC20(SYN), amount);
    }

    function testDepositETH(uint64 amount) public {
        vm.assume(amount > 0);
        deal(user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenDeposit(user, 1, IERC20(WAVAX), amount);
        zap.depositETH{value: amount}(user, 1, amount);
    }

    function testDepositETHAndSwap(uint64 amount) public {
        vm.assume(amount > 0);
        deal(user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenDepositAndSwap(user, 1, IERC20(WAVAX), amount, 2, 3, 4, 5);
        zap.depositETHAndSwap{value: amount}(user, 1, amount, 2, 3, 4, 5);
    }

    function testRedeem(uint64 amount) public {
        // We're using token that 100% wasn't pre-approved in Zap
        vm.assume(amount > 0);
        deal(SYN, user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenRedeem(user, 1, IERC20(SYN), amount);
        zap.redeem(user, 1, IERC20(SYN), amount);
    }

    function testRedeemAndRemove(uint64 amount) public {
        // This will not be completed on the destination chain!
        // Still needs to be accepted on source chain
        // We're using token that 100% wasn't pre-approved in Zap,
        // as nUSD on some chains won't have a swap pool
        vm.assume(amount > 0);
        deal(SYN, user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenRedeemAndRemove(user, 1, IERC20(SYN), amount, 2, 3, 4);
        zap.redeemAndRemove(user, 1, IERC20(SYN), amount, 2, 3, 4);
    }

    function testRedeemAndSwap(uint64 amount) public {
        // This will not be completed on the destination chain!
        // Still needs to be accepted on source chain
        // We're using token that 100% wasn't pre-approved in Zap,
        // as nUSD on some chains won't have a swap pool
        vm.assume(amount > 0);
        deal(SYN, user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenRedeemAndSwap(user, 1, IERC20(SYN), amount, 2, 3, 4, 5);
        zap.redeemAndSwap(user, 1, IERC20(SYN), amount, 2, 3, 4, 5);
    }

    function testRedeemV2(uint64 amount) public {
        // Just imagine this is UST
        vm.assume(amount > 0);
        deal(SYN, user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenRedeemV2(keccak256("address"), 1, IERC20(SYN), amount);
        zap.redeemV2(keccak256("address"), 1, IERC20(SYN), amount);
    }

    function testSwapAndRedeem(uint96 amount) public {
        vm.assume(amount > 1337);

        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeem(user, 0, IERC20(address(0)), 0);
        deal(WETH, user, amount);
        zap.swapAndRedeem(user, 1, IERC20(NETH), 1, 0, amount, 0, MAX_UINT256);

        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeem(user, 0, IERC20(address(0)), 0);
        deal(DAI, user, amount);
        zap.swapAndRedeem(user, 1, IERC20(NUSD), 1, 0, amount, 0, MAX_UINT256);
    }

    function testSwapAndRedeemAndRemove(uint96 amount) public {
        vm.assume(amount > 1337);

        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeemAndRemove(user, 0, IERC20(address(0)), 0, 0, 0, 0);
        deal(DAI, user, amount);
        zap.swapAndRedeemAndRemove(
            user,
            1,
            IERC20(NUSD),
            1,
            0,
            amount,
            0,
            MAX_UINT256,
            0,
            0,
            0
        );
    }

    function testSwapAndRedeemAndSwap(uint64 amount) public {
        vm.assume(amount > 1337);

        deal(DAI, user, amount);
        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeemAndSwap(user, 0, IERC20(address(0)), 0, 0, 0, 0, 0);
        zap.swapAndRedeemAndSwap(
            user,
            1,
            IERC20(NUSD),
            1,
            0,
            amount,
            0,
            MAX_UINT256,
            0,
            0,
            0,
            0
        );

        deal(WETH, user, amount);
        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeemAndSwap(user, 0, IERC20(address(0)), 0, 0, 0, 0, 0);
        zap.swapAndRedeemAndSwap(
            user,
            1,
            IERC20(NETH),
            1,
            0,
            amount,
            0,
            MAX_UINT256,
            0,
            0,
            0,
            0
        );
    }

    // testSwapETHAndRedeem N/A on AVAX

    // testSwapETHAndRedeemAndSwap N/A on AVAX
}
