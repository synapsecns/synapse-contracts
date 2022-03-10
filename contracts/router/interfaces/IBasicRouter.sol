// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBasicRouter {
    event Recovered(address indexed _asset, uint256 amount);

    event UpdatedTrustedAdapters(address[] _newTrustedAdapters);

    event AddedTrustedAdapter(address _newTrustedAdapter);

    event RemovedAdapter(address _removedAdapter);

    // -- VIEWS --

    function getTrustedAdapter(uint8 _index) external view returns (address);

    function trustedAdaptersCount() external view returns (uint256);

    // -- ADAPTER FUNCTIONS --

    function addTrustedAdapter(address _adapter) external;

    function removeAdapter(address _adapter) external;

    function removeAdapterByIndex(uint8 _index) external;

    function setAdapters(address[] memory _adapters) external;

    // -- RECOVER FUNCTIONS --

    function recoverERC20(address _tokenAddress) external;

    function recoverGAS() external;

    // -- RECEIVE GAS FUNCTION --

    receive() external payable;
}
