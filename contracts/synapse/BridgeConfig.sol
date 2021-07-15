// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

/**
 * @title BridgeConfig contract
 * @notice This token is used for configuring different tokens on the bridge and mapping them across chains.
**/
contract BridgeConfig is AccessControl {
  bytes32 public constant BRIDGEMANAGER_ROLE = keccak256('BRIDGEMANAGER_ROLE');
  address[] private _allTokenIDs;
  using SafeMath for uint256;
  mapping(address => MultichainToken[]) private _allMultichainTokens; // key is tokenID
  mapping(uint256 => mapping(address => address)) private _tokenIDMap; // key is chainID,tokenAddress
  mapping(address => mapping(uint256 => TokenConfig)) private _tokenConfig; // key is tokenID,chainID

  // the denominator used to calculate fees. For example, an
  // LP fee might be something like tradeAmount.mul(fee).div(FEE_DENOMINATOR)
  uint256 private constant FEE_DENOMINATOR = 10**10;

  modifier checkTokenConfig(TokenConfig memory config) {
    require(config.maxSwap > 0, 'zero MaximumSwap');
    require(config.minSwap > 0, 'zero MinimumSwap');
    require(config.maxSwap >= config.minSwap, 'MaximumSwap < MinimumSwap');
    require(
      config.maxSwapFee >= config.minSwapFee,
      'MaximumSwapFee < MinimumSwapFee'
    );
    require(
      config.maxSwapFee >= config.minSwapFee,
      'MinimumSwap < MinimumSwapFee'
    );
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

  function getAllTokenIDs() external view returns (address[] memory result) {
    uint256 length = _allTokenIDs.length;
    result = new address[](length);
    for (uint256 i = 0; i < length; ++i) {
      result[i] = _allTokenIDs[i];
    }
  }

  function getTokenID(uint256 chainID, address tokenAddress)
    public
    view
    returns (address)
  {
    return _tokenIDMap[chainID][tokenAddress];
  }

  function getMultichainToken(address tokenID, uint256 chainID)
    public
    view
    returns (address)
  {
    MultichainToken[] storage _mcTokens = _allMultichainTokens[tokenID];
    for (uint256 i = 0; i < _mcTokens.length; ++i) {
      if (_mcTokens[i].chainId == chainID) {
        return _mcTokens[i].tokenAddress;
      }
    }
    return address(0);
  }

  function _isTokenIDExist(address tokenID) internal view returns (bool) {
    for (uint256 i = 0; i < _allTokenIDs.length; ++i) {
      if (_allTokenIDs[i] == tokenID) {
        return true;
      }
    }
    return false;
  }

  function isTokenIDExist(address tokenID) public view returns (bool) {
    return _isTokenIDExist(tokenID);
  }

  /**
   * @notice Gets the token config for a given token
   * @dev you can pass 0 for origin chain to get the token address on the destination chain
   */
  function getTokenConfig(
    address originToken,
    uint256 originChainID,
    uint256 destChainId
  ) public view returns (TokenConfig memory) {
    address tokenID;
    if (getTokenID(originChainID, originToken) != address(0)) {
      tokenID = getTokenID(originChainID, originToken);
    } else {
      tokenID = originToken;
    }
    return _tokenConfig[tokenID][destChainId];
  }

  function _setTokenConfig(
    address tokenID,
    uint256 chainID,
    TokenConfig memory config
  ) internal checkTokenConfig(config) returns (bool) {
    _tokenConfig[tokenID][chainID] = config;
    if (!_isTokenIDExist(tokenID)) {
      _allTokenIDs.push(tokenID);
    }
    _setMultichainToken(tokenID, chainID, config.tokenAddress);

    return true;
  }

  function setTokenConfig(
    address tokenID,
    uint256 chainID,
    address tokenAddress,
    uint8 tokenDecimals,
    uint256 maxSwap,
    uint256 minSwap,
    uint256 swapFee,
    uint256 maxSwapFee,
    uint256 minSwapFee
  ) external returns (bool) {
    TokenConfig memory config;
    config.tokenAddress = tokenAddress;
    config.tokenDecimals = tokenDecimals;
    config.maxSwap = maxSwap;
    config.minSwap = minSwap;
    config.swapFee = swapFee;
    config.maxSwapFee = maxSwapFee;
    config.minSwapFee = minSwapFee;
    require(hasRole(BRIDGEMANAGER_ROLE, msg.sender));
    return _setTokenConfig(tokenID, chainID, config);
  }

  function _setMultichainToken(
    address tokenID,
    uint256 chainID,
    address token
  ) internal {
    MultichainToken[] storage _mcTokens = _allMultichainTokens[tokenID];
    for (uint256 i = 0; i < _mcTokens.length; ++i) {
      if (_mcTokens[i].chainId == chainID) {
        address oldToken = _mcTokens[i].tokenAddress;
        if (token != oldToken) {
          _mcTokens[i].tokenAddress = token;
          _tokenIDMap[chainID][oldToken] = address(0);
          _tokenIDMap[chainID][token] = tokenID;
        }
        return;
      }
    }
    _mcTokens.push(MultichainToken(chainID, token));
    _tokenIDMap[chainID][token] = tokenID;
  }

  function calculateSwapFee(
    uint256 chainId,
    address tokenAddress,
    uint256 amount
  ) external view returns (uint256) {
    address tokenId = getTokenID(chainId, tokenAddress);
    TokenConfig memory config = getTokenConfig(tokenId, chainId, chainId);
    uint256 calculatedSwapFee = amount.mul(config.swapFee).div(FEE_DENOMINATOR);
    if (calculatedSwapFee > config.minSwapFee) {
      return calculatedSwapFee;
    } else {
      return config.minSwapFee;
    }
  }

  constructor() public {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(BRIDGEMANAGER_ROLE, msg.sender);
  }
}
