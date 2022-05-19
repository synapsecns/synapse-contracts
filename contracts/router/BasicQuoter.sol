// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicQuoter} from "./interfaces/IBasicQuoter.sol";
import {IBasicRouter} from "./interfaces/IBasicRouter.sol";

import {Bytes} from "./libraries/LibBytes.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

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
    // solhint-disable-next-line
    uint8 public MAX_SWAPS;

    address payable public immutable router;

    constructor(address payable _router, uint8 _maxSwaps) {
        setMaxSwaps(_maxSwaps);
        router = _router;
    }

    // -- MODIFIERS --

    modifier checkTokenIndex(uint8 index) {
        require(index < trustedTokens.length, "Token index out of range");
        _;
    }

    modifier checkAdapterIndex(uint8 index) {
        require(index < trustedAdapters.length, "Adapter index out of range");
        _;
    }

    //  -- VIEWS --

    function getTrustedAdapter(uint8 index) external view checkAdapterIndex(index) returns (address) {
        return trustedAdapters[index];
    }

    function getTrustedToken(uint8 index) external view checkTokenIndex(index) returns (address) {
        return trustedTokens[index];
    }

    function trustedAdaptersCount() external view returns (uint256) {
        return trustedAdapters.length;
    }

    function trustedTokensCount() external view returns (uint256) {
        return trustedTokens.length;
    }

    // -- RESTRICTED ADAPTER FUNCTIONS --

    function addTrustedAdapter(address adapter) external onlyOwner {
        for (uint8 i = 0; i < trustedAdapters.length; i++) {
            require(trustedAdapters[i] != adapter, "Adapter already added");
        }
        trustedAdapters.push(adapter);
        // Add Adapter to Router as well
        IBasicRouter(router).addTrustedAdapter(adapter);
        emit AddedTrustedAdapter(adapter);
    }

    function removeAdapter(address adapter) external onlyOwner {
        for (uint8 i = 0; i < trustedAdapters.length; i++) {
            if (trustedAdapters[i] == adapter) {
                _removeAdapterByIndex(i);
                return;
            }
        }
        revert("Adapter not found");
    }

    function removeAdapterByIndex(uint8 index) external onlyOwner {
        _removeAdapterByIndex(index);
    }

    // -- RESTRICTED TOKEN FUNCTIONS --

    function addTrustedToken(address token) external onlyOwner {
        for (uint8 i = 0; i < trustedTokens.length; i++) {
            require(trustedTokens[i] != token, "Token already added");
        }
        trustedTokens.push(token);
        emit AddedTrustedToken(token);
    }

    function removeToken(address token) external onlyOwner {
        for (uint8 i = 0; i < trustedTokens.length; i++) {
            if (trustedTokens[i] == token) {
                _removeTokenByIndex(i);
                return;
            }
        }
        revert("Token not found");
    }

    function removeTokenByIndex(uint8 index) external onlyOwner {
        _removeTokenByIndex(index);
    }

    // -- RESTRICTED SETTERS

    /// @dev This doesn't check if any of the adapters are duplicated,
    /// so make sure to check the data for duplicates
    function setAdapters(address[] calldata adapters) external onlyOwner {
        // First, remove old Adapters, if there are any
        if (trustedAdapters.length > 0) {
            IBasicRouter(router).setAdapters(trustedAdapters, false);
        }
        trustedAdapters = adapters;
        IBasicRouter(router).setAdapters(adapters, true);
        emit UpdatedTrustedAdapters(adapters);
    }

    function setMaxSwaps(uint8 _maxSwaps) public onlyOwner {
        require(_maxSwaps != 0, "Amount of swaps can't be zero");
        MAX_SWAPS = _maxSwaps;
    }

    /// @dev This doesn't check if any of the tokens are duplicated,
    /// so make sure to check the data for duplicates
    function setTokens(address[] calldata tokens) public onlyOwner {
        trustedTokens = tokens;
        emit UpdatedTrustedTokens(tokens);
    }

    // -- PRIVATE FUNCTIONS --

    function _removeAdapterByIndex(uint8 index) private checkAdapterIndex(index) {
        address removedAdapter = trustedAdapters[index];

        // We don't care about adapters order, so we replace the
        // selected adapter with the last one
        trustedAdapters[index] = trustedAdapters[trustedAdapters.length - 1];
        trustedAdapters.pop();

        // Remove Adapter from Router as well
        IBasicRouter(router).removeAdapter(removedAdapter);

        emit RemovedAdapter(removedAdapter);
    }

    function _removeTokenByIndex(uint8 index) private checkTokenIndex(index) {
        address removedToken = trustedTokens[index];

        // We don't care about tokens order, so we replace the
        // selected token with the last one
        trustedTokens[index] = trustedTokens[trustedTokens.length - 1];
        trustedTokens.pop();

        emit RemovedToken(removedToken);
    }
}
