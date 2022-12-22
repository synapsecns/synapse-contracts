// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../../interfaces/ISwap.sol";

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

abstract contract SwapCalculator {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Set of supported pools conforming to ISwap interface
    EnumerableSet.AddressSet internal _pools;
    /// @dev Pool tokens for every supported ISwap pool
    mapping(address => address[]) internal _poolTokens;
    /// @dev LP token for every supported ISwap pool (if exists)
    mapping(address => address) internal _poolLpToken;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _addPool(address pool) internal {
        if (_pools.add(pool)) {
            address[] storage tokens = _poolTokens[pool];
            // Don't do anything if pool was added before
            if (tokens.length != 0) return;
            for (uint8 i = 0; ; ++i) {
                try ISwap(pool).getToken(i) returns (IERC20 token) {
                    _poolTokens[pool].push(address(token));
                } catch {
                    // End of pool reached
                    break;
                }
            }
            try ISwap(pool).swapStorage() returns (
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                address lpToken
            ) {
                _poolLpToken[pool] = lpToken;
            } catch {
                // solhint-disable-previous-line no-empty-blocks
                // Don't do anything if swapStorage fails,
                // this is probably a wrapper pool
            }
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _calculateSwap(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        try ISwap(pool).calculateSwap(tokenIndexFrom, tokenIndexTo, amountIn) returns (uint256 _amountOut) {
            amountOut = _amountOut;
        } catch {
            return 0;
        }
    }

    function _calculateRemove(
        address pool,
        uint8 tokenIndexTo,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        try ISwap(pool).calculateRemoveLiquidityOneToken(amountIn, tokenIndexTo) returns (uint256 _amountOut) {
            amountOut = _amountOut;
        } catch {
            return 0;
        }
    }

    function _calculateAdd(
        address pool,
        uint8 tokenIndexFrom,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        uint256 tokens = _poolTokens[pool].length;
        // Prepare array with deposit amounts
        uint256[] memory amounts = new uint256[](tokens);
        amounts[tokenIndexFrom] = amountIn;
        // TODO: use SwapCalculator to get the exact quote
        try ISwap(pool).calculateTokenAmount(amounts, true) returns (uint256 _amountOut) {
            amountOut = _amountOut;
        } catch {
            return 0;
        }
    }

    /**
     * @notice Returns indexes for the two given tokens plus 1.
     * The default value of 0 means a token is not supported by the pool.
     */
    function _getTokenIndexes(
        address pool,
        address tokenIn,
        address tokenOut
    ) internal view returns (uint8 indexIn, uint8 indexOut) {
        address[] storage tokens = _poolTokens[pool];
        uint256 amount = tokens.length;
        for (uint8 t = 0; t < amount; ++t) {
            address poolToken = tokens[t];
            if (poolToken == tokenIn) {
                indexIn = t + 1;
            } else if (poolToken == tokenOut) {
                indexOut = t + 1;
            }
        }
    }
}
