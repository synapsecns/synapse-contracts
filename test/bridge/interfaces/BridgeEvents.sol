// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

interface BridgeEvents {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              BRIDGE IN                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    event TokenWithdraw(address indexed to, IERC20 token, uint256 amount, uint256 fee, bytes32 indexed kappa);

    event TokenMint(address indexed to, IERC20 token, uint256 amount, uint256 fee, bytes32 indexed kappa);

    event TokenMintAndSwap(
        address indexed to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bool swapSuccess,
        bytes32 indexed kappa
    );

    event TokenWithdrawAndRemove(
        address indexed to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bool swapSuccess,
        bytes32 indexed kappa
    );

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              BRIDGE OUT                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    event TokenDeposit(address indexed to, uint256 chainId, IERC20 token, uint256 amount);

    event TokenRedeem(address indexed to, uint256 chainId, IERC20 token, uint256 amount);

    event TokenDepositAndSwap(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );

    event TokenRedeemAndSwap(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );

    event TokenRedeemAndRemove(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline
    );

    event TokenRedeemV2(bytes32 indexed to, uint256 chainId, IERC20 token, uint256 amount);
}
