// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMessageExecutor {
    /**
     * @notice Returns srcGasToken fee to charge in wei for the cross-chain message based on the gas limit, gas airdrop, etc.
     * @param _options Versioned struct used to instruct message executor on how to proceed with gas limit, gas airdrop, etc.
     */
    function estimateGasFee(uint256 _dstChainId, bytes calldata _options) external view returns (uint256 fee);

    function executeMessage(
        uint256 _srcChainId,
        bytes32 _srcAddress,
        address _dstAddress,
        bytes calldata _message,
        bytes calldata _options
    ) external returns (address gasDropRecipient, uint256 gasDropAmount);
}
