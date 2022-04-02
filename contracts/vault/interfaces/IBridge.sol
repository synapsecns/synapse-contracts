// SPDX-License-Identifier: MIT

pragma solidity >=0.8.11;

import {ERC20Burnable} from "@openzeppelin/contracts-solc8/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

import {IBridgeRouter} from "../../router/interfaces/IBridgeRouter.sol";

interface IBridge {
    struct SwapParams {
        uint256 minAmountOut;
        address[] path;
        address[] adapters;
        uint256 deadline;
    }

    event Recovered(address indexed asset, uint256 amount);

    // -- VIEWS

    function tokenBridgeType(address token) external view returns (uint256);

    // -- BRIDGE EVENTS OUT: Deposit --

    event TokenDepositEVM(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint256 minAmountOut,
        address[] path,
        address[] adapters,
        uint256 deadline
    );

    event TokenDepositNonEVM(
        bytes32 indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    );

    // -- BRIDGE EVENTS OUT: Redeem --

    event TokenRedeemEVM(
        address indexed to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount,
        uint256 minAmountOut,
        address[] path,
        address[] adapters,
        uint256 deadline
    );

    event TokenRedeemNonEVM(
        bytes32 indexed to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    );

    // -- BRIDGE EVENTS IN --

    event TokenBridgedIn(
        address indexed to,
        IERC20 tokenBridged,
        uint256 amountBridged,
        uint256 bridgeFee,
        IERC20 tokenReceived,
        uint256 amountReceived,
        bool isMint,
        bytes32 indexed kappa
    );

    // -- BRIDGE OUT FUNCTIONS: Deposit --

    function depositEVM(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapParams calldata swapParams
    ) external;

    function depositMaxEVM(
        address to,
        uint256 chainId,
        address token,
        SwapParams calldata swapParams
    ) external;

    function depositNonEVM(
        bytes32 to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external;

    function depositMaxNonEVM(
        bytes32 to,
        uint256 chainId,
        address token
    ) external;

    // -- BRIDGE OUT FUNCTIONS: Redeem --

    function redeemEVM(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapParams calldata swapParams
    ) external;

    function redeemMaxEVM(
        address to,
        uint256 chainId,
        address token,
        SwapParams calldata swapParams
    ) external;

    function redeemNonEVM(
        bytes32 to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external;

    function redeemMaxNonEVM(
        bytes32 to,
        uint256 chainId,
        address token
    ) external;

    // -- BRIDGE IN FUNCTIONS --

    function bridgeIn(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bool isMint,
        SwapParams calldata swapParams,
        bytes32 kappa
    ) external;

    // -- RESTRICTED FUNCTIONS --

    function recoverGAS() external;

    function recoverERC20(IERC20 token) external;

    function setRouter(IBridgeRouter _router) external;

    function setTokenBridgeType(address token, uint256 bridgeType) external;
}
