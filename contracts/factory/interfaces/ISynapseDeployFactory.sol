// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.6.12;

interface ISynapseDeployFactory {
    /**
     * @notice Deploys a contract using CREATE3.
     * @dev The provided salt is hashed together with msg.sender to generate the final salt,
     * which would be unique for every deployer. Every deployer will have their own unique set of
     * potential deployment addresses, as long there are no collisions in keccak256.
     * The latter is believed to be impossible to find.
     * The deployment address depends only on the deployer address and the salt,
     * so make sure not to reuse the same salt for different contracts on different chains.
     * @param salt          Salt for determining the deployed contract address
     * @param creationCode  Creation code of the contract to deploy (contract bytecode + abi-encoded constructor args)
     * @return deployed     Address of the deployed contract
     */
    function deploy(bytes32 salt, bytes memory creationCode) external payable returns (address deployed);

    /**
     * @notice Deploys a minimal proxy for the given master implementation.
     * @dev The provided salt is hashed together with msg.sender to generate the final salt,
     * which would be unique for every deployer. Every deployer will have their own unique set of
     * potential deployment addresses, as long there are no collisions in keccak256.
     * The latter is believed to be impossible to find.
     * The deployment address depends only on the deployer address and the salt,
     * so make sure not to reuse the same salt for different contracts on different chains.
     * @param salt      Salt for determining the deployed contract address
     * @param master    Master implementation that will be used for the deployed minimal proxy
     * @param initData  Calldata for initializer call (ignored if empty)
     * @return deployed Address of the deployed minimal proxy
     */
    function deployClone(
        bytes32 salt,
        address master,
        bytes calldata initData
    ) external returns (address deployed);

    /**
     * @notice Predicts the address of a deployed contract.
     * @dev The provided salt is hashed together with msg.sender to generate the final salt,
     * which would be unique for every deployer.
     * The deployment address doesn't depend on the creation code - make sure not to reuse the salt for
     * different contracts on different chains.
     * @param deployer  Deployer account that will call deploy()
     * @param salt      Salt for determining the deployed contract address
     * @return deployed Address of the contract that will be deployed
     */
    function predictAddress(address deployer, bytes32 salt) external view returns (address deployed);

    /**
     * @notice Predicts the address of a minimal proxy (Clone).
     * @dev The provided salt is hashed together with msg.sender to generate the final salt,
     * which would be unique for every deployer.
     * The deployment address doesn't depend on the creation code - make sure not to reuse the salt for
     * different contracts on different chains.
     * @param deployer  Deployer account that will call deployClone()
     * @param salt      Salt for determining the deployed contract address
     * @param master    Master implementation that will be used for the deployed minimal proxy
     * @return deployed Address of the minimal proxy that will be deployed
     */
    function predictCloneAddress(
        address deployer,
        bytes32 salt,
        address master
    ) external view returns (address deployed);
}
