// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IAuthVerifier {
    /**
     * @notice Authentication library to allow the validator network to execute cross-chain messages.
     * @param _authData A bytes32 address encoded via abi.encode(address)
     * @return authenticated returns true if bytes data submitted and decoded to the address is correct
     */
    function msgAuth(bytes calldata _authData)
        external
        view
        returns (bool authenticated);

    /**
     * @notice Permissioned method to support upgrades to the library
     * @param _nodegroup address which has authentication to execute messages
     */
    function setNodeGroup(address _nodegroup) external;
}
