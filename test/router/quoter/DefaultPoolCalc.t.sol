// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../contracts/router/interfaces/IDefaultExtendedPool.sol";
import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";
import {console2, Test} from "forge-std/Test.sol";

// solhint-disable func-name-mixedcase
contract DefaultPoolCalcForkTest is Test {
    using SafeERC20 for IERC20;

    string public ethRPC;
    DefaultPoolCalc public calc;
    address public user;

    // Quite important pool, isn't it?
    address public constant POOL = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;
    address public constant LP_TOKEN = 0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // Maximum amount for tests before decimals
    uint256 public constant MIN_ADD_AMOUNT = 10;
    uint256 public constant MAX_AMOUNT = 10**9;

    // 2023-05-20
    uint256 public constant BLOCK_NUMBER_RECENT = 17_300_000;

    // Block when the pool was created
    uint256 public constant BLOCK_NUMBER_POOL_EMPTY = 13033711;

    function setUp() public {
        user = makeAddr("User");
        ethRPC = vm.envString("rpc_mainnet");
        calc = new DefaultPoolCalc();
        vm.makePersistent(address(calc));
        vm.createSelectFork(ethRPC, BLOCK_NUMBER_RECENT);

        vm.label(POOL, "Pool");
        vm.label(LP_TOKEN, "LP_TOKEN");
        vm.label(DAI, "DAI");
        vm.label(USDC, "USDC");
        vm.label(USDT, "USDT");
    }

    function test_calculateAddLiquidity(uint256[3] memory amounts_) public {
        uint256[] memory amounts = castArray(amounts_);
        boundTokenAmounts(amounts);
        vm.assume(amounts[0] > 0 || amounts[1] > 0 || amounts[2] > 0);
        checkAddLiquidityQuote(amounts);
    }

    function test_calculateAddLiquidity_whenEmpty(uint256 amount, uint256[3] memory amounts_) public {
        amount = bound(amount, MIN_ADD_AMOUNT, MAX_AMOUNT);
        // limit the initial pool offset to 10% so that StableSwap Math converges
        uint256 amountMin = (amount * 9) / 10;
        uint256 amountMax = (amount * 11) / 10;
        amounts_[0] = bound(amounts_[0], amountMin * 10**18, amountMax * 10**18);
        amounts_[1] = bound(amounts_[1], amountMin * 10**6, amountMax * 10**6);
        amounts_[2] = bound(amounts_[2], amountMin * 10**6, amountMax * 10**6);
        uint256[] memory amounts = castArray(amounts_);
        vm.createSelectFork(ethRPC, BLOCK_NUMBER_POOL_EMPTY);
        checkAddLiquidityQuote(amounts);
    }

    function test_calculateAddLiquidity_whenEmpty_revert_whenZero() public {
        vm.createSelectFork(ethRPC, BLOCK_NUMBER_POOL_EMPTY);
        uint256[] memory amounts = new uint256[](3);
        // Iterate over all from [0,0,0] to [1,1,0]
        for (uint256 mask = 0; mask < 7; ++mask) {
            amounts[0] = (mask & 1) * 10**18;
            amounts[1] = ((mask >> 1) & 1) * 10**6;
            amounts[2] = ((mask >> 2) & 1) * 10**6;
            vm.expectRevert("Must supply all tokens in pool");
            calc.calculateAddLiquidity(POOL, amounts);
        }
    }

    function checkAddLiquidityQuote(uint256[] memory amounts) public {
        uint256 amountOut = calc.calculateAddLiquidity(POOL, amounts);
        prepareTokens(amounts);
        if (amountOut == 0) vm.expectRevert("LPToken: cannot mint 0");
        vm.prank(user);
        IDefaultExtendedPool(POOL).addLiquidity(amounts, 0, type(uint256).max);
        assertEq(IERC20(LP_TOKEN).balanceOf(user), amountOut);
    }

    function prepareTokens(uint256[] memory amounts) public {
        deal(DAI, user, amounts[0]);
        deal(USDC, user, amounts[1]);
        deal(USDT, user, amounts[2]);
        vm.startPrank(user);
        IERC20(DAI).safeApprove(POOL, amounts[0]);
        IERC20(USDC).safeApprove(POOL, amounts[1]);
        IERC20(USDT).safeApprove(POOL, amounts[2]);
    }

    function boundTokenAmounts(uint256[] memory amounts) public pure {
        amounts[0] = amounts[0] % (MAX_AMOUNT * 10**18);
        amounts[1] = amounts[1] % (MAX_AMOUNT * 10**6);
        amounts[2] = amounts[2] % (MAX_AMOUNT * 10**6);
    }

    function castArray(uint256[3] memory amounts) public pure returns (uint256[] memory casted) {
        casted = new uint256[](3);
        casted[0] = amounts[0];
        casted[1] = amounts[1];
        casted[2] = amounts[2];
    }
}
