// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import {Initializable} from "@openzeppelin/contracts-upgradeable-4.5.0/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable-4.5.0/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable-4.5.0/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable-4.5.0/security/PausableUpgradeable.sol";

import {ERC20Burnable} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {IVault} from "./interfaces/IVault.sol";
import {IBridge} from "./interfaces/IBridge.sol";
import {IBridgeConfig} from "./interfaces/IBridgeConfig.sol";

import {IBridgeRouter} from "../router/interfaces/IBridgeRouter.sol";

// solhint-disable reason-string

contract Bridge is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IBridge
{
    using SafeERC20 for IERC20;

    IBridgeConfig public bridgeConfig;
    IBridgeRouter public router;
    IVault public vault;

    bytes32 public constant NODEGROUP_ROLE = keccak256("NODEGROUP_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    /// @notice Maximum amount of GAS units for Swap part of bridge transaction
    uint256 public maxGasForSwap;

    uint256 internal constant UINT_MAX = type(uint256).max;

    function initialize(
        IVault _vault,
        IBridgeConfig _bridgeConfig,
        uint256 _maxGasForSwap
    ) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        vault = _vault;
        bridgeConfig = _bridgeConfig;
        maxGasForSwap = _maxGasForSwap;
    }

    // -- MODIFIERS --

    modifier checkSwapParams(SwapParams calldata swapParams) {
        require(
            swapParams.path.length == swapParams.adapters.length + 1,
            "|path|!=|adapters|+1"
        );

        _;
    }

    // -- RECOVER TOKEN/GAS --

    /**
        @notice Recover GAS from the contract
     */
    function recoverGAS() external onlyRole(GOVERNANCE_ROLE) {
        uint256 amount = address(this).balance;
        require(amount != 0, "!balance");

        emit Recovered(address(0), amount);
        //solhint-disable-next-line
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "!xfer");
    }

    /**
        @notice Recover a token from the contract
        @param token token to recover
     */
    function recoverERC20(IERC20 token) external onlyRole(GOVERNANCE_ROLE) {
        uint256 amount = token.balanceOf(address(this));
        require(amount != 0, "!balance");

        emit Recovered(address(token), amount);
        //solhint-disable-next-line
        token.safeTransfer(msg.sender, amount);
    }

    // -- RESTRICTED SETTERS --

    function setMaxGasForSwap(uint256 _maxGasForSwap)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        maxGasForSwap = _maxGasForSwap;
    }

    function setRouter(IBridgeRouter _router)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        router = _router;
    }

    // -- BRIDGE OUT FUNCTIONS: to EVM chains --

    function bridgeToEVM(
        address to,
        uint256 chainId,
        IERC20 token,
        SwapParams calldata destinationSwapParams,
        bool gasdropRequested
    )
        external
        checkSwapParams(destinationSwapParams)
        returns (uint256 amountBridged)
    {
        // First, get token address on destination chain and check if it is enabled
        (address tokenBridgedTo, bool isEnabled) = bridgeConfig
        .getTokenAddressEVM(address(token), chainId);

        require(tokenBridgedTo != address(0), "!token");
        require(isEnabled, "!enabled");
        require(tokenBridgedTo == destinationSwapParams.path[0], "!swap");

        // Then, burn token, or deposit to Vault (depending on bridge token type).
        // Use verified burnt/deposited amount for bridging purposes.
        amountBridged = _lockToken(token);

        // Finally, emit a Bridge Event
        emit BridgedOutEVM(
            to,
            chainId,
            token,
            amountBridged,
            IERC20(tokenBridgedTo),
            destinationSwapParams,
            gasdropRequested
        );
    }

    // -- BRIDGE OUT FUNCTIONS: to non-EVM chain --

    function bridgeToNonEVM(
        bytes32 to,
        uint256 chainId,
        IERC20 token
    ) external returns (uint256 amountBridged) {
        // First, get token address on destination chain and check if it is enabled
        (string memory tokenBridgedTo, bool isEnabled) = bridgeConfig
        .getTokenAddressNonEVM(address(token), chainId);
        require(bytes(tokenBridgedTo).length > 0, "!token");
        require(isEnabled, "!enabled");

        // Then, burn token, or deposit to Vault (depending on bridge token type).
        // Use verified burnt/deposited amount for bridging purposes.
        amountBridged = _lockToken(token);

        // Finally, emit a Bridge Event
        emit BridgedOutNonEVM(
            to,
            chainId,
            token,
            amountBridged,
            tokenBridgedTo
        );
    }

    // -- BRIDGE OUT : internal helpers --

    function _lockToken(IERC20 token)
        internal
        returns (uint256 amountVerified)
    {
        // Figure out how much tokens do we have.
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "!amount");

        (address bridgeToken, bool isEnabled, bool isMintBurn) = bridgeConfig
        .getBridgeToken(address(token));

        require(isEnabled, "!enabled");

        if (isMintBurn) {
            // Burn token, and verify how much was burnt
            uint256 balanceBefore = token.balanceOf(address(this));

            ERC20Burnable(bridgeToken).burn(amount);

            amountVerified = balanceBefore - token.balanceOf(address(this));
        } else {
            // Deposit token into Vault, and verify how much was burnt
            uint256 balanceBefore = token.balanceOf(address(vault));

            IERC20(bridgeToken).transfer(address(vault), amount);

            amountVerified = token.balanceOf(address(vault)) - balanceBefore;
        }

        require(amountVerified > 0, "!locked");
    }

    // -- BRIDGE IN FUNCTIONS --

    function bridgeInEVM(
        address to,
        IERC20 token,
        uint256 amount,
        SwapParams calldata swapParams,
        bool gasdropRequested,
        bytes32 kappa
    ) external onlyRole(NODEGROUP_ROLE) nonReentrant whenNotPaused {
        _bridgeIn(to, token, amount, swapParams, gasdropRequested, kappa);
    }

    function bridgeInNonEVM(
        address to,
        uint256 chainIdFrom,
        string calldata bridgeTokenFrom,
        uint256 amount,
        bytes32 kappa
    ) external onlyRole(NODEGROUP_ROLE) nonReentrant whenNotPaused {
        address token = bridgeConfig.findTokenNonEVM(
            chainIdFrom,
            bridgeTokenFrom
        );
        require(token != address(0), "!token");

        // Construct path consisting of bridge token only (for consistency)
        address[] memory path = new address[](1);
        path[0] = token;

        _bridgeIn(
            to,
            IERC20(token),
            amount,
            // (minAmountOut, path, adapters, swapDeadline)
            SwapParams(0, path, new address[](0), 0),
            // gasdropEnabled = true
            true,
            kappa
        );
    }

    function _bridgeIn(
        address to,
        IERC20 token,
        uint256 amount,
        SwapParams memory swapParams,
        bool gasdropRequested,
        bytes32 kappa
    ) internal {
        _BridgeInData memory data;
        // solhint-disable not-rely-on-time
        data.amountOfSwaps = block.timestamp <= swapParams.deadline
            ? swapParams.adapters.length
            : 0;

        (data.fee, data.bridgeToken, data.isEnabled, data.isMint) = bridgeConfig
        .calculateBridgeFee(
            address(token),
            amount,
            gasdropRequested,
            data.amountOfSwaps
        );

        require(amount > data.fee, "!fee");
        require(data.isEnabled, "!enabled");

        // First, get the amount post fees
        amount = amount - data.fee;

        // If swap is present, release tokens to Router directly
        // Otherwise, release them to specified user address
        data.gasdropAmount = _releaseToken(
            data.amountOfSwaps > 0 ? address(router) : to,
            data.bridgeToken,
            amount,
            data.fee,
            data.isMint,
            to, // always send gasDrop to user
            gasdropRequested,
            kappa
        );

        // If swap is present, do it and gather the info about tokens received
        // Otherwise, use bridge token and its amount
        (data.tokenReceived, data.amountReceived) = data.amountOfSwaps > 0
            ? _handleSwap(to, token, amount, swapParams)
            : (token, amount);

        // Finally, emit BridgeIn Event
        emit TokenBridgedIn(
            to,
            token,
            amount + data.fee,
            data.fee,
            data.tokenReceived,
            data.amountReceived,
            data.gasdropAmount,
            kappa
        );
    }

    // -- BRIDGE IN: internal helpers --

    function _handleSwap(
        address to,
        IERC20 token,
        uint256 amountPostFee,
        SwapParams memory swapParams
    ) internal returns (IERC20 tokenOut, uint256 amountOut) {
        // We're limiting amount of gas forwarded to Router,
        // so we always have some leftover gas to transfer
        // bridged token, should the swap run out of gas
        try
            router.postBridgeSwap{gas: maxGasForSwap}(
                to,
                swapParams,
                amountPostFee
            )
        returns (uint256 _amountOut) {
            // Swap succeeded, save information about received token
            tokenOut = IERC20(swapParams.path[swapParams.path.length - 1]);
            amountOut = _amountOut;
        } catch {
            // Swap failed, return bridge token to user
            tokenOut = token;
            amountOut = amountPostFee;
            router.refundToAddress(to, token, amountPostFee);
        }
    }

    function _isSwapPresent(SwapParams memory params)
        internal
        pure
        returns (bool)
    {
        return params.adapters.length > 0;
    }

    function _releaseToken(
        address to,
        address bridgeToken,
        uint256 amountPostFee,
        uint256 fee,
        bool isMint,
        address userAddress,
        bool gasdropRequested,
        bytes32 kappa
    ) internal returns (uint256 gasdropAmount) {
        gasdropAmount = (isMint ? vault.mintToken : vault.withdrawToken)(
            to,
            IERC20(bridgeToken),
            amountPostFee,
            fee,
            userAddress,
            gasdropRequested,
            kappa
        );
    }
}
