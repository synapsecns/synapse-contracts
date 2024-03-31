// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISynapseCreate3Factory {
    /// @notice Deploys a contract EIP-3171 style with an optional initialization call.
    /// The deployed contract address depends only on the provided salt and the address of the factory contract,
    /// and does NOT depend on the creation code or the data for the initialization call.
    /// - In order to prevent unauthorized deploys, the first 20 bytes of the salt
    /// must be equal to the deployer's address. The remaining 12 bytes could be arbitrary, leaving 2**96 possible
    /// addresses for each deployer.
    /// - Function is payable and all value is forwarded to the contract constructor.
    /// - If `initData` is non-empty, it will be used to perform an initialization call to the deployed contract.
    /// This could be used to call the contract initializer atomically with the deployment to prevent front-running.
    /// @dev The execution will be reverted in either of the following cases:
    /// - First 20 bytes of the salt are not equal to the deployer's address.
    /// - Salt has been used before (meaning the address associated with the salt is already occupied).
    /// - Contract creation fails, in which case a generic error is thrown, regardless of the reason.
    /// - Initialization call fails, in which case the error is bubbled up. A generic error will be thrown, if
    /// initialization call reverts silently.
    /// @param salt         Salt for the contract deployment. Must contain the deployer's address as the first 20 bytes.
    /// @param creationCode Creation code of the contract to deploy. This is usually the
    ///                     bytecode of the contract, followed by the ABI-encoded constructor arguments.
    /// @param initData     Data to be used for an initialization call to the deployed contract.
    ///                     Empty, if no initialization call is needed.
    /// @return deployedAt  Address of the deployed contract.
    function safeCreate3(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory initData
    ) external payable returns (address deployedAt);

    /// @notice Predicts the address of the final contract deployed using `safeCreate3`.
    /// Note: accepts any salt, but for deployment to succeed, the first 20 bytes of the salt
    /// must be equal to the deployer's address.
    /// @param salt     Salt for the contract deployment. Must contain the deployer's address as the first 20 bytes.
    /// @return Address of the contract deployed using `safeCreate3`.
    function predictAddress(bytes32 salt) external view returns (address);
}
