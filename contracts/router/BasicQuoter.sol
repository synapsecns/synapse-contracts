// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicQuoter} from "./interfaces/IBasicQuoter.sol";
import {IBasicRouter} from "./interfaces/IBasicRouter.sol";

import {Ownable} from "@openzeppelin/contracts-4.4.2/access/Ownable.sol";
import {Bytes} from "@synapseprotocol/sol-lib/contracts/universal/lib/LibBytes.sol";

contract BasicQuoter is Ownable, IBasicQuoter {
    /// @notice A list of tokens that will be used as "intermediate" tokens, when
    /// finding the best path between initial and final token
    address[] internal trustedTokens;

    /// @notice A list of adapters that are abstracting away swaps via third party contracts
    address[] internal trustedAdapters;

    /// @notice Maximum amount of swaps that Quoter will be using
    /// for finding the best path between two tokens.
    /// This is done for two reasons:
    /// 1. Too many swaps in the path make very little sense
    /// 2. Every extra swap increases the amount of possible paths exponentially,
    ///    so we need some sensible limitation.
    uint8 public maxSwaps;

    IBasicRouter public immutable router;

    constructor(uint8 _maxSwaps, IBasicRouter _router) {
        setMaxSwaps(_maxSwaps);
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

    function setMaxSwaps(uint8 _maxSwaps) public onlyOwner {
        maxSwaps = _maxSwaps;
    }

    function setTokens(address[] calldata _tokens) public onlyOwner {
        trustedTokens = _tokens;
        emit UpdatedTrustedTokens(_tokens);
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
