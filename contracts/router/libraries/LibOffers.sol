// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Bytes} from "./LibBytes.sol";

library Offers {
    struct Offer {
        bytes amounts;
        bytes adapters;
        bytes path;
    }

    struct FormattedOffer {
        uint256[] amounts;
        address[] adapters;
        address[] path;
    }

    /**
     * Appends Query elements to Offer struct
     */
    function addQuery(
        Offer memory _queries,
        uint256 _amount,
        address _adapter,
        address _tokenOut
    ) internal pure {
        _queries.path = Bytes.mergeBytes(
            _queries.path,
            Bytes.toBytes(_tokenOut)
        );
        _queries.amounts = Bytes.mergeBytes(
            _queries.amounts,
            Bytes.toBytes(_amount)
        );
        _queries.adapters = Bytes.mergeBytes(
            _queries.adapters,
            Bytes.toBytes(_adapter)
        );
    }

    /**
     * Makes a deep copy of Offer struct
     */
    function cloneOfferWithGas(Offer memory _queries)
        internal
        pure
        returns (Offer memory)
    {
        return Offer(_queries.amounts, _queries.adapters, _queries.path);
    }

    function containsToken(bytes memory addresses, address token)
        internal
        pure
        returns (bool)
    {
        uint256 chunks = addresses.length / 32;
        for (uint256 i = 0; i < chunks; i++) {
            if (Bytes.toAddress(i * 32 + 32, addresses) == token) {
                return true;
            }
        }
        return false;
    }

    /**
     * Formats elements in the Offer object from byte-arrays to integers and addresses
     */
    function formatOfferWithGas(Offer memory _queries)
        internal
        pure
        returns (FormattedOffer memory)
    {
        return
            FormattedOffer(
                Bytes.toArrayUint256(_queries.amounts),
                Bytes.toArrayAddress(_queries.adapters),
                Bytes.toArrayAddress(_queries.path)
            );
    }
}
