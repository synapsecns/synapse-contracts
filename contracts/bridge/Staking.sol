// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";

contract SynStaking {
    using BoringERC20 for IERC20;

    /// @notice Address of SYNAPSE contract.
    IERC20 public immutable SYNAPSE;

    event Bond(address indexed user, uint256 indexed amount, uint256 amount, string indexed to);

    function stake(uint256 _amount, string delegatee) external {
        // transfer the token from the user to the staking contract
        synapse.safeTransferFrom(msg.sender, address(this), _amount);
        // burn the synapse in the contract
        synapse.burn(_amount);
        emit Bond(msg.sender, _amount, delegatee);
    }
}
