// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

interface IL2BridgeZap {
    function swapAndRedeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external;

    function swapAndRedeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 swapTokenIndexFrom,
        uint8 swapTokenIndexTo,
        uint256 swapMinDy,
        uint256 swapDeadline
    ) external;

    function swapAndRedeemAndRemove(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 liqTokenIndex,
        uint256 liqMinAmount,
        uint256 liqDeadline
    ) external;

    function redeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external;

    function deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external;

    function depositETH(
        address to,
        uint256 chainId,
        uint256 amount
    ) external payable;

    function depositETHAndSwap(
        address to,
        uint256 chainId,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external payable;

    function swapETHAndRedeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external payable;

    function swapETHAndRedeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 swapTokenIndexFrom,
        uint8 swapTokenIndexTo,
        uint256 swapMinDy,
        uint256 swapDeadline
    ) external payable;

    function redeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external;

    function redeemAndRemove(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 liqTokenIndex,
        uint256 liqMinAmount,
        uint256 liqDeadline
    ) external;

    function redeemV2(
        bytes32 to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external;
}

abstract contract L2BridgeZapTest is Test {
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

    IL2BridgeZap public immutable zap;
    address public immutable user;

    uint256 internal constant MAX_UINT256 = type(uint256).max;

    constructor() {
        zap = IL2BridgeZap(_deployZap());
        user = address(this);
    }

    function _deployZap() internal virtual returns (address _zap);
}
