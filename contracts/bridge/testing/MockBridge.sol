// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import "../interfaces/IMetaSwapDeposit.sol";
import "../interfaces/ISwap.sol";
import {ISynapseBridge} from '../interfaces/ISynapseBridge.sol';


interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

// MockBridge is a bridge which does nothing and is used to test the auth proxy
contract MockBridge is ISynapseBridge {
    using SafeERC20 for IERC20;

    function deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external{}

    function depositAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external{}

    function redeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external{}

    function redeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external{}

    function redeemAndRemove(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 liqTokenIndex,
        uint256 liqMinAmount,
        uint256 liqDeadline
    ) external{}

    function withdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external{}

    function mint(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external{}

    function mintAndSwap(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        IMetaSwapDeposit pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bytes32 kappa
    ) external{}

    function withdrawAndRemove(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        ISwap pool,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bytes32 kappa
    ) external{}
}
