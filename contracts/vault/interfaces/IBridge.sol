// SPDX-License-Identifier: MIT

pragma solidity >=0.8.11;

import {ERC20Burnable} from "@openzeppelin/contracts-solc8/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

import {IBridgeRouter} from "../../router/interfaces/IBridgeRouter.sol";

interface IBridge {
    /// @dev NOT_SUPPORTED would be default value
    enum TokenType {
        NOT_SUPPORTED,
        MINT_BURN,
        DEPOSIT_WITHDRAW
    }

    // internal struct to avoid stack too deep error
    // solhint-disable-next-line
    struct _BridgeInData {
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

    struct TokenConfig {
        // -- FEES --
        /// @notice Synapse:bridge fee value(i.e. 0.1%), multiplied by `FEE_DENOMINATOR`
        uint256 synapseFee;
        /// @notice Maximum total bridge fee
        uint256 maxTotalFee;
        /// @notice Minimum part of the fee covering bridging in (always present)
        uint256 minBridgeFee;
        /// @notice Minimum part of the fee covering GasDrop (when gasDrop is present)
        uint256 minGasDropFee;
        /// @notice Minimum part of the fee covering further swap (when swap is present)
        uint256 minSwapFee;
        // -- TOKEN TYPE --
        /// @notice Describes how `token` is going to be bridged: mint or withdraw
        TokenType tokenType;
        /// @notice Contract responsible for `token` locking/releasing
        /// @dev If `token` is compatible with Synapse:Bridge directly, this would be `token` address
        /// Otherwise, it is address of BridgeWrapper for `token`
        address bridgeToken;
        // -- TOKEN MAP --
        /// @notice Token addresses on other chains
        mapping(uint256 => string) tokenMap;
    }

    event BridgeTokenRegistered(
        address indexed bridgeToken,
        address indexed bridgeWrapper,
        TokenType tokenType
    );

    event Recovered(address indexed asset, uint256 amount);

    // -- VIEWS

    function getBridgeToken(IERC20 token) external view returns (IERC20);

    function getUnderlyingToken(IERC20 token) external view returns (IERC20);

    function bridgeTokenType(address token) external view returns (TokenType);

    // -- BRIDGE EVENTS OUT: Reworked

    event BridgedOutEVM(
        address indexed to,
        uint256 chainId,
        IERC20 tokenBridgedFrom,
        IERC20 tokenBridgedTo,
        uint256 amount,
        SwapParams swapParams,
        bool gasdropRequested
    );

    event BridgedOutNonEVM(
        bytes32 indexed to,
        uint256 chainId,
        IERC20 tokenBridgedFrom,
        string tokenBridgedTo,
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
        uint256 gasdropAmount,
        bytes32 indexed kappa
    );

    // -- BRIDGE OUT FUNCTIONS: to EVM chains --

    function bridgeToEVM(
        address to,
        uint256 chainId,
        IERC20 token,
        SwapParams calldata destinationSwapParams,
        bool gasdropRequested
    ) external returns (uint256 amountBridged);

    // -- BRIDGE OUT FUNCTIONS: to non-EVM chains --

    function bridgeToNonEVM(
        bytes32 to,
        uint256 chainId,
        IERC20 token
    ) external returns (uint256 amountBridged);

    // -- BRIDGE IN FUNCTIONS --

    function bridgeIn(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        SwapParams calldata destinationSwapParams,
        bool gasdropRequested,
        bytes32 kappa
    ) external;

    // -- RESTRICTED FUNCTIONS --

    function registerBridgeToken(
        address bridgeToken,
        address bridgeWrapper,
        TokenType tokenType
    ) external;

    function recoverGAS() external;

    function recoverERC20(IERC20 token) external;

    function setRouter(IBridgeRouter _router) external;
}
