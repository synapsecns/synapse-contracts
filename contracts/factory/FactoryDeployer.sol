// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import {ISynapseDeployFactory} from "./interfaces/ISynapseDeployFactory.sol";

/// @notice Auxiliary contract to be used in scripts/tests for factory deployments.
/// Contract is abstract, as it is not supposed to be deployed.
abstract contract FactoryDeployer {
    ISynapseDeployFactory public factory;

    function deployContract(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory initData
    ) public returns (address deployed) {
        return factory.deploy(salt, creationCode, initData);
    }

    function deployCloneContract(
        bytes32 salt,
        address master,
        bytes memory initData
    ) public returns (address deployed) {
        // Here we construct the bytecode for a minimal proxy manually, see
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/Clones.sol
        // We don't do any fancy schmancy assembly here, as this contract is not supposed to be used
        // outside of scripting and/or testing, so we don't care about "gas consumption".
        bytes memory creationCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            master,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        return factory.deploy(salt, creationCode, initData);
    }

    function setupFactory(ISynapseDeployFactory _factory) public {
        factory = _factory;
    }
}
