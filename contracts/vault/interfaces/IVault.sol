// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

interface IVault {
    // -- VIEWS --

    function chainGasAmount() external returns (uint256);

    function getFeeBalance(address tokenAddress)
        external
        view
        returns (uint256);

    function getTokenBalance(IERC20 token) external view returns (uint256);

    function kappaExists(bytes32 kappa) external view returns (bool);

    // solhint-disable-next-line
    function WETH_ADDRESS() external returns (address payable);

    // -- VAULT FUNCTIONS --

    function mintToken(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function spendToken(
        address to,
        IERC20 token,
        uint256 amount
    ) external;

    function withdrawToken(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;
}
