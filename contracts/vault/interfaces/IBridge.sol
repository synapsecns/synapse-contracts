// SPDX-License-Identifier: MIT

pragma solidity >=0.8.11;

import {ERC20Burnable} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

import {IVault} from "./IVault.sol";
import {IBridgeConfig} from "./IBridgeConfig.sol";

import {IBridgeRouter} from "../../router/interfaces/IBridgeRouter.sol";

interface IBridge {
    // internal struct to avoid stack too deep error
    // solhint-disable-next-line
    struct _BridgeInData {
        address bridgeToken;
        uint256 fee;
        uint256 amountOfSwaps;
        bool isEnabled;
        bool isMint;
        uint256 gasdropAmount;
        IERC20 tokenReceived;
        uint256 amountReceived;
    }

    struct SwapParams {
        uint256 minAmountOut;
        address[] path;
        address[] adapters;
        uint256 deadline;
    }

    event Recovered(address indexed asset, uint256 amount);

    // -- VIEWS --

    function bridgeConfig() external view returns (IBridgeConfig);

    function router() external view returns (IBridgeRouter);

    function vault() external view returns (IVault);

    // -- BRIDGE EVENTS OUT:

    event BridgedOutEVM(
        address indexed to,
        uint256 chainId,
        IERC20 tokenBridgedFrom,
        uint256 amount,
        IERC20 tokenBridgedTo,
        SwapParams swapParams,
        bool gasdropRequested
    );

    event BridgedOutNonEVM(
        bytes32 indexed to,
        uint256 chainId,
        IERC20 tokenBridgedFrom,
        uint256 amount,
        string tokenBridgedTo
    );

    // -- BRIDGE EVENTS IN --

    event TokenBridgedIn(
        address indexed to,
        IERC20 tokenBridged,
        uint256 amountBridged,
        uint256 bridgeFee,
        IERC20 tokenReceived,
        uint256 amountReceived,
        uint256 gasdropAmount,
        bytes32 indexed kappa
    );

    // -- BRIDGE OUT FUNCTIONS:

    function bridgeToEVM(
        address to,
        uint256 chainId,
        IERC20 token,
        SwapParams calldata destinationSwapParams,
        bool gasdropRequested
    ) external returns (uint256 amountBridged);

    function bridgeToNonEVM(
        bytes32 to,
        uint256 chainId,
        IERC20 token
    ) external returns (uint256 amountBridged);

    // -- BRIDGE IN FUNCTIONS --

    function bridgeInEVM(
        address to,
        IERC20 token,
        uint256 amount,
        SwapParams calldata destinationSwapParams,
        bool gasdropRequested,
        bytes32 kappa
    ) external;

    function bridgeInNonEVM(
        address to,
        uint256 chainIdFrom,
        string calldata bridgeTokenFrom,
        uint256 amount,
        bytes32 kappa
    ) external;
}
