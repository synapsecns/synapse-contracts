// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';
import './interfaces/IECDSANodeManagement.sol';

contract ECDSAFactory is Ownable {
  event ECDSANodeGroupCreated(
    address indexed keepAddress,
    address[] members,
    address indexed owner,
    uint256 honestThreshold
  );

  struct LatestNodeGroup {
    address keepAddress;
    address[] members;
    address owner;
    uint256 honestThreshold;
  }

  LatestNodeGroup public latestNodeGroup;

  constructor() public Ownable() {}

  /// @notice Returns members of the keep.
  /// @return List of the keep members' addresses.
  function getMembers() public view returns (address[] memory) {
    return latestNodeGroup.members;
  }

  /**
    @notice Deploys a new node 
    @param nodeMgmtAddress address of the ECDSANodeManagement contract to initialize with
    @param owner Owner of the  ECDSANodeManagement contract who can determine if the node group is closed or active
    @param members Array of node group members addresses
    @param honestThreshold Number of signers to process a transaction 
    @return Address of the newest node management contract created
    **/
  function deploy(
    address nodeMgmtAddress,
    address owner,
    address[] memory members,
    uint256 honestThreshold
  ) external onlyOwner returns (address) {
    address nodeClone = Clones.clone(nodeMgmtAddress);
    IECDSANodeManagement(nodeClone).initialize(owner, members, honestThreshold);

    latestNodeGroup.keepAddress = nodeClone;
    latestNodeGroup.members = members;
    latestNodeGroup.owner = owner;
    latestNodeGroup.honestThreshold = honestThreshold;

    emit ECDSANodeGroupCreated(nodeClone, members, owner, honestThreshold);
    return nodeClone;
  }
}
