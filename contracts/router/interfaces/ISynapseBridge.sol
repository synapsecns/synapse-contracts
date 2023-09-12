// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISynapseBridge {
    function deposit(
        address to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external;

    function depositAndSwap(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external;

    function redeem(
        address to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external;

    function redeemV2(
        bytes32 to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external;

    function redeemAndSwap(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external;

    function redeemAndRemove(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 liqTokenIndex,
        uint256 liqMinAmount,
        uint256 liqDeadline
    ) external;
}
