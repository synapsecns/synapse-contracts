// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

library Bytes {
    function toBytes(address x) internal pure returns (bytes memory b) {
        b = new bytes(32);
        assembly {
            mstore(add(b, 32), x)
        }
    }

    function toAddress(uint256 _offst, bytes memory _input)
        internal
        pure
        returns (address _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function toBytes(uint256 x) internal pure returns (bytes memory b) {
        b = new bytes(32);
        assembly {
            mstore(add(b, 32), x)
        }
    }

    function toUint256(uint256 _offst, bytes memory _input)
        internal
        pure
        returns (uint256 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function mergeBytes(bytes memory a, bytes memory b)
        internal
        pure
        returns (bytes memory c)
    {
        // From https://ethereum.stackexchange.com/a/40456
        uint256 alen = a.length;
        uint256 totallen = alen + b.length;
        uint256 loopsa = (a.length + 31) / 32;
        uint256 loopsb = (b.length + 31) / 32;
        assembly {
            let m := mload(0x40)
            mstore(m, totallen)
            for {
                let i := 0
            } lt(i, loopsa) {
                i := add(1, i)
            } {
                mstore(
                    add(m, mul(32, add(1, i))),
                    mload(add(a, mul(32, add(1, i))))
                )
            }
            for {
                let i := 0
            } lt(i, loopsb) {
                i := add(1, i)
            } {
                mstore(
                    add(m, add(mul(32, add(1, i)), alen)),
                    mload(add(b, mul(32, add(1, i))))
                )
            }
            mstore(0x40, add(m, add(32, totallen)))
            c := m
        }
    }
}
