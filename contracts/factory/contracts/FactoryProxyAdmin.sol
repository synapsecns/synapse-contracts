// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/ProxyAdmin.sol";

/**
 * @notice This contract is needed for factory deployments of proxy admins,
 * as basic {ProxyAdmin} contract does not support deploying and transferring ownership.
 */
contract FactoryProxyAdmin is ProxyAdmin {
    constructor(address owner_) public {
        transferOwnership(owner_);
    }
}
