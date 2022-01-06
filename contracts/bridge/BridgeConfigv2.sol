// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {BridgeConfig} from './BridgeConfig.sol';
import {AccessControl} from './BridgeConfig.sol';
import {SafeMath} from './BridgeConfig.sol';
import {PoolConfig} from './PoolConfig.sol';

/**
 * @title BridgeConfigV2 contract
 * @notice This token is used for configuring different tokens on the bridge and mapping them across chains.
 * It wraps bridge config for data storage
**/

contract BridgeConfigV2 is AccessControl {
    using SafeMath for uint256;
    bytes32 public constant BRIDGEMANAGER_ROLE = keccak256('BRIDGEMANAGER_ROLE');
    BridgeConfig public BRIDGECONFIG_V1;
    PoolConfig public POOLCONFIG_V1;
    mapping(uint256 => uint256) private _maxGasPrice; // key is tokenID,chainID

    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setBridgeConfig(BridgeConfig bridgeconfig, PoolConfig poolconfig) public {
        require(hasRole(BRIDGEMANAGER_ROLE, msg.sender));
        BRIDGECONFIG_V1 = bridgeconfig;
        POOLCONFIG_V1 = poolconfig;
    }

    /**
     * @notice Returns a list of all existing token IDs converted to strings
     */
    function getAllTokenIDs() public view returns (string[] memory result) {
        return BRIDGECONFIG_V1.getAllTokenIDs();
    }

    /**
     * @notice Returns the token ID (string) of the cross-chain token inputted
     * @param tokenAddress address of token to get ID for
     * @param chainID chainID of which to get token ID for
     */
    function getTokenID(address tokenAddress, uint256 chainID) public view returns (string memory)  {
        return BRIDGECONFIG_V1.getTokenID(tokenAddress, chainID);
    }

    /**
     * @notice Returns the full token config struct
     * @param tokenID String input of the token ID for the token
     * @param chainID Chain ID of which token address + config to get
     */
    function getToken(string calldata tokenID, uint256 chainID) public view returns (BridgeConfig.Token memory token) {
        return BRIDGECONFIG_V1.getToken(tokenID, chainID);
    }

    /**
     * @notice Returns token config struct, given an address and chainID
     * @param tokenAddress Matches the token ID by using a combo of address + chain ID
     * @param chainID Chain ID of which token to get config for
     */
    function getToken(address tokenAddress, uint256 chainID) public view returns (BridgeConfig.Token memory token) {
        return BRIDGECONFIG_V1.getToken(tokenAddress, chainID);
    }

    /**
     * @notice Returns true if the token has an underlying token -- meaning the token is deposited into the bridge
     * @param tokenID String to check if it is a withdraw/underlying token
     */
    function hasUnderlyingToken(string calldata tokenID) public view returns (bool) {
        return BRIDGECONFIG_V1.hasUnderlyingToken(tokenID);
    }

    /**
     * @notice Returns which token is the underlying token to withdraw
     * @param tokenID string token ID
     */
    function getUnderlyingToken(string calldata tokenID) public view returns (BridgeConfig.Token memory token) {
        return BRIDGECONFIG_V1.getUnderlyingToken(tokenID);
    }

    /**
     @notice Public function returning if token ID exists given a string
     */
    function isTokenIDExist(string calldata tokenID) public view returns (bool) {
        return BRIDGECONFIG_V1.isTokenIDExist(tokenID);
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
        return BRIDGECONFIG_V1.calculateSwapFee(tokenAddress, chainID, amount);
    }

    function getPoolConfig(address tokenAddress, uint256 chainID) external view
    returns (PoolConfig.Pool memory) {
        return POOLCONFIG_V1.getPoolConfig(tokenAddress, chainID);
    }

    /**
    * @notice sets the max gas price for a chain
    */
    function setMaxGasPrice(uint256 chainID, uint256 maxPrice) public {
        require(hasRole(BRIDGEMANAGER_ROLE, msg.sender));
        _maxGasPrice[chainID] = maxPrice;
    }

    /**
    * @notice gets the max gas price for a chain
    */
    function getMaxGasPrice(uint256 chainID) public view returns (uint256){
        return _maxGasPrice[chainID];
    }
}