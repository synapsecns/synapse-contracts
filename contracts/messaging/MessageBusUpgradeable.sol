// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;
import "./MessageBusSenderUpgradeable.sol";
import "./MessageBusReceiverUpgradeable.sol";

contract MessageBusUpgradeable is
    MessageBusSenderUpgradeable,
    MessageBusReceiverUpgradeable
{
    function initialize(address _gasFeePricing, address _authVerifier)
        external
        initializer
    {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __MessageBusSender_init_unchained(_gasFeePricing);
        __MessageBusReceiver_init_unchained(_authVerifier);
    }

    // PAUSABLE FUNCTIONS ***/
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
