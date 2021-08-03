// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

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
   * @param name Token name
   * @param symbol Token symbol
   * @param decimals Token name
   * @param owner admin address to be initialized with
   */
  function initialize(
    string memory name,
    string memory symbol,
    uint8 decimals,
    address owner
  ) external initializer {
    __Context_init_unchained();
    __AccessControl_init_unchained();
    __ERC20_init_unchained(name, symbol);
    __ERC20Burnable_init_unchained();
    _setupDecimals(decimals);
    __ERC20Permit_init(name);
    _setupRole(DEFAULT_ADMIN_ROLE, owner);
  }

  function mint(address to, uint256 amount) external {
    require(hasRole(MINTER_ROLE, msg.sender), 'Not a minter');
    _mint(to, amount);
  }
}
