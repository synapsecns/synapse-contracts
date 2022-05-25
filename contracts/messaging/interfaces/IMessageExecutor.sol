// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IMessageExecutor {
    function executeMessage(
        uint256 _srcChainId,
        bytes32 _srcAddress,
        address _dstAddress,
        bytes calldata _message,
        bytes calldata _options
    ) external;
}
