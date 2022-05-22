// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library GasFeePricingUpdates {
    enum MsgType {
        UNKNOWN,
        UPDATE_CONFIG,
        UPDATE_INFO
    }

    function encode(
        uint8 _txType,
        uint128 _newValueA,
        uint128 _newValueB
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(_txType, _newValueA, _newValueB);
    }

    function decode(bytes memory _message)
        internal
        pure
        returns (
            uint8 txType,
            uint128 newValueA,
            uint128 newValueB
        )
    {
        require(_message.length == 33, "Unknown message format");
        // solhint-disable-next-line
        assembly {
            txType := mload(add(_message, 1))
            newValueA := mload(add(_message, 17))
            newValueB := mload(add(_message, 33))
        }
    }
}
