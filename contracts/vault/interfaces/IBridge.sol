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
        /// @notice Contract responsible for `token` locking/releasing.
        /// @dev If `token` is compatible with Synapse:Bridge directly, this would be `token` address.
        /// Otherwise, it is address of BridgeWrapper for `token`.
        /// No one (UI, users, validators) needs to know about this extra layer, it is abstracted away
        /// outside of Bridge contract.
        address bridgeToken;
        bool isEnabled;
        /// @dev If `token` comes from non-EVM chain, these will store the token config there
        /// Otherwise, these are left empty.
        uint256 chainIdNonEVM;
        string bridgeTokenNonEVM;
        /// @dev List of ALL EVM chains `token` is present on, in no particular order.
        /// This includes the chain this Bridge is deployed on
        uint256[] chainIdsEVM;
    }

    event TokenSetupUpdated(IERC20 token, address bridgeToken, bool isMintBurn);

    event TokenFeesUpdated(
        IERC20 token,
        uint256 synapseFee,
        uint256 maxTotalFee,
        uint256 minBridgeFee,
        uint256 minGasDropFee,
        uint256 minSwapFee
    );

    event TokenMapUpdated(
        uint256[] chainIdsEVM,
        address[] bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string bridgeTokenNonEVM
    );

    event TokenDeleted(uint256 chainIdEVM, address bridgeTokenEVM);

    event TokenStatusUpdated(
        uint256[] chainIdsEVM,
        address[] bridgeTokensEVM,
        bool isEnabled
    );

    event Recovered(address indexed asset, uint256 amount);

    // -- VIEWS

    function calculateBridgeFee(
        address token,
        uint256 amount,
        bool gasdropRequested,
        bool swapRequested
    ) external view returns (uint256 fee);

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
        string memory bridgeTokenFrom,
        uint256 amount,
        bytes32 kappa
    ) external;
}
