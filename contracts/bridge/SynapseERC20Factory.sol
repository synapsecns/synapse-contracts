// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/ISynapseERC20.sol";

contract SynapseERC20Factory {
    constructor() public {}

    event SynapseERC20Created(address contractAddress);

    /**
     * @notice Deploys a new node
     * @param synapseERC20Address address of the synapseERC20Address contract to initialize with
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals Token name
     * @param owner admin address to be initialized with
     * @return Address of the newest node management contract created
     **/
    function deploy(
        address synapseERC20Address,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address owner
    ) external returns (address) {
        address synERC20Clone = Clones.clone(synapseERC20Address);
        ISynapseERC20(synERC20Clone).initialize(name, symbol, decimals, owner);

        emit SynapseERC20Created(synERC20Clone);

        return synERC20Clone;
    }
}
