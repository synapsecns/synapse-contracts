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

    function getAllTokenIDs() public view returns (string[] memory result) {
        uint256 length = _allTokenIDs.length;
        result = new string[](length);
        for (uint256 i = 0; i < length; ++i) {
            result[i] = bytes32ToString(_allTokenIDs[i]);
        }
    }

    function getTokenID(uint256 chainID, address tokenAddress) public view returns (string memory)  {
        return bytes32ToString(_tokenIDMap[chainID][tokenAddress]);
    }

    function getToken(string calldata tokenID, uint256 chainID) public view returns (Token memory token) {
        return _tokens[stringToBytes32(tokenID)][chainID];
    }

    function getUnderlyingToken(string calldata tokenID) public view returns (Token memory token) {
        bytes32 bytesTokenID = stringToBytes32(tokenID);
        Token[] storage _mcTokens = _allTokens[bytesTokenID];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].isUnderlying == true) {
                return _mcTokens[i];
            }
        }
    }
    
    function isTokenIDExist(string calldata tokenID) public view returns (bool) {
        return _isTokenIDExist(stringToBytes32(tokenID));
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
        string calldata tokenID,
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
        bytes32 bytesTokenID = stringToBytes32(tokenID);
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

        _tokens[bytesTokenID][chainID] = tokenToAdd;
         if (!_isTokenIDExist(bytesTokenID)) {
            _allTokenIDs.push(bytesTokenID);
        }

        Token[] memory _mcTokens = _allTokens[bytesTokenID];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].chainId == chainID) {
                address oldToken = _mcTokens[i].tokenAddress;
                if (tokenToAdd.tokenAddress != oldToken) {
                _mcTokens[i].tokenAddress = tokenToAdd.tokenAddress ;
                _tokenIDMap[chainID][oldToken] = keccak256('');
                _tokenIDMap[chainID][tokenToAdd.tokenAddress] = bytesTokenID;
                }
            }
        }

        _tokenIDMap[chainID][tokenToAdd.tokenAddress] = bytesTokenID;
        return true;
    }
    
    function stringToBytes32(string memory str) internal pure returns (bytes32 result) {
        assembly {
            result := mload(add(str, 32))
        }
    }

    function bytes32ToString(bytes32 data) internal pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && data[i] != 0) {
            ++i;
        }
        bytes memory bs = new bytes(i);
        for (uint8 j = 0; j < i; ++j) {
            bs[j] = data[j];
        }
        return string(bs);
    }
}