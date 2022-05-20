// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable-4.5.0/proxy/utils/Initializable.sol";

abstract contract ContextChainIdUpgradeable is Initializable {
    function __ContextChainId_init() internal onlyInitializing {}

    function __ContextChainId_init_unchained() internal onlyInitializing {}

    function _chainId() internal view virtual returns (uint256) {
        return block.chainid;
    }

    /**
     * This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
