// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/// @notice Multicall utility for view/pure functions. Inspired by Multicall3:
/// https://github.com/mds1/multicall/blob/master/src/Multicall3.sol
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
            // We perform a static call to ourselves here. This will record `success` as false,
            // should the static call be reverted. The other calls will still be performed regardless.
            // Note: `success` will be set to false, if data for state modifying call was supplied.
            // No data will be modified, as this is a view function.
            (callResults[i].success, callResults[i].returnData) = address(this).staticcall(data[i]);
        }
    }
}
