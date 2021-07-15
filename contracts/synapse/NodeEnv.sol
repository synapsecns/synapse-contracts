// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/access/AccessControl.sol';
import "./utils/EnumerableStringMap.sol";

/**
 * @title NodeEnv contract
 * @author Synapse Authors
 * @notice This contract implements a key-value store for storing variables on which synapse nodes must coordinate
 * methods are purposely arbitrary to allow these fields to be defined in synapse improvement proposals.
 * @notice This token is used for configuring different tokens on the bridge and mapping them across chains.
**/
contract NodeEnv is AccessControl {
    using EnumerableStringMap for EnumerableStringMap.StringToStringMap;
    // BRIDGEMANAGER_ROLE owns the bridge. They are the only user that can call setters on this contract
    bytes32 public constant BRIDGEMANAGER_ROLE = keccak256('BRIDGEMANAGER_ROLE');
    // _config stores the config
    EnumerableStringMap.StringToStringMap private _config; // key is tokenAddress,chainID

    // ConfigUpdate is emitted when the config is updated by the user
    event ConfigUpdate(
        string key
    );

    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(BRIDGEMANAGER_ROLE, msg.sender);
    }

    /**
    * @notice get the length of the config
    *
    * @dev this is useful for enumerating through all keys in the env
    */
    function keyCount()
    public
    view
    returns (uint256){
        return _config.length();
    }

    /**
    * @notice gets the key/value pair by it's index
    *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function keyValueByIndex(uint256 index) public view returns(string memory, string memory){
        return _config.at(index);
    }

    /**
    * @notice gets the value associated with the key
    */
    function get(string calldata _key) public view returns(string memory){
        string memory key = _key;
        return _config.get(key);
    }

    /**
    * @notice sets the key
    *
    * @dev caller must have bridge manager role
    */
    function set(string calldata _key, string calldata _value) public returns(bool) {
        require(
            hasRole(BRIDGEMANAGER_ROLE, msg.sender),
            'Caller is not Bridge Manager'
        );
        string memory key = _key;
        string memory value = _value;

        return _config.set(key, value);
    }
}