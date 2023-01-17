// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {CREATE3Factory} from "create3-factory/CREATE3Factory.sol";

contract SynapseDeployFactory is CREATE3Factory {
    function deployClone(
        bytes32 salt,
        address master,
        bytes calldata initData
    ) external {}

    function deployTransparentUpgradeableProxy(
        bytes32 salt,
        address logic,
        address admin,
        bytes calldata data
    ) external {}

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL LOGIC                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _deployerSalt(address deployer, bytes32 salt) internal pure returns (bytes32) {
        // hash salt with the deployer address to give each deployer its own namespace
        return keccak256(abi.encode(deployer, salt));
    }
}
