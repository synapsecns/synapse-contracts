// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IntegrationTest {
    /// @notice Returns the name of the chain where the integration test is running.
    function chainName() external view returns (string memory);

    /// @notice Returns the name of the contract to be tested.
    /// @dev The integration test will be skipped if the contract has already been deployed.
    function contractName() external view returns (string memory);

    /// @notice Whether to run the integration test, if the tested contract is already deployed.
    /// @dev This is set to false by default. Could be overridden to true to enable the CI workflow
    /// for the deployed contract that has the config updated.
    function runIfDeployed() external view returns (bool);
}
