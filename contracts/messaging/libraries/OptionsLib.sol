// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library OptionsLib {
    enum TxType {
        UNKNOWN,
        DEFAULT,
        GASDROP
    }

    function encode(uint256 _gasLimit) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(TxType.DEFAULT), _gasLimit);
    }

    function encode(
        uint256 _gasLimit,
        uint256 _gasDropAmount,
        bytes32 _dstReceiver
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(TxType.GASDROP), _gasLimit, _gasDropAmount, _dstReceiver);
    }

    function decode(bytes memory _options)
        internal
        pure
        returns (
            uint256 gasLimit,
            uint256 gasDropAmount,
            bytes32 dstReceiver
        )
    {
        require(_options.length == 2 + 32 || _options.length == 2 + 32 * 3, "Wrong _options size");
        uint16 txType;
        // solhint-disable-next-line
        assembly {
            txType := mload(add(_options, 2))
            gasLimit := mload(add(_options, 34))
        }

        if (txType == uint16(TxType.GASDROP)) {
            // solhint-disable-next-line
            assembly {
                gasDropAmount := mload(add(_options, 66))
                dstReceiver := mload(add(_options, 98))
            }
            require(gasDropAmount != 0, "gasDropAmount empty");
            require(dstReceiver != bytes32(0), "dstReceiver empty");
        }
    }
}
