// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPool} from "./IDefaultPool.sol";

interface IDefaultExtendedPool is IDefaultPool {
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256);

    function removeLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 minAmount,
        uint256 deadline
    ) external returns (uint256);

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    function calculateRemoveLiquidity(uint256 amount) external view returns (uint256[] memory);

    function calculateRemoveLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex)
        external
        view
        returns (uint256 availableTokenAmount);

    function getAPrecise() external view returns (uint256);

    function getTokenBalance(uint8 index) external view returns (uint256);

    function swapStorage()
        external
        view
        returns (
            uint256 initialA,
            uint256 futureA,
            uint256 initialATime,
            uint256 futureATime,
            uint256 swapFee,
            uint256 adminFee,
            address lpToken
        );
}
