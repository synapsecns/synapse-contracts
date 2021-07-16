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
    bytes32 private _allTokenIDs;
    mapping(bytes32 => Token) private _allTokens; // key is tokenID
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

}