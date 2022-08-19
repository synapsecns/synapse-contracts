// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/ISynapseERC20.sol";

contract SynapseERC20DeterministicFactory is Ownable {
    constructor(address deployer) public Ownable() {
        transferOwnership(deployer);
    }

    event SynapseERC20Created(address contractAddress);

    /**
     * @notice Deploys a new SynapseERC20 token
     * @param synapseERC20Address address of the synapseERC20Address contract to initialize with
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals Token name
     * @param owner admin address to be initialized with
     * @return synERC20Clone Address of the newest SynapseERC20 token created
     **/
    function deploy(
        address synapseERC20Address,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address owner
    ) external returns (address synERC20Clone) {
        synERC20Clone = Clones.clone(synapseERC20Address);
        _initializeToken(synERC20Clone, name, symbol, decimals, owner);
    }

    /**
     * @notice Deploys a new SynapseERC20 token
     * @dev Use the same salt for the same token on different chains to get the same deployment address.
     *      Requires having SynapseERC20Factory deployed at the same address on different chains as well.
     *
     * NOTE: this function has onlyOwner modifier to prevent bad actors from taking a token's address on another chain
     *
     * @param synapseERC20Address address of the synapseERC20Address contract to initialize with
     * @param salt Salt for creating a clone
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals Token name
     * @param owner admin address to be initialized with
     * @return synERC20Clone Address of the newest SynapseERC20 token created
     **/
    function deployDeterministic(
        address synapseERC20Address,
        bytes32 salt,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address owner
    ) external onlyOwner returns (address synERC20Clone) {
        synERC20Clone = Clones.cloneDeterministic(synapseERC20Address, salt);
        _initializeToken(synERC20Clone, name, symbol, decimals, owner);
    }

    function predictDeterministicAddress(
        address synapseERC20Address,
        bytes32 salt
    ) external view returns (address) {
        return Clones.predictDeterministicAddress(synapseERC20Address, salt);
    }

    function _initializeToken(
        address synERC20Clone,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address owner
    ) internal {
        ISynapseERC20(synERC20Clone).initialize(name, symbol, decimals, owner);
        emit SynapseERC20Created(synERC20Clone);
    }
}
