// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TokenMessengerEvents} from "../../../contracts/cctp/events/TokenMessengerEvents.sol";
import {IMessageTransmitter} from "../../../contracts/cctp/interfaces/IMessageTransmitter.sol";
import {ITokenMessenger} from "../../../contracts/cctp/interfaces/ITokenMessenger.sol";
import {ITokenMinter} from "../../../contracts/cctp/interfaces/ITokenMinter.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract MockTokenMessenger is TokenMessengerEvents, ITokenMessenger {
    using SafeERC20 for IERC20;

    address public override localMessageTransmitter;
    address public override localMinter;
    mapping(uint32 => bytes32) public remoteTokenMessenger;

    constructor(address localMessageTransmitter_) {
        localMessageTransmitter = localMessageTransmitter_;
    }

    function setLocalMinter(address localMinter_) external {
        localMinter = localMinter_;
    }

    function setRemoteTokenMessenger(uint32 remoteDomain, bytes32 remoteTokenMessenger_) external {
        remoteTokenMessenger[remoteDomain] = remoteTokenMessenger_;
    }

    function depositForBurnWithCaller(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller
    ) external returns (uint64 nonce) {
        IERC20(burnToken).safeTransferFrom(msg.sender, localMinter, amount);
        ITokenMinter(localMinter).burn(burnToken, amount);
        bytes memory messageBody = formatTokenMessage(amount, mintRecipient, burnToken);
        nonce = IMessageTransmitter(localMessageTransmitter).sendMessageWithCaller(
            destinationDomain,
            remoteTokenMessenger[destinationDomain],
            destinationCaller,
            messageBody
        );
        emit DepositForBurn({
            nonce: nonce,
            burnToken: burnToken,
            amount: amount,
            depositor: msg.sender,
            mintRecipient: mintRecipient,
            destinationDomain: destinationDomain,
            destinationTokenMessenger: remoteTokenMessenger[destinationDomain],
            destinationCaller: destinationCaller
        });
    }

    function handleReceiveMessage(
        uint32 remoteDomain,
        bytes32 sender,
        bytes calldata messageBody
    ) external returns (bool success) {
        require(msg.sender == localMessageTransmitter, "Invalid message transmitter");
        require(sender == remoteTokenMessenger[remoteDomain], "Remote TokenMessenger unsupported");
        (uint256 amount, bytes32 mintRecipient, bytes32 burnToken) = abi.decode(
            messageBody,
            (uint256, bytes32, bytes32)
        );
        address mintToken = ITokenMinter(localMinter).mint(
            remoteDomain,
            burnToken,
            address(uint160(uint256(mintRecipient))),
            amount
        );
        emit MintAndWithdraw({
            mintRecipient: address(uint160(uint256(mintRecipient))),
            amount: amount,
            mintToken: mintToken
        });
        return true;
    }

    function formatTokenMessage(
        uint256 amount,
        bytes32 mintRecipient,
        address burnToken
    ) public pure returns (bytes memory tokenMessage) {
        return abi.encode(amount, mintRecipient, bytes32(uint256(uint160(burnToken))));
    }
}
