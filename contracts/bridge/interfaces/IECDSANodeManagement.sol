// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

/**
 * @title IECDSANodeManagement interface
 * @notice Interface for the ECDSA node management interface.
 * @dev implement this interface to develop a a factory-patterned ECDSA node management contract
 **/
interface IECDSANodeManagement {
    function initialize(
        address _owner,
        address[] memory _members,
        uint256 _honestThreshold
    ) external;
}
