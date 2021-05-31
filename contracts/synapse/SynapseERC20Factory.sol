// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "openzeppelin-contracts-3.4/proxy/Clones.sol";
import "./interfaces/ISynapseERC20.sol";

contract SynapseERC20Factory  {
    constructor() public {}

    /**
    * @notice Deploys a new node 
    * @param synapseERC20Address address of the synapseERC20Address contract to initialize with
    * @param _name Token name
    * @param _symbol Token symbol
    * @param _decimals Token name
    * @param _owner admin address to be initialized with
    * @return Address of the newest node management contract created
    **/
    function deploy(
    address synapseERC20Address, string memory _name, string memory _symbol, uint8 _decimals, address _owner
    ) external returns (address) {
        address synERC20Clone = Clones.clone(synapseERC20Address);
        ISynapseERC20(synERC20Clone).initialize(
            _name,
            _symbol,
            _decimals,
            _owner
        );

        return synERC20Clone;
    }
}
