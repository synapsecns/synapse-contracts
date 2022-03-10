// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicQuoter} from "./interfaces/IBasicQuoter.sol";
import {IBasicRouter} from "./interfaces/IBasicRouter.sol";

import {Ownable} from "@openzeppelin/contracts-4.4.2/access/Ownable.sol";
import {Bytes} from "@synapseprotocol/sol-lib/contracts/universal/lib/LibBytes.sol";

contract BasicQuoter is Ownable, IBasicQuoter {
    address[] internal trustedTokens;
    address[] internal trustedAdapters;

    uint8 public maxSteps;

    IBasicRouter public immutable router;

    constructor(uint8 _maxSteps, IBasicRouter _router) {
        setMaxSteps(_maxSteps);
        router = _router;
    }

    // -- MODIFIERS --

    modifier checkTokenIndex(uint8 _index) {
        require(_index < trustedTokens.length, "Token index out of range");
        _;
    }

    modifier checkAdapterIndex(uint8 _index) {
        require(_index < trustedAdapters.length, "Adapter index out of range");
        _;
    }

    //  -- VIEWS --

    function getTrustedAdapter(uint8 _index)
        external
        view
        checkAdapterIndex(_index)
        returns (address)
    {
        return trustedAdapters[_index];
    }

    function getTrustedToken(uint8 _index)
        external
        view
        checkTokenIndex(_index)
        returns (address)
    {
        return trustedTokens[_index];
    }

    function trustedAdaptersCount() external view returns (uint256) {
        return trustedAdapters.length;
    }

    function trustedTokensCount() external view returns (uint256) {
        return trustedTokens.length;
    }

    // -- RESTRICTED ADAPTER FUNCTIONS --

    function addTrustedAdapter(address _adapter) external onlyOwner {
        trustedAdapters.push(_adapter);
        // Add Adapter to Router as well
        router.addTrustedAdapter(_adapter);
        emit AddedTrustedAdapter(_adapter);
    }

    function removeAdapter(address _adapter) external onlyOwner {
        for (uint8 i = 0; i < trustedAdapters.length; i++) {
            if (trustedAdapters[i] == _adapter) {
                _removeAdapterByIndex(i);
                return;
            }
        }
        revert("Adapter not found");
    }

    function removeAdapterByIndex(uint8 _index) external onlyOwner {
        _removeAdapterByIndex(_index);
    }

    // -- RESTRICTED TOKEN FUNCTIONS --

    function addTrustedToken(address _token) external onlyOwner {
        trustedTokens.push(_token);
        emit AddedTrustedToken(_token);
    }

    function removeToken(address _token) external onlyOwner {
        for (uint8 i = 0; i < trustedTokens.length; i++) {
            if (trustedTokens[i] == _token) {
                _removeTokenByIndex(i);
                return;
            }
        }
        revert("Token not found");
    }

    function removeTokenByIndex(uint8 _index) external onlyOwner {
        _removeTokenByIndex(_index);
    }

    // -- RESTRICTED SETTERS

    function setAdapters(address[] calldata _adapters) external onlyOwner {
        // First, remove old Adapters, if there are any
        if (trustedAdapters.length > 0) {
            router.setAdapters(trustedAdapters, false);
        }
        trustedAdapters = _adapters;
        router.setAdapters(_adapters, true);
        emit UpdatedTrustedAdapters(_adapters);
    }

    function setMaxSteps(uint8 _maxSteps) public onlyOwner {
        maxSteps = _maxSteps;
    }

    function setTokens(address[] calldata _tokens) public onlyOwner {
        trustedTokens = _tokens;
        emit UpdatedTrustedTokens(_tokens);
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

    function _removeAdapterByIndex(uint8 _index)
        private
        checkAdapterIndex(_index)
    {
        address _removedAdapter = trustedAdapters[_index];

        // We don't care about adapters order, so we replace the
        // selected adapter with the last one
        trustedAdapters[_index] = trustedAdapters[trustedAdapters.length - 1];
        trustedAdapters.pop();

        // Remove Adapter from Router as well
        router.removeAdapter(_removedAdapter);

        emit RemovedAdapter(_removedAdapter);
    }

    function _removeTokenByIndex(uint8 _index) private checkTokenIndex(_index) {
        address _removedToken = trustedTokens[_index];

        // We don't care about tokens order, so we replace the
        // selected token with the last one
        trustedTokens[_index] = trustedTokens[trustedTokens.length - 1];
        trustedTokens.pop();

        emit RemovedToken(_removedToken);
    }
}
