// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

/**
 * @title BridgeConfig contract
 * @notice This token is used for configuring different tokens on the bridge and mapping them across chains.
**/

contract BridgeConfig is AccessControl {
    using SafeMath for uint256;
    bytes32 public constant BRIDGEMANAGER_ROLE = keccak256('BRIDGEMANAGER_ROLE');
    bytes32[] private _allTokenIDs;
    mapping(bytes32 => Token[]) private _allTokens; // key is tokenID
    mapping(uint256 => mapping(address => bytes32)) private _tokenIDMap; // key is chainID,tokenAddress
    mapping(bytes32 => mapping(uint256 => Token)) private _tokens; // key is tokenID,chainID

    // the denominator used to calculate fees. For example, an
    // LP fee might be something like tradeAmount.mul(fee).div(FEE_DENOMINATOR)
    uint256 private constant FEE_DENOMINATOR = 10**10;

    // this struct must be initialized using setTokenConfig for each token that directly interacts with the bridge
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
    }

    /**
     * @notice Returns a list of all existing token IDs converted to strings
     */
    function getAllTokenIDs() public view returns (string[] memory result) {
        uint256 length = _allTokenIDs.length;
        result = new string[](length);
        for (uint256 i = 0; i < length; ++i) {
            result[i] = bytes32ToString(_allTokenIDs[i]);
        }
    }

    /**
     * @notice Returns the token ID (string) of the cross-chain token inputted
     * @param tokenAddress address of token to get ID for
     * @param chainID chainID of which to get token ID for
     */
    function getTokenID(address tokenAddress, uint256 chainID) public view returns (string memory)  {
        return bytes32ToString(_tokenIDMap[chainID][tokenAddress]);
    }

    /**
     * @notice Returns the full token config struct 
     * @param tokenID String input of the token ID for the token
     * @param chainID Chain ID of which token address + config to get
     */
    function getToken(string calldata tokenID, uint256 chainID) public view returns (Token memory token) {
        return _tokens[stringToBytes32(tokenID)][chainID];
    }

    /**
     * @notice Returns token config struct, given an address and chainID
     * @param tokenAddress Matches the token ID by using a combo of address + chain ID
     * @param chainID Chain ID of which token to get config for
     */
    function getToken(address tokenAddress, uint256 chainID) public view returns (Token memory token) {
        string memory tokenID = getTokenID(tokenAddress, chainID);
        return _tokens[stringToBytes32(tokenID)][chainID];
    }

    /**
     * @notice Returns true if the token has an underlying token -- meaning the token is deposited into the bridge
     * @param tokenID String to check if it is a withdraw/underlying token
     */
    function hasUnderlyingToken(string calldata tokenID) public view returns (bool) {
        bytes32 bytesTokenID = stringToBytes32(tokenID);
        Token[] memory _mcTokens = _allTokens[bytesTokenID];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].hasUnderlying) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Returns which token is the underlying token to withdraw
     * @param tokenID string token ID
     */
    function getUnderlyingToken(string calldata tokenID) public view returns (Token memory token) {
        bytes32 bytesTokenID = stringToBytes32(tokenID);
        Token[] memory _mcTokens = _allTokens[bytesTokenID];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].isUnderlying) {
                return _mcTokens[i];
            }
        }
    }
    
    /**
     @notice Public function returning if token ID exists given a string
     */
    function isTokenIDExist(string calldata tokenID) public view returns (bool) {
        return _isTokenIDExist(stringToBytes32(tokenID));
    }

    /**
     @notice Internal function returning if token ID exists given bytes32 version of the ID
     */
    function _isTokenIDExist(bytes32 tokenID) internal view returns(bool) {
        for (uint256 i = 0; i < _allTokenIDs.length; ++i) {
            if (_allTokenIDs[i] == tokenID) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Internal function which handles logic of setting token ID and dealing with mappings
     * @param tokenID bytes32 version of ID
     * @param chainID which chain to set the token config for
     * @param tokenToAdd Token object to set the mapping to
     */
    function _setTokenConfig(bytes32 tokenID, uint256 chainID, Token memory tokenToAdd) internal returns(bool) {
        _tokens[tokenID][chainID] = tokenToAdd;
         if (!_isTokenIDExist(tokenID)) {
            _allTokenIDs.push(tokenID);
        }

        Token[] storage _mcTokens = _allTokens[tokenID];
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
        _mcTokens.push(tokenToAdd);
        _tokenIDMap[chainID][tokenToAdd.tokenAddress] = tokenID;
        return true;
    }

    /**
     * @notice Main write function of this contract - Handles creating the struct and passing it to the internal logic function
     * @param tokenID string ID to set the token config object form
     * @param chainID chain ID to use for the token config object
     * @param tokenAddress token address of the token on the given chain
     * @param tokenDecimals decimals of token 
     * @param maxSwap maximum amount of token allowed to be transferred at once - in native token decimals
     * @param minSwap minimum amount of token needed to be transferred at once - in native token decimals
     * @param swapFee percent based swap fee -- 10e6 == 10bps
     * @param maxSwapFee max swap fee to be charged - in native token decimals
     * @param minSwapFee min swap fee to be charged - in native token decimals - especially useful for mainnet ETH
     * @param hasUnderlying bool which represents whether this is a global mint token or one to withdraw()
     * @param isUnderlying bool which represents if this token is the one to withdraw on the given chain
     */
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

        return _setTokenConfig(stringToBytes32(tokenID), chainID, tokenToAdd);
    }

    /** 
     * @notice Calculates bridge swap fee based on the destination chain's token transfer.
     * @dev This means the fee should be calculated based on the chain that the nodes emit a tx on
     * @param tokenAddress address of the destination token to query token config for
     * @param chainID destination chain ID to query the token config for
     * @param amount in native token decimals
     * @return Fee calculated in token decimals
     */
    function calculateSwapFee(
        address tokenAddress,
        uint256 chainID,
        uint256 amount
    ) external view returns (uint256) {
        Token memory token = getToken(tokenAddress, chainID);
        uint256 calculatedSwapFee = amount.mul(token.swapFee).div(FEE_DENOMINATOR);
        if (calculatedSwapFee > token.minSwapFee && calculatedSwapFee < token.maxSwapFee) {
            return calculatedSwapFee;
        } else if (calculatedSwapFee > token.maxSwapFee) {
            return token.maxSwapFee;
        } else {
            return token.minSwapFee;
        }
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