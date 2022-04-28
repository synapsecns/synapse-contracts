// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./L2BridgeZapTest.sol";

contract L2ZapTestArb is L2BridgeZapTest {
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant BRIDGE = 0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9;

    address public constant NUSD = 0x2913E812Cf0dcCA30FB28E6Cac3d2DCFF4497688;
    address public constant NETH = 0x3ea9B0ab55F34Fb188824Ee288CeaEfC63cf908e;

    address public constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant SYN = 0x080F6AEd32Fc474DD5717105Dba5ea57268F46eb;

    address public constant NUSD_POOL =
        0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40;
    address public constant NETH_POOL =
        0xa067668661C84476aFcDc6fA5D758C4c01C34352;

    constructor() L2BridgeZapTest() {
		IERC20(SYN).approve(address(zap), MAX_UINT256);
		IERC20(USDC).approve(address(zap), MAX_UINT256);
		IERC20(WETH).approve(address(zap), MAX_UINT256);
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
            abi.encode(WETH, swaps, tokens, BRIDGE)
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

	// testDepositETH N/A on Arbitrum

	// testDepositETHAndSwap N/A on Arbitrum

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

        deal(WETH, user, amount);
		vm.expectEmit(true, false, false, false);
		// Don't check data
        emit TokenRedeem(user, 0, IERC20(address(0)), 0);
        zap.swapAndRedeem(user, 1, IERC20(NETH), 1, 0, amount, 0, MAX_UINT256);

		vm.expectEmit(true, false, false, false);
		// Don't check data
        emit TokenRedeem(user, 0, IERC20(address(0)), 0);
        deal(USDC, user, amount);
        zap.swapAndRedeem(user, 1, IERC20(NUSD), 1, 0, amount, 0, MAX_UINT256);
    }

	function testSwapAndRedeemAndRemove(uint96 amount) public {
        vm.assume(amount > 1337);

        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeemAndRemove(user, 0, IERC20(address(0)), 0, 0, 0, 0);
        deal(USDC, user, amount);
        zap.swapAndRedeemAndRemove(
            user,
            1,
            IERC20(NUSD),
            1,
            0,
            amount,
            0,
            MAX_UINT256,
            2,
            3,
            4
        );
    }

	function testSwapAndRedeemAndSwap(uint64 amount) public {
        vm.assume(amount > 1337);

        deal(USDC, user, amount);
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

    function testSwapETHAndRedeem(uint64 amount) public {
        vm.assume(amount > 1337);
        deal(user, amount);
        // Don't check data
        vm.expectEmit(true, false, false, false);
        emit TokenRedeem(user, 0, IERC20(address(0)), 0);
        zap.swapETHAndRedeem{value: amount}(
            user,
            1,
            IERC20(NETH),
            1,
            0,
            amount,
            0,
            MAX_UINT256
        );
    }

    function testSwapETHAndRedeemAndSwap(uint64 amount) public {
        vm.assume(amount > 1337);
        deal(user, amount);
        // Don't check data
        vm.expectEmit(true, false, false, false);
        emit TokenRedeemAndSwap(user, 0, IERC20(address(0)), 0, 0, 0, 0, 0);
        zap.swapETHAndRedeemAndSwap{value: amount}(
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
}
