// SPDX-License-Identifier: MIT


pragma solidity >=0.6.0 <0.8.0;

interface IECDSANodeManagement {    
    function initialize(
        address _owner,
        address[] memory _members,
        uint256 _honestThreshold) external;
}

