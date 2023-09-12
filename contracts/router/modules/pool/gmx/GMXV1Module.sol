// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";
import {UniversalTokenLib} from "../../../libs/UniversalToken.sol";

import {IGMXV1Reader} from "../../../interfaces/gmx/IGMXV1Reader.sol";
import {IGMXV1Router} from "../../../interfaces/gmx/IGMXV1Router.sol";
import {IGMXV1Vault} from "../../../interfaces/gmx/IGMXV1Vault.sol";

import {OnlyDelegateCall} from "../../OnlyDelegateCall.sol";

/// @notice PoolModule for GMX V1 pools
/// @dev Implements IPoolModule interface to be used with pools added to LinkedPool router
abstract contract GMXV1Module is OnlyDelegateCall, IPoolModule {
    using UniversalTokenLib for address;

    IGMXV1Router public immutable router;
    IGMXV1Vault public immutable vault;
    IGMXV1Reader public immutable reader;

    modifier supportedToken(address token) {
        require(_isSupported(token), "token not supported");
        _;
    }

    constructor(address _router, address _reader) {
        router = IGMXV1Router(_router);
        vault = IGMXV1Vault(router.vault());
        reader = IGMXV1Reader(_reader);
    }

    /// @notice whether token supported by this pool module
    function _isSupported(address token) internal view virtual returns (bool);

    /// @inheritdoc IPoolModule
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external supportedToken(tokenFrom.token) supportedToken(tokenTo.token) returns (uint256 amountOut) {
        assertDelegateCall();
        require(pool == address(vault), "pool != vault");
        address tokenIn = tokenFrom.token;
        tokenIn.universalApproveInfinity(address(router), amountIn);

        address tokenOut = tokenTo.token;
        uint256 balanceTo = IERC20(tokenOut).balanceOf(address(this));

        uint256 maxAmountIn = reader.getMaxAmountIn(vault, tokenIn, tokenOut);
        require(amountIn <= maxAmountIn, "amountIn > maxAmountIn");

        address[] memory path = new address[](2);
        path[0] = tokenFrom.token;
        path[1] = tokenTo.token;
        router.swap(path, amountIn, 0, address(this));

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceTo;
    }

    /// @inheritdoc IPoolModule
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) external view supportedToken(tokenFrom.token) supportedToken(tokenTo.token) returns (uint256 amountOut) {
        require(pool == address(vault), "pool != vault");
        address tokenIn = tokenFrom.token;
        address tokenOut = tokenTo.token;

        uint256 maxAmountIn = reader.getMaxAmountIn(vault, tokenIn, tokenOut);
        require(amountIn <= maxAmountIn, "amountIn > maxAmountIn");

        (amountOut, ) = reader.getAmountOut(vault, tokenIn, tokenOut, amountIn);
    }

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) external view returns (address[] memory tokens) {
        require(pool == address(vault), "pool != vault");
        uint256 numCoins = vault.whitelistedTokenCount();

        address[] memory tokensFiltered = new address[](numCoins);
        uint256 count;
        for (uint256 i = 0; i < numCoins; i++) {
            address token = vault.allWhitelistedTokens(i);
            if (_isSupported(token)) {
                tokensFiltered[i] = token;
                count++;
            }
        }

        tokens = new address[](count);
        uint256 idx;
        for (uint256 i = 0; i < numCoins; i++) {
            address token = tokensFiltered[i];
            if (token != address(0)) {
                tokens[idx] = token;
                idx++;
            }
        }
    }
}
