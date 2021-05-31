// SPDX-License-Identifier: MIT


pragma solidity >=0.6.0 <0.8.0;

interface ISynapseERC20 {    
    function initialize(
        string memory _name, string memory _symbol, uint8 _decimals,  uint256 _underlyingChainId, address _underlyingTokenAddress,  address owner) external; 
}

