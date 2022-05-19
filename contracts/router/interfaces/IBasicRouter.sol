// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

interface IBasicRouter {
    event Recovered(address indexed asset, uint256 amount);

    event AddedTrustedAdapter(address newTrustedAdapter);

    event RemovedAdapter(address removedAdapter);

    event UpdatedAdapters(address[] adapters, bool isTrusted);

    // -- VIEWS --

    function isTrustedAdapter(address adapter) external view returns (bool);

    // solhint-disable-next-line
    function WGAS() external view returns (address payable);

    // -- ADAPTER FUNCTIONS --

    function addTrustedAdapter(address adapter) external;

    function removeAdapter(address adapter) external;

    function setAdapters(address[] memory adapters, bool status) external;

    // -- RECOVER FUNCTIONS --

    function recoverERC20(IERC20 token) external;

    function recoverGAS() external;

    // -- RECEIVE GAS FUNCTION --

    receive() external payable;
}
