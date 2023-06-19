// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPool} from "../../../contracts/router/interfaces/IDefaultPool.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

/// A simple lightweight mock of the Default pool contract for testing purposes.
/// Note that the mock is using the UniSwap formula for price calculations. This is done to simplify the logic.
/// Note there is no addLiquidity or removeLiquidity. This pool is using the whole balance of each token as liquidity.
/// Mint of transfer test tokens to the pool address before using the pool.
contract MockDefaultPool is IDefaultPool {
    using SafeERC20 for IERC20;

    address[] internal _tokens;
    uint256 internal _coins;

    // We don't expose paused() in this contract to test that LinkedPool could handle pools without this function.
    bool internal _paused;

    constructor(address[] memory tokens) {
        _tokens = tokens;
        _coins = tokens.length;
    }

    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        if (_paused) revert("Siesta time");
        amountOut = _calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
        require(amountOut >= minDy, "Insufficient output amount");
        // solhint-disable-next-line not-rely-on-time
        require(deadline >= block.timestamp, "Deadline expired");
        IERC20(_getToken(tokenIndexFrom)).safeTransferFrom(msg.sender, address(this), dx);
        IERC20(_getToken(tokenIndexTo)).safeTransfer(msg.sender, amountOut);
    }

    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut) {
        return _calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    }

    function getToken(uint8 index) external view returns (address token) {
        return _getToken(index);
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    function _calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) internal view returns (uint256 amountOut) {
        if (tokenIndexFrom == tokenIndexTo) return 0;
        if (tokenIndexFrom >= _coins || tokenIndexTo >= _coins) return 0;
        uint256 balanceFrom = _getBalance(_getToken(tokenIndexFrom));
        uint256 balanceTo = _getBalance(_getToken(tokenIndexTo));
        require(balanceFrom > 0 && balanceTo > 0, "No liquidity");
        // Follow the Uniswap formula for calculating the amountOut
        amountOut = (dx * balanceTo * 997) / (balanceFrom * 1000 + dx * 997);
    }

    function _getBalance(address token) internal view returns (uint256 balance) {
        return IERC20(token).balanceOf(address(this));
    }

    function _getToken(uint8 index) internal view returns (address token) {
        require(index < _coins, "Incorrect token index");
        return _tokens[index];
    }
}
