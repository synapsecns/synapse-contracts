// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./MessageBusUpgradeable.sol";

contract HarmonyMessageBusUpgradeable is MessageBusUpgradeable {
    uint256 private constant CHAIN_ID = 1666600000;

    function _chainId() internal pure override returns (uint256) {
        return CHAIN_ID;
    }
}
