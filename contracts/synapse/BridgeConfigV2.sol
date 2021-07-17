// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

/**
 * @title BridgeConfig contract
 * @notice This token is used for configuring different tokens on the bridge and mapping them across chains.
**/

contract BridgeConfigV2 is AccessControl {
    bytes32 public constant BRIDGEMANAGER_ROLE = keccak256('BRIDGEMANAGER_ROLE');
    bytes32[] private _allTokenIDs;
    mapping(bytes32 => Token[]) private _allTokens; // key is tokenID
    mapping(uint256 => mapping(address => bytes32)) private _tokenIDMap; // key is chainID,tokenAddress
    mapping(bytes32 => mapping(uint256 => Token)) private _tokens; // key is tokenID,chainID

    struct Token {
        uint256 chainId;
        address tokenAddress;
        uint8 tokenDecimals;
        uint256 maxSwap;
        uint256 minSwap;
        uint256 swapFee;
        uint256 maxSwapFee;
        uint256 minSwapFee;
        bool hasUnderlying;
        bool isUnderlying;
    }


    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(BRIDGEMANAGER_ROLE, msg.sender);
    }

    function getAllTokenIDs() public view returns (bytes32[] memory result) {
        uint256 length = _allTokenIDs.length;
        result = new bytes32[](length);
        for (uint256 i = 0; i < length; ++i) {
            result[i] = _allTokenIDs[i];
        }
    }

    function getTokenID(uint256 chainID, address tokenAddress) public view returns (bytes32)  {
        return _tokenIDMap[chainID][tokenAddress];
    }

    function getToken(bytes32 tokenID, uint256 chainID) public view returns (Token memory token) {
        return _tokens[tokenID][chainID];
    }

    function getUnderlyingToken(bytes32 tokenID) public view returns (Token memory token) {
        Token[] storage _mcTokens = _allTokens[tokenID];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].isUnderlying == true) {
                return _mcTokens[i];
            }
        }
    }

    function _isTokenIDExist(bytes32 tokenID) internal view returns(bool) {
        for (uint256 i = 0; i < _allTokenIDs.length; ++i) {
            if (_allTokenIDs[i] == tokenID) {
                return true;
            }
        }
        return false;
    }

    function setTokenConfig(
        bytes32 tokenID,
        uint256 chainID,
        address tokenAddress,
        uint8 tokenDecimals,
        uint256 maxSwap,
        uint256 minSwap,
        uint256 swapFee,
        uint256 maxSwapFee,
        uint256 minSwapFee,
        bool hasUnderlying,
        bool isUnderlying
    ) public returns (bool) {
        require(hasRole(BRIDGEMANAGER_ROLE, msg.sender));
        Token memory tokenToAdd;
        tokenToAdd.tokenAddress = tokenAddress;
        tokenToAdd.tokenDecimals = tokenDecimals;
        tokenToAdd.maxSwap = maxSwap;
        tokenToAdd.minSwap = minSwap;
        tokenToAdd.swapFee = swapFee;
        tokenToAdd.maxSwapFee = maxSwapFee;
        tokenToAdd.minSwapFee = minSwapFee;
        tokenToAdd.hasUnderlying = hasUnderlying;
        tokenToAdd.isUnderlying = isUnderlying;

        _tokens[tokenID][chainID] = tokenToAdd;
         if (!_isTokenIDExist(tokenID)) {
            _allTokenIDs.push(tokenID);
        }

        Token[] memory _mcTokens = _allTokens[tokenID];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].chainId == chainID) {
                address oldToken = _mcTokens[i].tokenAddress;
                if (tokenToAdd.tokenAddress != oldToken) {
                _mcTokens[i].tokenAddress = tokenToAdd.tokenAddress ;
                _tokenIDMap[chainID][oldToken] = keccak256('');
                _tokenIDMap[chainID][tokenToAdd.tokenAddress] = tokenID;
                }
            }
        }

        _tokenIDMap[chainID][tokenToAdd.tokenAddress] = tokenID;
        return true;
    }
}