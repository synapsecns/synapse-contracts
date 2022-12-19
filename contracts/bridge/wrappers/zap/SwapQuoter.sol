// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../interfaces/ISwap.sol";
import "../../interfaces/ISwapQuoter.sol";
import "../../libraries/BridgeStructs.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract SwapQuoter is Ownable, ISwapQuoter {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable bridgeZap;

    EnumerableSet.AddressSet internal _pools;
    mapping(address => address[]) internal _poolTokens;

    constructor(address _bridgeZap) public {
        bridgeZap = _bridgeZap;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function addPools(address[] calldata pools) external onlyOwner {
        uint256 amount = pools.length;
        for (uint256 i = 0; i < amount; ++i) {
            addPool(pools[i]);
        }
    }

    function addPool(address pool) public onlyOwner {
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
        }
    }

    function removePool(address pool) external onlyOwner {
        _pools.remove(pool);
        // We don't remove _poolTokens records, as pool's set of tokens doesn't change over time.
        // Quoter iterates through all pools in `_pools`, so removing it from there is enough.
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view override returns (SwapQuery memory query) {
        if (tokenIn == tokenOut) {
            // Return struct indicating no swap is required
            return
                SwapQuery({
                    swapAdapter: address(0),
                    tokenOut: tokenIn,
                    minAmountOut: amountIn,
                    deadline: 0,
                    rawParams: bytes("")
                });
        }
        uint256 amount = poolsAmount();
        for (uint256 i = 0; i < amount; ++i) {
            address pool = _pools.at(i);
            (uint8 indexIn, uint8 indexOut) = _getTokenIndexes(pool, tokenIn, tokenOut);
            // Check if both tokens are present in the current pool
            if (indexIn != 0 && indexOut != 0) {
                uint8 tokenIndexFrom = indexIn - 1;
                uint8 tokenIndexTo = indexOut - 1;
                // Try getting a quote for tokenIn -> tokenOut swap via the current pool
                try ISwap(pool).calculateSwap(tokenIndexFrom, tokenIndexTo, amountIn) returns (uint256 amountOut) {
                    // We want to return the best available quote
                    if (amountOut > query.minAmountOut) {
                        query.minAmountOut = amountOut;
                        // Encode params for swapping via the current pool
                        query.rawParams = abi.encode(SynapseParams(pool, tokenIndexFrom, tokenIndexTo));
                    }
                } catch {
                    // Do nothing if calculateSwap() reverts
                }
            }
        }
        // Fill the remaining fields if a path was found
        if (query.minAmountOut != 0) {
            // Bridge Zap should be used for doing a swap through Synapse pools
            query.swapAdapter = bridgeZap;
            query.tokenOut = tokenOut;
            // Set default deadline to infinity. Not using the value of 0,
            // which would lead to every swap to revert by default.
            query.deadline = type(uint256).max;
        }
    }

    function allPools() external view returns (address[] memory pools) {
        uint256 amount = poolsAmount();
        pools = new address[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            pools[i] = _pools.at(i);
        }
    }

    function poolTokens(address pool) external view returns (address[] memory tokens) {
        tokens = _poolTokens[pool];
    }

    function poolsAmount() public view returns (uint256) {
        return _pools.length();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

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
