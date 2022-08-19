// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./MessageBusSenderUpgradeable.sol";
import "./MessageBusReceiverUpgradeable.sol";

contract HarmonyMessageBusUpgradeable is MessageBusSenderUpgradeable, MessageBusReceiverUpgradeable {
    uint256 private constant CHAIN_ID = 1666600000;

    function initialize(address _gasFeePricing, address _authVerifier) external initializer {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __MessageBusSender_init_unchained(_gasFeePricing);
        __MessageBusReceiver_init_unchained(_authVerifier);
    }

    function _chainId() internal pure override returns (uint256) {
        return CHAIN_ID;
    }

    // PAUSABLE FUNCTIONS ***/
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
