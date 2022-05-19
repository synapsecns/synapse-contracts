// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

interface IVault {
    // -- VIEWS --

    function chainGasAmount() external returns (uint256);

    function getFeeBalance(IERC20 token) external view returns (uint256);

    function getTokenBalance(IERC20 token) external view returns (uint256);

    function kappaExists(bytes32 kappa) external view returns (bool);

    function startBlockNumber() external view returns (uint256);

    function bridgeVersion() external view returns (uint256);

    // solhint-disable-next-line
    function NODEGROUP_ROLE() external view returns (bytes32);

    // solhint-disable-next-line
    function GOVERNANCE_ROLE() external view returns (bytes32);

    // solhint-disable-next-line
    function BRIDGE_ROLE() external view returns (bytes32);

    // solhint-disable-next-line
    function WETH_ADDRESS() external returns (address payable);

    // -- RESTRICTED ACCESS --

    function initialize() external;

    function setChainGasAmount(uint256 amount) external;

    function setWethAddress(address payable _wethAddress) external;

    function addKappas(bytes32[] calldata kappas) external;

    function recoverGAS(address to) external;

    function withdrawFees(IERC20 token, address to) external;

    function pause() external;

    function unpause() external;

    // -- VAULT FUNCTIONS --

    function mintToken(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        address gasdropAddress,
        bool gasdropRequested,
        bytes32 kappa
    ) external returns (uint256 gasdropAmount);

    function withdrawToken(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        address gasdropAddress,
        bool gasdropRequested,
        bytes32 kappa
    ) external returns (uint256 gasdropAmount);
}
