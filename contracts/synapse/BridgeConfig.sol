// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract BridgeConfig is AccessControl {
    bytes32 public constant BRIDGEMANAGER_ROLE = keccak256("BRIDGEMANAGER_ROLE");
    bytes32[] private _allTokenIDs;
    mapping (bytes32 => MultichainToken[]) private _allMultichainTokens; // key is tokenID
    mapping (uint256 => mapping(address => bytes32)) private _tokenIDMap; // key is chainID,tokenAddress
    mapping (bytes32 => mapping(uint256 => TokenConfig)) private _tokenConfig; // key is tokenID,chainID


    modifier checkTokenConfig(TokenConfig memory config) {
        require(config.maxSwap > 0, "zero MaximumSwap");
        require(config.minSwap > 0, "zero MinimumSwap");
        require(config.maxSwap >= config.minSwap, "MaximumSwap < MinimumSwap");
        require(config.maxSwapFee >= config.minSwapFee, "MaximumSwapFee < MinimumSwapFee");
        require(config.maxSwapFee >= config.minSwapFee, "MinimumSwap < MinimumSwapFee");
        _;
    }

    struct TokenConfig {
        uint256 chainId;
        address tokenAddress;
        uint8 tokenDecimals;
        uint256 maxSwap;
        uint256 minSwap;
        uint256 swapFee;
        uint256 maxSwapFee;
        uint256 minSwapFee;
    }

    struct MultichainToken {
        uint256 chainId;
        address tokenAddress;
    }

    function getAllTokenIDs() external view returns (string[] memory result) {
        uint256 length = _allTokenIDs.length;
        result = new string[](length);
        for (uint256 i = 0; i < length; ++i) {
            result[i] = bytes32ToString(_allTokenIDs[i]);
        }
    }


    function getTokenID(uint256 chainID, address tokenAddress) external view returns (string memory) {
        return bytes32ToString(_tokenIDMap[chainID][tokenAddress]);
    }

    function getMultichainToken(string calldata tokenID, uint256 chainID) public view returns (address) {
        MultichainToken[] storage _mcTokens = _allMultichainTokens[stringToBytes32(tokenID)];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].chainId == chainID) {
                return _mcTokens[i].tokenAddress;
            }
        }
        return address(0);
    }

    function _isTokenIDExist(bytes32 tokenID) internal view returns (bool) {
        for (uint256 i = 0; i < _allTokenIDs.length; ++i) {
            if (_allTokenIDs[i] == tokenID) {
                return true;
            }
        }
        return false;
    }

    function isTokenIDExist(string calldata tokenID) public view returns (bool) {
        return _isTokenIDExist(stringToBytes32(tokenID));
    }

    function getTokenConfig(string calldata tokenID, uint256 chainID) external view returns (TokenConfig memory) {
        return _tokenConfig[stringToBytes32(tokenID)][chainID];
    }

    function _setTokenConfig(bytes32 tokenID, uint256 chainID, TokenConfig memory config) internal checkTokenConfig(config) returns (bool) {
        require(tokenID != bytes32(0), "empty tokenID");
        require(chainID > 0, "zero chainID");
        
        _tokenConfig[tokenID][chainID] = config;
        if (!_isTokenIDExist(tokenID)) {
            _allTokenIDs.push(tokenID);
        }
        _setMultichainToken(tokenID, chainID, config.tokenAddress);

        return true;
    }

    function setTokenConfig(string calldata tokenID, uint256 chainID, TokenConfig calldata config) external returns (bool) {
        require(hasRole(BRIDGEMANAGER_ROLE, msg.sender));
        return _setTokenConfig(stringToBytes32(tokenID), chainID, config);
    }


    function _setMultichainToken(bytes32 tokenID, uint256 chainID, address token) internal {
        require(tokenID != bytes32(0), "empty tokenID");
        require(chainID > 0, "zero chainID");
        MultichainToken[] storage _mcTokens = _allMultichainTokens[tokenID];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].chainId == chainID) {
                address oldToken = _mcTokens[i].tokenAddress;
                if (token != oldToken) {
                    _mcTokens[i].tokenAddress = token;
                    _tokenIDMap[chainID][oldToken] = bytes32(0);
                    _tokenIDMap[chainID][token] = tokenID;
                }
                return;
            }
        }
        _mcTokens.push(MultichainToken(chainID, token));
        _tokenIDMap[chainID][token] = tokenID;
    }

  
    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(BRIDGEMANAGER_ROLE, msg.sender);
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