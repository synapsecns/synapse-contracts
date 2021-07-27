// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20BurnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/drafts/ERC20PermitUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';

contract SynapseERC20 is
  Initializable,
  ContextUpgradeable,
  AccessControlUpgradeable,
  ERC20BurnableUpgradeable,
  ERC20PermitUpgradeable
{
  bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');

  /**
   * @notice Initializes this ERC20 contract with the given parameters.
   * @param _name Token name
   * @param _symbol Token symbol
   * @param _decimals Token name
   * @param _owner admin address to be initialized with
   */
  function initialize(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    address _owner
  ) public initializer {
    __Context_init_unchained();
    __AccessControl_init_unchained();
    __ERC20_init_unchained(_name, _symbol);
    __ERC20Burnable_init_unchained();
    _setupDecimals(_decimals);
    __ERC20Permit_init(_name);
    _setupRole(DEFAULT_ADMIN_ROLE, _owner);
  }

  function mint(address to, uint256 amount) public {
    require(hasRole(MINTER_ROLE, msg.sender), 'Not a minter');
    _mint(to, amount);
  }
}
