// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../utils/DefaultRouterTest.t.sol";

contract QuoterTest is DefaultRouterTest {
    function testFindBestPath1(
        uint8 indexFrom,
        uint8 indexTo,
        uint64 amountIn
    ) public {
        uint8 maxSwaps = 1;
        _checkFindBestPath(maxSwaps, indexFrom, indexTo, amountIn);
    }

    function testFindBestPath2(
        uint8 indexFrom,
        uint8 indexTo,
        uint64 amountIn
    ) public {
        uint8 maxSwaps = 2;
        _checkFindBestPath(maxSwaps, indexFrom, indexTo, amountIn);
    }

    function testFindBestPath3(
        uint8 indexFrom,
        uint8 indexTo,
        uint64 amountIn
    ) public {
        uint8 maxSwaps = 3;
        _checkFindBestPath(maxSwaps, indexFrom, indexTo, amountIn);
    }

    function testFindBestPath4(
        uint8 indexFrom,
        uint8 indexTo,
        uint64 amountIn
    ) public {
        uint8 maxSwaps = 4;
        _checkFindBestPath(maxSwaps, indexFrom, indexTo, amountIn);
    }

    function _checkFindBestPath(
        uint8 maxSwaps,
        uint8 indexFrom,
        uint8 indexTo,
        uint64 _amountIn
    ) internal {
        vm.assume(indexFrom < allTokens.length);
        vm.assume(indexTo < allTokens.length);
        vm.assume(indexFrom != indexTo);
        vm.assume(_amountIn > 0);

        address tokenIn = allTokens[indexFrom];
        address tokenOut = allTokens[indexTo];

        // use at least 1<<20 (~1e6) for amountIn
        uint256 amountIn = _amountIn << 20;

        Offers.FormattedOffer memory offer = quoter.findBestPath(tokenIn, amountIn, tokenOut, maxSwaps);

        uint256 bestAmountOut = offer.path.length > 0 ? offer.amounts[offer.amounts.length - 1] : 0;

        bool[] memory isTokenUsed = new bool[](routeTokens.length);

        uint256 index = routeIndex[tokenIn];
        if (index > 0) {
            isTokenUsed[index - 1] = true;
        }

        uint256 foundAmountOut = _bruteForcePath(maxSwaps, tokenIn, amountIn, tokenOut, isTokenUsed);

        assertEq(bestAmountOut, foundAmountOut, "Quoter vs BruteForce mismatch");
        if (bestAmountOut != foundAmountOut) {
            _logOffer(offer);
        }
    }
}
