// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBasicRouter {
    event Recovered(address indexed _asset, uint256 amount);

    event UpdatedTrustedAdapters(address[] _newTrustedAdapters);

    event AddedTrustedAdapter(address _newTrustedAdapter);

    event RemovedAdapter(address _removedAdapter);

    function setAdapters(address[] memory _adapters) external;

    function getTrustedAdapter(uint256 _index) external view returns (address);

    function trustedAdaptersCount() external view returns (uint256);

    function recoverERC20(address _tokenAddress) external;

    function recoverGAS() external;

    receive() external payable;
}
