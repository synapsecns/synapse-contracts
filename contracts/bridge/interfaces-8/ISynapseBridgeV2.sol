// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IWETH9} from "../interfaces/IWETH9.sol";

import {ISynapseBridge} from "./ISynapseBridge.sol";
import {IERC20Mintable} from "./IERC20Mintable.sol";
import {ISwap} from "./ISwap.sol";
import {IRouter} from "./IRouter.sol";

import {IERC20} from "@openzeppelin/contracts-4.4.2/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts-4.4.2/token/ERC20/extensions/ERC20Burnable.sol";

interface ISynapseBridgeV2 {
    struct RouterTrade {
        address[] path;
        address[] adapters;
        uint256 maxBridgeSlippage;
    }

    event TokenDepositAndSwapV2(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        address[] path,
        address[] adapters,
        uint256 maxBridgeSlippage
    );

    event TokenMintAndSwapV2(
        address indexed to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        address[] path,
        address[] adapters,
        uint256 maxBridgeSlippage,
        bool swapSuccess,
        bytes32 indexed kappa
    );

    event TokenRedeemAndSwapV2(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        address[] path,
        address[] adapters,
        uint256 maxBridgeSlippage
    );

    event TokenWithdrawAndSwapV2(
        address indexed to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        address[] path,
        address[] adapters,
        uint256 maxBridgeSlippage,
        bool swapSuccess,
        bytes32 indexed kappa
    );

    function BRIDGE_VERSION()     external view returns (uint256);
    function START_BLOCK_NUMBER() external view returns (uint256);
    function CHAIN_GAS_AMOUNT()   external view returns (uint256);

    function WETH()      external view returns (IWETH9);
    function ROUTER()    external view returns (IRouter);
    function BRIDGE_V1() external view returns (ISynapseBridge);

    function setChainGasAmount(uint256 amount)             external;
    function setWethAddress(address payable _wethAddress)  external;
    function setRouterAddress(address payable _router)     external;
    function setBridgeV1Address(address payable _bridgeV1) external;

    function addKappas(bytes32[] calldata kappas)          external;

    function kappaExists(bytes32 kappa)          external view returns (bool);
    function getFeeBalance(address tokenAddress) external view returns (uint256);

    function depositMaxAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        address[] calldata path,
        address[] calldata adapters,
        uint256 maxBridgeSlippage
    ) external;

    function redeemMaxAndSwap(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        address[] calldata path,
        address[] calldata adapters,
        uint256 maxBridgeSlippage
    ) external;

    function mintAndSwap(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        RouterTrade calldata _trade,
        bytes32 kappa
    ) external;

    function withdrawAndSwap(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        RouterTrade calldata _trade,
        bytes32 kappa
    ) external;
}
