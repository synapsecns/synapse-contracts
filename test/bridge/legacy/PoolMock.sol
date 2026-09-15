// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

// solhint-disable no-empty-blocks, no-unused-vars
contract PoolMock {
    /// @notice We include an empty "test" function so that this contract does not appear in the coverage report.
    function testPoolMock() external {}

    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 amount
    ) external returns (uint256) {}

    function calculateRemoveLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex) external returns (uint256) {}
}
