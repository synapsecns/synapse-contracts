// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseBridgeModule} from "../../../../contracts/router/modules/bridge/SynapseBridgeModule.sol";
import {ILocalBridgeConfig} from "../../../../contracts/router/interfaces/ILocalBridgeConfig.sol";

import {Test} from "forge-std/Test.sol";

abstract contract SynapseRouterV2BridgeUtils is Test {
    // Utils06 events for Synapse bridge
    event TokenDeposit(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenRedeem(address indexed to, uint256 chainId, address token, uint256 amount);
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

    // synapse bridge events as structs
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

    DepositEvent internal depositEvent;
    RedeemEvent internal redeemEvent;
    DepositAndSwapEvent internal depositAndSwapEvent;
    RedeemAndSwapEvent internal redeemAndSwapEvent;
    RedeemAndRemoveEvent internal redeemAndRemoveEvent;

    // synapse bridge module
    address public synapseLocalBridgeConfig;
    address public synapseBridge;
    address public synapseBridgeModule;

    function deploySynapseBridgeModule() public virtual {
        require(synapseLocalBridgeConfig != address(0), "synapseLocalBridgeConfig == address(0)");
        require(synapseBridge != address(0), "synapseBridge == address(0)");
        synapseBridgeModule = address(new SynapseBridgeModule(synapseLocalBridgeConfig, synapseBridge));
    }

    function expectDepositEvent() internal {
        vm.expectEmit(synapseBridge);
        emit TokenDeposit(depositEvent.to, depositEvent.chainId, depositEvent.token, depositEvent.amount);
    }

    function expectRedeemEvent() internal {
        vm.expectEmit(synapseBridge);
        emit TokenRedeem(redeemEvent.to, redeemEvent.chainId, redeemEvent.token, redeemEvent.amount);
    }

    function expectDepositAndSwapEvent() internal {
        vm.expectEmit(synapseBridge);
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
        vm.expectEmit(synapseBridge);
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
        vm.expectEmit(synapseBridge);
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
}
