// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/access/AccessControl.sol';

contract PoolConfig is AccessControl {
  bytes32 public constant BRIDGEMANAGER_ROLE = keccak256('BRIDGEMANAGER_ROLE');
  mapping(address => mapping(uint256 => Pool)) private _pool; // key is tokenAddress,chainID

  struct Pool {
    address tokenAddress;
    uint256 chainId;
    address poolAddress;
    bool metaswap;
  }

  constructor() public {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(BRIDGEMANAGER_ROLE, msg.sender);
  }

  function getPoolConfig(address tokenAddress, uint256 chainID)
    external
    view
    returns (Pool memory)
  {
    return _pool[tokenAddress][chainID];
  }

  function setPoolConfig(
    address tokenAddress,
    uint256 chainID,
    address poolAddress,
    bool metaswap
  ) external returns (Pool memory) {
    require(
      hasRole(BRIDGEMANAGER_ROLE, msg.sender),
      'Caller is not Bridge Manager'
    );
    Pool memory newPool = Pool(tokenAddress, chainID, poolAddress, metaswap);
    _pool[tokenAddress][chainID] = newPool;
    return newPool;
  }
}
