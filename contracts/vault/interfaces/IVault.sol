// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    function withdrawToken(
        IERC20 token,
        uint256 amount,
        address to,
        bytes32 kappa
    ) external;

    function spendToken(
        IERC20 token,
        uint256 amount,
        address to
    ) external;
}
