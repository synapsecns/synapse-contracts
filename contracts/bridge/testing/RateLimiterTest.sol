// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import "../interfaces/IRateLimiter.sol";
import "@openzeppelin/contracts-4.3.1-upgradeable/proxy/utils/Initializable.sol";

/// @title RateLimiterTest
// @dev this contract is used to test RateLimiter's checkAndUpdateAllowance method's return value
// because web3 libraries don't provide an interface for retrieving boolean values from a non-view function
// we store the return value here for retrieval later.

contract RateLimiterTest is Initializable {
    /*** STATE ***/

    string public constant NAME = "Rate Limiter Test";
    string public constant VERSION = "0.1.0";

    // @dev stores the return value of checkAndUpdateAllowance
    bool checkAndUpdateReturn;
    // @dev whether or not a value has been stored at least once. Used to revert if developer calls
    // getLastUpdateValue without a store first
    bool stored;

    // the rate limiter contract
    IRateLimiter rateLimiter;

    function initialize(IRateLimiter _rateLimiter) external initializer {
        rateLimiter = _rateLimiter;
    }

    // @dev stores the last value of check and update allowance
    function storeCheckAndUpdateAllowance(address token, uint256 amount) external {
        stored = true;
        checkAndUpdateReturn = rateLimiter.checkAndUpdateAllowance(token, amount);
    }

    // @dev gets the most recent value returned by storeCheckAndUpdateAllowance
    // reverts if no value stored yet
    function getLastUpdateValue() external view returns (bool){
        require(stored, "no update value has been stored yet");
        return checkAndUpdateReturn;
    }
}
