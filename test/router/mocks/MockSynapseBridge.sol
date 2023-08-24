// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISynapseBridge} from "../../../contracts/router/interfaces/ISynapseBridge.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

// solhint-disable no-empty-blocks
contract MockSynapseBridge is ISynapseBridge {
    using SafeERC20 for IERC20;

    event TokenDeposit(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenDepositAndSwap(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );

    event TokenRedeem(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenRedeemAndSwap(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenRedeemAndRemove(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline
    );

    event TokenRedeemV2(bytes32 indexed to, uint256 chainId, address token, uint256 amount);

    function deposit(
        address to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit TokenDeposit(to, chainId, token, amount);
    }

    function depositAndSwap(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit TokenDepositAndSwap(to, chainId, token, amount, tokenIndexFrom, tokenIndexTo, minDy, deadline);
    }

    function redeem(
        address to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit TokenRedeem(to, chainId, token, amount);
    }

    function redeemV2(
        bytes32 to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit TokenRedeemV2(to, chainId, token, amount);
    }

    function redeemAndSwap(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit TokenRedeemAndSwap(to, chainId, token, amount, tokenIndexFrom, tokenIndexTo, minDy, deadline);
    }

    function redeemAndRemove(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 liqTokenIndex,
        uint256 liqMinAmount,
        uint256 liqDeadline
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit TokenRedeemAndRemove(to, chainId, token, amount, liqTokenIndex, liqMinAmount, liqDeadline);
    }
}
