// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IntegrationTest {
    /// @notice Returns the name of the chain where the integration test is running.
    function chainName() external view returns (string memory);

    /// @notice Returns the name of the contract to be tested.
    /// @dev The integration test will be skipped if the contract has already been deployed.
    function contractName() external view returns (string memory);
}
