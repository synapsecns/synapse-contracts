// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

contract SynStaking {

    constructor(ERC20Burnable _synapse) public {
        SYNAPSE = _synapse;
    }

    /// @notice Address of SYNAPSE contract.
    ERC20Burnable public immutable SYNAPSE;

    event Bond(address indexed user, uint256 indexed amount,  string indexed to);

    function stake(uint256 _amount, string memory delegatee) external {
        require(_amount != 0);
        // transfer the token from the user to the staking contract
        SYNAPSE.burnFrom(msg.sender, _amount);
        // burn the synapse in the contract
        emit Bond(msg.sender, _amount, delegatee);
    }
}
