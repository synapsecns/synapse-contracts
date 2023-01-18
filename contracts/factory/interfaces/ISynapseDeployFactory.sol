// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.6.12;

interface ISynapseDeployFactory {
    function deploy(bytes32 salt, bytes memory creationCode) external payable returns (address deployed);

    function deployClone(
        bytes32 salt,
        address master,
        bytes calldata initData
    ) external returns (address deployed);

    function predictAddress(address deployer, bytes32 salt) external view returns (address deployed);

    function predictCloneAddress(
        address deployer,
        bytes32 salt,
        address master
    ) external view returns (address deployed);
}
