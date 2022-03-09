// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicQuoter} from "./interfaces/IBasicQuoter.sol";

import {Ownable} from "@openzeppelin/contracts-4.4.2/access/Ownable.sol";
import {Bytes} from "@synapseprotocol/sol-lib/contracts/universal/lib/LibBytes.sol";

contract BasicQuoter is Ownable, IBasicQuoter {
    address[] public trustedTokens;

    constructor(address[] memory _tokens) {
        setTokens(_tokens);
    }

    // -- MODIFIERS --

    modifier checkTokenIndex(uint256 _index) {
        require(_index < trustedTokens.length, "Token index out of range");
        _;
    }

    //  -- VIEWS --

    function getTrustedToken(uint8 _index)
        external
        view
        checkTokenIndex(_index)
        returns (address)
    {
        return trustedTokens[_index];
    }

    function trustedTokensCount() external view returns (uint256) {
        return trustedTokens.length;
    }

    // -- RESTRICTED TOKEN FUNCTIONS --

    function addTrustedToken(address _token) external onlyOwner {
        trustedTokens.push(_token);
        emit AddedTrustedToken(_token);
    }

    function removeToken(address _token) external onlyOwner {
        for (uint256 i = 0; i < trustedTokens.length; i++) {
            if (trustedTokens[i] == _token) {
                _removeTokenByIndex(i);
                return;
            }
        }
        revert("Token not found");
    }

    function removeTokenByIndex(uint256 _index) external onlyOwner {
        _removeTokenByIndex(_index);
    }

    function setTokens(address[] memory _tokens) public onlyOwner {
        emit UpdatedTrustedTokens(_tokens);
        trustedTokens = _tokens;
    }

    // -- INTERNAL HELPERS: OfferWithGas --

    /**
     * Appends Query elements to Offer struct
     */
    function _addQueryWithGas(
        OfferWithGas memory _queries,
        uint256 _amount,
        address _adapter,
        address _tokenOut,
        uint256 _gasEstimate
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
        _queries.gasEstimate += _gasEstimate;
    }

    /**
     * Makes a deep copy of OfferWithGas struct
     */
    function _cloneOfferWithGas(OfferWithGas memory _queries)
        internal
        pure
        returns (OfferWithGas memory)
    {
        return
            OfferWithGas(
                _queries.amounts,
                _queries.adapters,
                _queries.path,
                _queries.gasEstimate
            );
    }

    // -- INTERNAL HELPERS: formatters --

    /**
     * Converts byte-arrays to an array of integers
     */
    function _formatAmounts(bytes memory _amounts)
        internal
        pure
        returns (uint256[] memory)
    {
        // Format amounts
        uint256 chunks = _amounts.length / 32;
        uint256[] memory amountsFormatted = new uint256[](chunks);
        for (uint256 i = 0; i < chunks; i++) {
            amountsFormatted[i] = Bytes.toUint256(i * 32 + 32, _amounts);
        }
        return amountsFormatted;
    }

    /**
     * Converts byte-array to an array of addresses
     */
    function _formatAddresses(bytes memory _addresses)
        internal
        pure
        returns (address[] memory)
    {
        uint256 chunks = _addresses.length / 32;
        address[] memory addressesFormatted = new address[](chunks);
        for (uint256 i = 0; i < chunks; i++) {
            addressesFormatted[i] = Bytes.toAddress(i * 32 + 32, _addresses);
        }
        return addressesFormatted;
    }

    /**
     * Formats elements in the Offer object from byte-arrays to integers and addresses
     */
    function _formatOfferWithGas(OfferWithGas memory _queries)
        internal
        pure
        returns (FormattedOfferWithGas memory)
    {
        return
            FormattedOfferWithGas(
                _formatAmounts(_queries.amounts),
                _formatAddresses(_queries.adapters),
                _formatAddresses(_queries.path),
                _queries.gasEstimate
            );
    }

    // -- PRIVATE FUNCTIONS --

    function _removeTokenByIndex(uint256 _index)
        private
        checkTokenIndex(_index)
    {
        address _removedToken = trustedTokens[_index];
        emit RemovedToken(_removedToken);
        // We don't care about tokens order, so we replace the
        // selected token with the last one
        trustedTokens[_index] = trustedTokens[trustedTokens.length - 1];
        trustedTokens.pop();
    }
}
