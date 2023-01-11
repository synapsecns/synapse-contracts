// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

abstract contract MulticallView {
    struct Result {
        bool success;
        bytes returnData;
    }

    /// @notice Aggregates a few static calls to this contract into one multicall.
    /// Any of the calls could revert without having impact on other calls. That includes the scenario,
    /// where a data for state modifying call was supplied, which would lead to one of the calls being reverted.
    function multicallView(bytes[] memory data) external view returns (Result[] memory callResults) {
        uint256 amount = data.length;
        callResults = new Result[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            (callResults[i].success, callResults[i].returnData) = address(this).staticcall(data[i]);
        }
    }
}
