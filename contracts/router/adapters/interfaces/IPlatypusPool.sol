// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPlatypusPool {
    // -- VIEWS --
    function getTokenAddresses() external view returns (address[] memory);

    function paused() external view returns (bool);

    function quotePotentialSwap(
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) external view returns (uint256 potentialOutcome, uint256 haircut);

    // -- SWAP --
    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 actualToAmount, uint256 haircut);
}
