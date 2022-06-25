// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {ISwap} from "./ISwap.sol";

// solhint-disable func-name-mixedcase
interface IBridge {
    function NODEGROUP_ROLE() external view returns (bytes32);

    function GOVERNANCE_ROLE() external view returns (bytes32);

    function startBlockNumber() external view returns (uint256);

    function bridgeVersion() external view returns (uint256);

    function chainGasAmount() external view returns (uint256);

    function WETH_ADDRESS() external view returns (address payable);

    function getFeeBalance(IERC20 token) external view returns (uint256);

    function kappaExists(bytes32 kappa) external view returns (bool);

    function mint(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function mintAndSwap(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        ISwap pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bytes32 kappa
    ) external;

    function withdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function withdrawAndRemove(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        ISwap pool,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bytes32 kappa
    ) external;
}
