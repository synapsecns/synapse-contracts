// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../utils/DefaultRouterTest.t.sol";

contract RouterTest is DefaultRouterTest {
    /**
     * @notice Checks that Router is able to execute the best path
     * between two tokens, found by Quoter with a max length of 1.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives the token.
     */
    function testExecuteBestPath1(
        uint8 indexFrom,
        uint8 indexTo,
        uint64 amountIn
    ) public {
        uint8 maxSwaps = 1;
        _checkExecution(maxSwaps, indexFrom, indexTo, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between two tokens, found by Quoter with a max length of 2.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives the token.
     */
    function testExecuteBestPath2(
        uint8 indexFrom,
        uint8 indexTo,
        uint64 amountIn
    ) public {
        uint8 maxSwaps = 2;
        _checkExecution(maxSwaps, indexFrom, indexTo, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between two tokens, found by Quoter with a max length of 3.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives the token.
     */
    function testExecuteBestPath3(
        uint8 indexFrom,
        uint8 indexTo,
        uint64 amountIn
    ) public {
        uint8 maxSwaps = 3;
        _checkExecution(maxSwaps, indexFrom, indexTo, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between two tokens, found by Quoter with a max length of 4.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives the token.
     */
    function testExecuteBestPath4(
        uint8 indexFrom,
        uint8 indexTo,
        uint64 amountIn
    ) public {
        uint8 maxSwaps = 4;
        _checkExecution(maxSwaps, indexFrom, indexTo, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between GAS and a token, found by Quoter with a max length of 1.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives the token.
     */
    function testExecuteBestPathFromGAS1(uint8 indexTo, uint64 amountIn) public {
        uint8 maxSwaps = 1;
        _checkExecutionFromGAS(maxSwaps, indexTo, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between GAS and a token, found by Quoter with a max length of 2.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives the token.
     */
    function testExecuteBestPathFromGAS2(uint8 indexTo, uint64 amountIn) public {
        uint8 maxSwaps = 2;
        _checkExecutionFromGAS(maxSwaps, indexTo, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between GAS and a token, found by Quoter with a max length of 3.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives the token.
     */
    function testExecuteBestPathFromGAS3(uint8 indexTo, uint64 amountIn) public {
        uint8 maxSwaps = 3;
        _checkExecutionFromGAS(maxSwaps, indexTo, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between GAS and a token, found by Quoter with a max length of 4.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives the token.
     */
    function testExecuteBestPathFromGAS4(uint8 indexTo, uint64 amountIn) public {
        uint8 maxSwaps = 4;
        _checkExecutionFromGAS(maxSwaps, indexTo, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between a token and GAS, found by Quoter with a max length of 1.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives GAS.
     */
    function testExecuteBestPathToGAS1(uint8 indexFrom, uint64 amountIn) public {
        uint8 maxSwaps = 1;
        _checkExecutionToGAS(maxSwaps, indexFrom, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between a token and GAS, found by Quoter with a max length of 1.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives GAS.
     */
    function testExecuteBestPathToGAS2(uint8 indexFrom, uint64 amountIn) public {
        uint8 maxSwaps = 2;
        _checkExecutionToGAS(maxSwaps, indexFrom, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between a token and GAS, found by Quoter with a max length of 1.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives GAS.
     */
    function testExecuteBestPathToGAS3(uint8 indexFrom, uint64 amountIn) public {
        uint8 maxSwaps = 3;
        _checkExecutionToGAS(maxSwaps, indexFrom, amountIn);
    }

    /**
     * @notice Checks that Router is able to execute the best path
     * between a token and GAS, found by Quoter with a max length of 1.
     * Checks that actual amountOut is the same as quote.
     * Checks that user receives GAS.
     */
    function testExecuteBestPathToGAS4(uint8 indexFrom, uint64 amountIn) public {
        uint8 maxSwaps = 4;
        _checkExecutionToGAS(maxSwaps, indexFrom, amountIn);
    }

    /**
     * @notice Checks correct execute of trade between two tokens.
     */
    function _checkExecution(
        uint8 maxSwaps,
        uint8 indexFrom,
        uint8 indexTo,
        uint64 _amountIn
    ) internal {
        (Offers.FormattedOffer memory offer, uint256 amountIn, uint256 amountOut) = _askQuoter(
            maxSwaps,
            indexFrom,
            indexTo,
            _amountIn
        );

        _dealToken(IERC20(allTokens[indexFrom]), user, amountIn);
        startHoax(user);
        IERC20(allTokens[indexFrom]).approve(address(router), amountIn);

        uint256 userPre = IERC20(allTokens[indexTo]).balanceOf(user);
        uint256 reportedOut = router.swap(user, offer.path, offer.adapters, amountIn, 0, block.timestamp);
        vm.stopPrank();
        assertEq(
            IERC20(allTokens[indexTo]).balanceOf(user) - userPre,
            reportedOut,
            "Failed to report amount of tokens sent to user"
        );
        assertEq(amountOut, reportedOut, "Failed to provide accurate quote");
        if (amountOut != reportedOut) {
            _logOffer(offer);
        }
    }

    /**
     * @notice Checks correct execute of trade from GAS to token.
     */
    function _checkExecutionFromGAS(
        uint8 maxSwaps,
        uint8 indexTo,
        uint64 _amountIn
    ) internal {
        uint8 indexFrom = WETH_INDEX;
        (Offers.FormattedOffer memory offer, uint256 amountIn, uint256 amountOut) = _askQuoter(
            maxSwaps,
            indexFrom,
            indexTo,
            _amountIn
        );

        deal(user, amountIn);
        startHoax(user);

        uint256 userPre = IERC20(allTokens[indexTo]).balanceOf(user);
        uint256 reportedOut = router.swapFromGAS{value: amountIn}(
            user,
            offer.path,
            offer.adapters,
            amountIn,
            0,
            block.timestamp
        );
        vm.stopPrank();
        assertEq(
            IERC20(allTokens[indexTo]).balanceOf(user) - userPre,
            reportedOut,
            "Failed to report amount of tokens sent to user"
        );
        assertEq(amountOut, reportedOut, "Failed to provide accurate quote");
        if (amountOut != reportedOut) {
            _logOffer(offer);
        }
    }

    /**
     * @notice Checks correct execute of trade from token to GAS.
     */
    function _checkExecutionToGAS(
        uint8 maxSwaps,
        uint8 indexFrom,
        uint64 _amountIn
    ) internal {
        uint8 indexTo = WETH_INDEX;
        (Offers.FormattedOffer memory offer, uint256 amountIn, uint256 amountOut) = _askQuoter(
            maxSwaps,
            indexFrom,
            indexTo,
            _amountIn
        );

        _dealToken(IERC20(allTokens[indexFrom]), user, amountIn);
        startHoax(user);
        IERC20(allTokens[indexFrom]).approve(address(router), amountIn);

        uint256 userPre = user.balance;
        uint256 reportedOut = router.swapToGAS(user, offer.path, offer.adapters, amountIn, 0, block.timestamp);
        vm.stopPrank();
        assertEq(user.balance - userPre, reportedOut, "Failed to report amount of tokens sent to user");
        assertEq(amountOut, reportedOut, "Failed to provide accurate quote");
        if (amountOut != reportedOut) {
            _logOffer(offer);
        }
    }
}
