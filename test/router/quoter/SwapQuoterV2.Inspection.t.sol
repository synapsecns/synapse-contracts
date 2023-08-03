// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../contracts/router/interfaces/IDefaultExtendedPool.sol";
import {PoolToken} from "../../../contracts/router/libs/Structs.sol";
import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockWETH} from "../mocks/MockWETH.sol";

import {BasicSwapQuoterV2Test} from "./BasicSwapQuoterV2.t.sol";

// solhint-disable max-states-count
contract SwapQuoterV2InspectionTest is BasicSwapQuoterV2Test {
    // Note: no pools are added, Quoter is supposed inspect arbitrary pools

    function testCalculateAddLiquidity() public {
        // Test quote for adding liquidity to nUSD/USDC.e/USDT pool
        // nUSD: 10, USDC.e: 5, USDT: 50
        uint256[] memory amounts = toArray(10 * 10**18, 5 * 10**6, 50 * 10**6);
        uint256 amountOut = quoter.calculateAddLiquidity(poolNusdUsdcEUsdt, amounts);
        // Should be equal to return value from DefaultPoolCalc, which is tested separately
        assertEq(amountOut, DefaultPoolCalc(defaultPoolCalc).calculateAddLiquidity(poolNusdUsdcEUsdt, amounts));
    }

    function testCalculateSwap() public {
        // Test swap quote in nUSD/USDC.e/USDT pool: nUSD -> USDT
        uint256 amountIn = 10**18;
        uint256 amountOut = quoter.calculateSwap(poolNusdUsdcEUsdt, 0, 2, amountIn);
        // Should be equal to pool's calculateSwap
        assertEq(amountOut, IDefaultExtendedPool(poolNusdUsdcEUsdt).calculateSwap(0, 2, amountIn));
    }

    function testCalculateRemoveLiquidity() public {
        // Test remove balanced liquidity quote in nUSD/USDC.e/USDT pool
        uint256 amountIn = 10**18;
        uint256[] memory amounts = quoter.calculateRemoveLiquidity(poolNusdUsdcEUsdt, amountIn);
        uint256[] memory expectedAmounts = IDefaultExtendedPool(poolNusdUsdcEUsdt).calculateRemoveLiquidity(amountIn);
        assertEq(amounts, expectedAmounts);
    }

    function testCalculateWithdrawOneToken() public {
        // Test remove liquidity quote in nUSD/USDC.e/USDT pool -> USDC.e
        uint256 amountIn = 10**18;
        uint256 amountOut = quoter.calculateWithdrawOneToken(poolNusdUsdcEUsdt, amountIn, 1);
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNusdUsdcEUsdt).calculateRemoveLiquidityOneToken(
            amountIn,
            1
        );
        assertEq(amountOut, expectedAmountOut);
    }

    function testPoolInfoDefaultPool() public {
        (uint256 numTokens, address lpToken) = quoter.poolInfo(poolNusdUsdcEUsdt);
        assertEq(numTokens, 3);
        assertEq(lpToken, poolLpToken[poolNusdUsdcEUsdt]);
    }

    function testPoolInfoLinkedPool() public {
        (uint256 numTokens, address lpToken) = quoter.poolInfo(linkedPoolNusd);
        assertEq(numTokens, 3);
        // Linked Pool has no lp token
        assertEq(lpToken, address(0));
    }

    function testPoolTokensDefaultPoolNoWETH() public {
        PoolToken[] memory tokens = quoter.poolTokens(poolNusdUsdcEUsdt);
        assertEq(tokens.length, 3);
        assertEq(tokens[0].token, nusd);
        assertEq(tokens[0].isWeth, false);
        assertEq(tokens[1].token, usdcE);
        assertEq(tokens[1].isWeth, false);
        assertEq(tokens[2].token, usdt);
        assertEq(tokens[2].isWeth, false);
    }

    function testPoolTokensDefaultPoolWithWETH() public {
        PoolToken[] memory tokens = quoter.poolTokens(poolNethWeth);
        assertEq(tokens.length, 2);
        assertEq(tokens[0].token, neth);
        assertEq(tokens[0].isWeth, false);
        assertEq(tokens[1].token, weth);
        assertEq(tokens[1].isWeth, true);
    }

    function testPoolTokensLinkedPoolNoWETH() public {
        PoolToken[] memory tokens = quoter.poolTokens(linkedPoolNusd);
        assertEq(tokens.length, 3);
        assertEq(tokens[0].token, nusd);
        assertEq(tokens[0].isWeth, false);
        assertEq(tokens[1].token, usdcE);
        assertEq(tokens[1].isWeth, false);
        assertEq(tokens[2].token, usdt);
        assertEq(tokens[2].isWeth, false);
    }

    function testPoolTokensLinkedPoolWithWETH() public {
        // Deploy Linked Pool for nETH pool
        address linkedPoolNeth = deployLinkedPool(neth, poolNethWeth);
        PoolToken[] memory tokens = quoter.poolTokens(linkedPoolNeth);
        assertEq(tokens.length, 2);
        assertEq(tokens[0].token, neth);
        assertEq(tokens[0].isWeth, false);
        assertEq(tokens[1].token, weth);
        assertEq(tokens[1].isWeth, true);
    }
}
