// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract AuthVerifier is Ownable {
    address public nodegroup;

    constructor(address _nodegroup) {
        nodegroup = _nodegroup;
    }

    /**
     * @notice Authentication library to allow the validator network to execute cross-chain messages.
     * @param _authData A bytes32 address encoded via abi.encode(address)
     * @return authenticated returns true if bytes data submitted and decoded to the address is correct. Reverts if check fails.
     */
    function msgAuth(bytes calldata _authData) external view returns (bool authenticated) {
        address caller = abi.decode(_authData, (address));
        require(caller == nodegroup, "Unauthenticated caller");
        return true;
    }

    /**
     * @notice Permissioned method to support upgrades to the library
     * @param _nodegroup address which has authentication to execute messages
     */
    function setNodeGroup(address _nodegroup) external onlyOwner {
        nodegroup = _nodegroup;
    }
}
