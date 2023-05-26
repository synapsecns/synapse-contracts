// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Utilities06} from "../../utils/Utilities06.sol";

abstract contract SynapseRouterExpectations is Utilities06 {
    struct DepositEvent {
        address to;
        uint256 chainId;
        address token;
        uint256 amount;
    }

    struct RedeemEvent {
        address to;
        uint256 chainId;
        address token;
        uint256 amount;
    }

    struct DepositAndSwapEvent {
        address to;
        uint256 chainId;
        address token;
        uint256 amount;
        uint8 tokenIndexFrom;
        uint8 tokenIndexTo;
        uint256 minDy;
        uint256 deadline;
    }

    struct RedeemAndSwapEvent {
        address to;
        uint256 chainId;
        address token;
        uint256 amount;
        uint8 tokenIndexFrom;
        uint8 tokenIndexTo;
        uint256 minDy;
        uint256 deadline;
    }

    struct RedeemAndRemoveEvent {
        address to;
        uint256 chainId;
        address token;
        uint256 amount;
        uint8 swapTokenIndex;
        uint256 swapMinAmount;
        uint256 swapDeadline;
    }

    address internal emittingBridge;
    DepositEvent internal depositEvent;
    RedeemEvent internal redeemEvent;
    DepositAndSwapEvent internal depositAndSwapEvent;
    RedeemAndSwapEvent internal redeemAndSwapEvent;
    RedeemAndRemoveEvent internal redeemAndRemoveEvent;

    bytes internal revertMessage;

    function expectDepositEvent() internal {
        vm.expectEmit(emittingBridge);
        emit TokenDeposit(depositEvent.to, depositEvent.chainId, depositEvent.token, depositEvent.amount);
    }

    function expectRedeemEvent() internal {
        vm.expectEmit(emittingBridge);
        emit TokenRedeem(redeemEvent.to, redeemEvent.chainId, redeemEvent.token, redeemEvent.amount);
    }

    function expectDepositAndSwapEvent() internal {
        vm.expectEmit(emittingBridge);
        emit TokenDepositAndSwap(
            depositAndSwapEvent.to,
            depositAndSwapEvent.chainId,
            depositAndSwapEvent.token,
            depositAndSwapEvent.amount,
            depositAndSwapEvent.tokenIndexFrom,
            depositAndSwapEvent.tokenIndexTo,
            depositAndSwapEvent.minDy,
            depositAndSwapEvent.deadline
        );
    }

    function expectRedeemAndSwapEvent() internal {
        vm.expectEmit(emittingBridge);
        emit TokenRedeemAndSwap(
            redeemAndSwapEvent.to,
            redeemAndSwapEvent.chainId,
            redeemAndSwapEvent.token,
            redeemAndSwapEvent.amount,
            redeemAndSwapEvent.tokenIndexFrom,
            redeemAndSwapEvent.tokenIndexTo,
            redeemAndSwapEvent.minDy,
            redeemAndSwapEvent.deadline
        );
    }

    function expectRedeemAndRemoveEvent() internal {
        vm.expectEmit(emittingBridge);
        emit TokenRedeemAndRemove(
            redeemAndRemoveEvent.to,
            redeemAndRemoveEvent.chainId,
            redeemAndRemoveEvent.token,
            redeemAndRemoveEvent.amount,
            redeemAndRemoveEvent.swapTokenIndex,
            redeemAndRemoveEvent.swapMinAmount,
            redeemAndRemoveEvent.swapDeadline
        );
    }

    function expectRevert() internal {
        vm.expectRevert(revertMessage);
    }

    function expectNothing() internal pure {
        // Same vibes as your parents expectations, anon
    }
}
