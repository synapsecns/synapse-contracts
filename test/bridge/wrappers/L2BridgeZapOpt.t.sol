// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./L2BridgeZapTest.sol";

contract L2ZapTestOpt is L2BridgeZapTest {
    address public constant WETH = 0x121ab82b49B2BC4c7901CA46B8277962b4350204;
    address public constant BRIDGE = 0xAf41a65F786339e7911F4acDAD6BD49426F2Dc6b;

    address public constant NUSD = 0x67C10C397dD0Ba417329543c1a40eb48AAa7cd00;
    address public constant NETH = 0x809DC529f07651bD43A172e8dB6f4a7a0d771036;

    address public constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address public constant SYN = 0x5A5fFf6F753d7C11A56A52FE47a177a87e431655;

    address public constant NUSD_POOL = 0xF44938b0125A6662f9536281aD2CD6c499F22004;
    address public constant NETH_POOL = 0xE27BFf97CE92C3e1Ff7AA9f86781FDd6D48F5eE9;

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

        _zap = deployCode("L2BridgeZap.sol", abi.encode(WETH, swaps, tokens, BRIDGE));
    }

    function testDeposit() public {
        // We're using token that 100% wasn't pre-approved in Zap
        uint256 amount = 10**18;
        deal(SYN, user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenDeposit(user, 1, IERC20(SYN), amount);
        zap.deposit(user, 1, IERC20(SYN), amount);
    }

    // testDepositETH N/A on Optimism

    // testDepositETHAndSwap N/A on Optimism

    function testRedeem() public {
        // We're using token that 100% wasn't pre-approved in Zap
        uint256 amount = 10**18;
        deal(SYN, user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenRedeem(user, 1, IERC20(SYN), amount);
        zap.redeem(user, 1, IERC20(SYN), amount);
    }

    function testRedeemAndRemove() public {
        // This will not be completed on the destination chain!
        // Still needs to be accepted on source chain
        // We're using token that 100% wasn't pre-approved in Zap,
        // as nUSD on some chains won't have a swap pool
        uint256 amount = 10**18;
        deal(SYN, user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenRedeemAndRemove(user, 1, IERC20(SYN), amount, 2, 3, 4);
        zap.redeemAndRemove(user, 1, IERC20(SYN), amount, 2, 3, 4);
    }

    function testRedeemAndSwap() public {
        // This will not be completed on the destination chain!
        // Still needs to be accepted on source chain
        // We're using token that 100% wasn't pre-approved in Zap,
        // as nUSD on some chains won't have a swap pool
        uint256 amount = 10**18;
        deal(SYN, user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenRedeemAndSwap(user, 1, IERC20(SYN), amount, 2, 3, 4, 5);
        zap.redeemAndSwap(user, 1, IERC20(SYN), amount, 2, 3, 4, 5);
    }

    function testRedeemV2() public {
        // Just imagine this is UST
        uint256 amount = 10**18;
        deal(SYN, user, amount);
        vm.expectEmit(true, false, false, true);
        emit TokenRedeemV2(keccak256("address"), 1, IERC20(SYN), amount);
        zap.redeemV2(keccak256("address"), 1, IERC20(SYN), amount);
    }

    function testSwapAndRedeem() public {
        uint256 amount = 10**18;

        deal(WETH, user, amount);
        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeem(user, 0, IERC20(address(0)), 0);
        zap.swapAndRedeem(user, 1, IERC20(NETH), 1, 0, amount, 0, MAX_UINT256);

        // adjust decimals for USDC
        amount = 10**6;

        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeem(user, 0, IERC20(address(0)), 0);
        deal(USDC, user, amount);
        zap.swapAndRedeem(user, 1, IERC20(NUSD), 1, 0, amount, 0, MAX_UINT256);
    }

    function testSwapAndRedeemAndRemove() public {
        uint256 amount = 10**6;

        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeemAndRemove(user, 0, IERC20(address(0)), 0, 0, 0, 0);
        deal(USDC, user, amount);
        zap.swapAndRedeemAndRemove(user, 1, IERC20(NUSD), 1, 0, amount, 0, MAX_UINT256, 2, 3, 4);
    }

    function testSwapAndRedeemAndSwap() public {
        uint256 amount = 10**6;

        deal(USDC, user, amount);
        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeemAndSwap(user, 0, IERC20(address(0)), 0, 0, 0, 0, 0);
        zap.swapAndRedeemAndSwap(user, 1, IERC20(NUSD), 1, 0, amount, 0, MAX_UINT256, 0, 0, 0, 0);

        // adjust decimals for WETH
        amount = 10**18;

        deal(WETH, user, amount);
        vm.expectEmit(true, false, false, false);
        // Don't check data
        emit TokenRedeemAndSwap(user, 0, IERC20(address(0)), 0, 0, 0, 0, 0);
        zap.swapAndRedeemAndSwap(user, 1, IERC20(NETH), 1, 0, amount, 0, MAX_UINT256, 0, 0, 0, 0);
    }

    function testSwapETHAndRedeem() public {
        uint256 amount = 10**18;
        deal(user, amount);
        // Don't check data
        vm.expectEmit(true, false, false, false);
        emit TokenRedeem(user, 0, IERC20(address(0)), 0);
        zap.swapETHAndRedeem{value: amount}(user, 1, IERC20(NETH), 1, 0, amount, 0, MAX_UINT256);
    }

    function testSwapETHAndRedeemAndSwap() public {
        uint256 amount = 10**18;
        deal(user, amount);
        // Don't check data
        vm.expectEmit(true, false, false, false);
        emit TokenRedeemAndSwap(user, 0, IERC20(address(0)), 0, 0, 0, 0, 0);
        zap.swapETHAndRedeemAndSwap{value: amount}(user, 1, IERC20(NETH), 1, 0, amount, 0, MAX_UINT256, 0, 0, 0, 0);
    }
}
