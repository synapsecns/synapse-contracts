// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBasicRouter {
    event Recovered(address indexed _asset, uint256 amount);

    event AddedTrustedAdapter(address _newTrustedAdapter);

    event RemovedAdapter(address _removedAdapter);

    event UpdatedAdapters(address[] _adapters, bool _isTrusted);

    // -- VIEWS --

    function isTrustedAdapter(address _adapter) external view returns (bool);

    // solhint-disable-next-line
    function WGAS() external view returns (address payable);

    // -- ADAPTER FUNCTIONS --

    function addTrustedAdapter(address _adapter) external;

    function removeAdapter(address _adapter) external;

    function setAdapters(address[] memory _adapters, bool _status) external;

    // -- RECOVER FUNCTIONS --

    function recoverERC20(address _tokenAddress) external;

    function recoverGAS() external;

    // -- RECEIVE GAS FUNCTION --

    receive() external payable;
}
