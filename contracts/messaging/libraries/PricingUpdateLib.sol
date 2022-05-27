// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library PricingUpdateLib {
    enum MsgType {
        UNKNOWN,
        UPDATE_CONFIG,
        UPDATE_INFO
    }

    function encodeConfig(
        uint112 _gasDropMax,
        uint80 _gasUnitsRcvMsg,
        uint32 _minGasUsageFeeUsd
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(MsgType.UPDATE_CONFIG, _gasDropMax, _gasUnitsRcvMsg, _minGasUsageFeeUsd);
    }

    function encodeInfo(uint128 _gasTokenPrice, uint128 _gasUnitPrice) internal pure returns (bytes memory) {
        return abi.encodePacked(MsgType.UPDATE_INFO, _gasTokenPrice, _gasUnitPrice);
    }

    function decodeConfig(bytes memory _message)
        internal
        pure
        returns (
            uint112 gasDropMax,
            uint80 gasUnitsRcvMsg,
            uint32 minGasUsageFeeUsd
        )
    {
        // message: (uint8, uint112, uint80, uint32)
        // length: (1, 14, 10, 4)
        // offset: (1, 15, 25, 29)
        require(_message.length == 29, "Wrong message length");
        uint8 msgType;
        // solhint-disable-next-line
        assembly {
            msgType := mload(add(_message, 1))
            gasDropMax := mload(add(_message, 15))
            gasUnitsRcvMsg := mload(add(_message, 25))
            minGasUsageFeeUsd := mload(add(_message, 29))
        }
        require(msgType == uint8(MsgType.UPDATE_CONFIG), "Wrong msgType");
    }

    function decodeInfo(bytes memory _message) internal pure returns (uint128 gasTokenPrice, uint128 gasUnitPrice) {
        // message: (uint8, uint128, uint128)
        // length: (1, 16, 16)
        // offset: (1, 17, 33)
        require(_message.length == 33, "Wrong message length");
        uint8 msgType;
        // solhint-disable-next-line
        assembly {
            msgType := mload(add(_message, 1))
            gasTokenPrice := mload(add(_message, 17))
            gasUnitPrice := mload(add(_message, 33))
        }
        require(msgType == uint8(MsgType.UPDATE_INFO), "Wrong msgType");
    }

    function messageType(bytes memory _message) internal pure returns (uint8 msgType) {
        // solhint-disable-next-line
        assembly {
            msgType := mload(add(_message, 1))
        }
    }
}
