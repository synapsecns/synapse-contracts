// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../../../contracts/bridge/wrappers/zap/SwapCalculator.sol";
import "../../../utils/Utilities06.sol";

contract SwapCalculatorHarness is SwapCalculator {
    function addPool(address pool) external {
        _addPool(pool);
    }

    function calculateSwap(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 amountIn
    ) external view returns (uint256) {
        return _calculateSwap(pool, tokenIndexFrom, tokenIndexTo, amountIn);
    }

    function calculateRemove(
        address pool,
        uint8 tokenIndexTo,
        uint256 amountIn
    ) external view returns (uint256) {
        return _calculateRemove(pool, tokenIndexTo, amountIn);
    }

    function calculateAdd(
        address pool,
        uint8 tokenIndexFrom,
        uint256 amountIn
    ) external view returns (uint256) {
        return _calculateAdd(pool, tokenIndexFrom, amountIn);
    }
}

// solhint-disable func-name-mixedcase
contract SwapCalculatorTest is Utilities06 {
    address internal nUsdPool;
    ERC20 internal nusd;
    IERC20[] internal nUsdTokens;
    ERC20 internal dai;
    ERC20 internal usdc;
    ERC20 internal usdt;

    SwapCalculatorHarness internal calc;

    function setUp() public override {
        super.setUp();

        dai = deployERC20("DAI", 18);
        usdc = deployERC20("USDC", 6);
        usdt = deployERC20("USDT", 6);

        {
            uint256[] memory amounts = new uint256[](4);
            nUsdTokens.push(IERC20(dai));
            nUsdTokens.push(IERC20(usdc));
            nUsdTokens.push(IERC20(usdt));
            amounts[0] = 1000;
            amounts[1] = 1050;
            amounts[2] = 1100;
            nUsdPool = deployPoolWithLiquidity(nUsdTokens, amounts);
            vm.label(nUsdPool, "Nexus Pool");
        }

        (, , , , , , address nexusLpToken) = ISwap(nUsdPool).swapStorage();
        nusd = ERC20(nexusLpToken);

        _dealAndApprove(address(nusd));
        _dealAndApprove(address(dai));
        _dealAndApprove(address(usdc));
        _dealAndApprove(address(usdt));

        calc = new SwapCalculatorHarness();
        calc.addPool(nUsdPool);
    }

    function test_calculateSwap(
        uint256 tokenFrom,
        uint256 tokenTo,
        uint256 amount
    ) public {
        tokenFrom = tokenFrom % nUsdTokens.length;
        tokenTo = tokenTo % nUsdTokens.length;
        IERC20 tokenIn = nUsdTokens[tokenFrom];
        IERC20 tokenOut = nUsdTokens[tokenTo];
        amount = _adjustAmount(tokenIn, amount);
        uint256 quoteOut = calc.calculateSwap(nUsdPool, uint8(tokenFrom), uint8(tokenTo), amount);
        uint256 balanceBefore = tokenOut.balanceOf(address(this));
        uint256 amountOut = 0;
        try ISwap(nUsdPool).swap(uint8(tokenFrom), uint8(tokenTo), amount, 0, type(uint256).max) returns (
            uint256 _amountOut
        ) {
            amountOut = _amountOut;
        } catch {
            emit log_string("swap failed");
        }
        uint256 balanceAfter = tokenOut.balanceOf(address(this));
        assertEq(quoteOut, balanceAfter - balanceBefore, "Incorrect swap quote");
        assertEq(amountOut, balanceAfter - balanceBefore, "Incorrect reported amount");
    }

    function test_calculateRemove(uint256 tokenTo, uint256 amount) public {
        tokenTo = tokenTo % nUsdTokens.length;
        IERC20 tokenIn = nusd;
        IERC20 tokenOut = nUsdTokens[tokenTo];
        amount = _adjustAmount(tokenIn, amount);
        uint256 quoteOut = calc.calculateRemove(nUsdPool, uint8(tokenTo), amount);
        uint256 balanceBefore = tokenOut.balanceOf(address(this));
        uint256 amountOut = 0;
        try ISwap(nUsdPool).removeLiquidityOneToken(amount, uint8(tokenTo), 0, type(uint256).max) returns (
            uint256 _amountOut
        ) {
            amountOut = _amountOut;
        } catch {
            emit log_string("removeLiquidity failed");
        }
        uint256 balanceAfter = tokenOut.balanceOf(address(this));
        assertEq(quoteOut, balanceAfter - balanceBefore, "Incorrect remove quote");
        assertEq(amountOut, balanceAfter - balanceBefore, "Incorrect reported amount");
    }

    function test_calculateAdd(uint256 tokenFrom, uint256 amount) public {
        tokenFrom = tokenFrom % nUsdTokens.length;
        IERC20 tokenIn = nUsdTokens[tokenFrom];
        IERC20 tokenOut = nusd;
        amount = _adjustAmount(tokenIn, amount);
        uint256 quoteOut = calc.calculateAdd(nUsdPool, uint8(tokenFrom), amount);
        uint256[] memory amounts = new uint256[](nUsdTokens.length);
        amounts[tokenFrom] = amount;
        uint256 balanceBefore = tokenOut.balanceOf(address(this));
        uint256 amountOut = 0;
        try ISwap(nUsdPool).addLiquidity(amounts, 0, type(uint256).max) returns (uint256 _amountOut) {
            amountOut = _amountOut;
        } catch {
            emit log_string("addLiquidity failed");
        }
        uint256 balanceAfter = tokenOut.balanceOf(address(this));
        assertEq(quoteOut, balanceAfter - balanceBefore, "Incorrect add quote");
        assertEq(amountOut, balanceAfter - balanceBefore, "Incorrect reported amount");
    }

    function _adjustAmount(IERC20 token, uint256 amount) internal view returns (uint256 amountIn) {
        amountIn = amount % token.balanceOf(address(this));
    }

    function _dealAndApprove(address token) internal {
        if (token != address(nusd)) {
            deal(token, address(this), 10**20, true);
        }
        IERC20(token).approve(address(nUsdPool), type(uint256).max);
    }
}
