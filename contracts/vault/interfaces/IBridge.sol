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

    // -- BRIDGE EVENTS OUT: Deposit --

    event TokenDeposit(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    );

    event TokenDepositAndSwapV2(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint256 minAmountOut,
        address[] path,
        address[] adapters,
        uint256 deadline
    );

    // -- BRIDGE EVENTS OUT: Redeem --

    event TokenRedeem(
        address indexed to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    );

    event TokenRedeemV2(
        bytes32 indexed to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    );

    event TokenRedeemAndSwapV2(
        address indexed to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount,
        uint256 minAmountOut,
        address[] path,
        address[] adapters,
        uint256 deadline
    );

    // -- BRIDGE EVENTS IN: Mint --

    event TokenMint(
        address indexed to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 indexed kappa
    );

    event TokenMintAndSwapV2(
        address indexed to,
        IERC20 tokenBridged,
        uint256 amountBridged,
        uint256 bridgeFee,
        IERC20 tokenReceived,
        uint256 amountReceived,
        bytes32 indexed kappa
    );

    // -- BRIDGE EVENTS IN: Withdraw --

    event TokenWithdraw(
        address indexed to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 indexed kappa
    );

    event TokenWithdrawAndSwapV2(
        address indexed to,
        IERC20 tokenBridged,
        uint256 amountBridged,
        uint256 bridgeFee,
        IERC20 tokenReceived,
        uint256 amountReceived,
        bytes32 indexed kappa
    );

    // -- BRIDGE OUT FUNCTIONS: Deposit --

    function deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external;

    function depositAndSwapV2(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        SwapParams calldata swapParams
    ) external;

    // -- BRIDGE OUT FUNCTIONS: Redeem --

    function redeem(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    ) external;

    function redeemV2(
        bytes32 to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    ) external;

    function redeemAndSwapV2(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount,
        SwapParams calldata swapParams
    ) external;

    // -- BRIDGE IN FUNCTIONS: Mint --

    function mint(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function mintAndSwapV2(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        SwapParams calldata swapParams,
        bytes32 kappa
    ) external;

    // -- BRIDGE IN FUNCTIONS: Withdraw --

    function withdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function withdrawAndSwapV2(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        SwapParams calldata swapParams,
        bytes32 kappa
    ) external;

    // -- RESTRICTED FUNCTIONS --

    function recoverGAS() external;

    function recoverERC20(IERC20 token) external;

    function setRouter(IBridgeRouter _router) external;
}
