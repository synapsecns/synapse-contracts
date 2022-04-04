// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import {Initializable} from "@openzeppelin/contracts-upgradeable-solc8/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable-solc8/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable-solc8/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable-solc8/security/PausableUpgradeable.sol";

import {ERC20Burnable} from "@openzeppelin/contracts-solc8/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import {IVault} from "./interfaces/IVault.sol";
import {IBridge} from "./interfaces/IBridge.sol";

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

    IVault public vault;
    IBridgeRouter public router;

    bytes32 public constant NODEGROUP_ROLE = keccak256("NODEGROUP_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    /// @notice GAS airdrop amount, that is given for every bridge IN transaction
    uint128 public chainGasAmount;
    /// @notice Maximum amount of GAS units for Swap part of bridge transaction
    uint128 public maxGasForSwap;

    uint256 internal constant UINT_MAX = type(uint256).max;

    uint256 internal constant MINT_BURN = 1;
    uint256 internal constant DEPOSIT_WITHDRAW = 2;

    mapping(address => uint256) public tokenBridgeType;

    function initialize(IVault _vault, uint128 _maxGasForSwap)
        external
        initializer
    {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        vault = _vault;
        maxGasForSwap = _maxGasForSwap;

        updateChainGasAmount();
    }

    function updateChainGasAmount() public {
        chainGasAmount = uint128(vault.chainGasAmount());
    }

    // -- MODIFIERS --

    modifier bridgeInTx(
        uint256 amount,
        uint256 fee,
        address to
    ) {
        require(amount > fee, "Amount must be greater than fee");

        _;

        _transferGasDrop(to);
    }

    // -- RECOVER TOKEN/GAS --

    /**
        @notice Recover GAS from the contract
     */
    function recoverGAS() external onlyRole(GOVERNANCE_ROLE) {
        uint256 amount = address(this).balance;
        require(amount != 0, "Nothing to recover");

        emit Recovered(address(0), amount);
        //solhint-disable-next-line
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "GAS transfer failed");
    }

    /**
        @notice Recover a token from the contract
        @param token token to recover
     */
    function recoverERC20(IERC20 token) external onlyRole(GOVERNANCE_ROLE) {
        uint256 amount = token.balanceOf(address(this));
        require(amount != 0, "Nothing to recover");

        emit Recovered(address(token), amount);
        //solhint-disable-next-line
        token.safeTransfer(msg.sender, amount);
    }

    // -- RESTRICTED SETTERS --

    function setMaxGasForSwap(uint128 _maxGasForSwap)
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

    function setTokenBridgeType(address token, uint256 bridgeType)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        tokenBridgeType[token] = bridgeType;
    }

    // -- BRIDGE OUT FUNCTIONS: Deposit --

    function depositEVM(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapParams calldata destinationSwapParams
    ) external {
        _depositEVM(to, chainId, IERC20(token), amount, destinationSwapParams);
    }

    function depositMaxEVM(
        address to,
        uint256 chainId,
        address token,
        SwapParams calldata destinationSwapParams
    ) external {
        // First, determine how much Bridge call pull from caller
        uint256 amount = _getMaxAmount(token);

        _depositEVM(to, chainId, IERC20(token), amount, destinationSwapParams);
    }

    function depositNonEVM(
        bytes32 to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external {
        _depositNonEVM(to, chainId, IERC20(token), amount);
    }

    function depositMaxNonEVM(
        bytes32 to,
        uint256 chainId,
        address token
    ) external {
        // First, determine how much Bridge call pull from caller
        uint256 amount = _getMaxAmount(token);
        _depositNonEVM(to, chainId, IERC20(token), amount);
    }

    function _depositEVM(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        SwapParams calldata destinationSwapParams
    ) internal {
        // First, deposit to Vault. Use verified deposit amount for bridging
        amount = _depositToVault(token, amount);
        // Then, emit corresponding Bridge Event
        if (_isSwapPresent(destinationSwapParams)) {
            emit TokenDepositEVM(
                to,
                chainId,
                token,
                amount,
                destinationSwapParams.minAmountOut,
                destinationSwapParams.path,
                destinationSwapParams.adapters,
                destinationSwapParams.deadline
            );
        } else {
            emit TokenDepositEVM(
                to,
                chainId,
                token,
                amount,
                0, // minAmountOut
                new address[](0), // path
                new address[](0), // adapters
                UINT_MAX // deadline
            );
        }
    }

    function _depositNonEVM(
        bytes32 to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) internal {
        // First, deposit to Vault. Use verified deposit amount for bridging
        amount = _depositToVault(token, amount);
        // Then, emit corresponding Bridge Event
        emit TokenDepositNonEVM(to, chainId, token, amount);
    }

    // -- BRIDGE OUT FUNCTIONS: Redeem --

    function redeemEVM(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapParams calldata destinationSwapParams
    ) external {
        _redeemEVM(
            to,
            chainId,
            ERC20Burnable(token),
            amount,
            destinationSwapParams
        );
    }

    function redeemMaxEVM(
        address to,
        uint256 chainId,
        address token,
        SwapParams calldata destinationSwapParams
    ) external {
        // First, determine how much Bridge can pull from caller
        uint256 amount = _getMaxAmount(token);

        _redeemEVM(
            to,
            chainId,
            ERC20Burnable(token),
            amount,
            destinationSwapParams
        );
    }

    function redeemNonEVM(
        bytes32 to,
        uint256 chainId,
        address token,
        uint256 amount
    ) external {
        _redeemNonEVM(to, chainId, ERC20Burnable(token), amount);
    }

    function redeemMaxNonEVM(
        bytes32 to,
        uint256 chainId,
        address token
    ) external {
        // First, determine how much Bridge can pull from caller
        uint256 amount = _getMaxAmount(token);
        _redeemNonEVM(to, chainId, ERC20Burnable(token), amount);
    }

    function _redeemEVM(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount,
        SwapParams calldata destinationSwapParams
    ) internal {
        // First, burn tokens from caller. Use verified deposit amount for bridging
        amount = _burnFromCaller(token, amount);
        // Then, emit corresponding Bridge Event
        if (_isSwapPresent(destinationSwapParams)) {
            emit TokenRedeemEVM(
                to,
                chainId,
                token,
                amount,
                destinationSwapParams.minAmountOut,
                destinationSwapParams.path,
                destinationSwapParams.adapters,
                destinationSwapParams.deadline
            );
        } else {
            emit TokenRedeemEVM(
                to,
                chainId,
                token,
                amount,
                0, // minAmountOut
                new address[](0), // path
                new address[](0), // adapters
                UINT_MAX // deadline
            );
        }
    }

    function _redeemNonEVM(
        bytes32 to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    ) internal {
        // First, burn tokens from caller. Use verified deposit amount for bridging
        amount = _burnFromCaller(token, amount);
        // Then, emit corresponding Bridge Event
        emit TokenRedeemNonEVM(to, chainId, token, amount);
    }

    // -- BRIDGE IN FUNCTIONS --

    function bridgeIn(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bool isMint,
        SwapParams calldata swapParams,
        bytes32 kappa
    )
        external
        onlyRole(NODEGROUP_ROLE)
        nonReentrant
        whenNotPaused
        bridgeInTx(amount, fee, to)
    {
        // First, get the amount post fees
        amount = amount - fee;

        SwapResult memory swapResult;

        if (
            _isSwapPresent(swapParams) &&
            !_isDeadlineFailed(swapParams.deadline)
        ) {
            // If there's a swap, and deadline check is passed,
            // mint|withdraw bridged tokens to Router
            (isMint ? vault.mintToken : vault.withdrawToken)(
                address(router),
                token,
                amount,
                fee,
                kappa
            );

            // Then handle the swap part
            swapResult = _handleSwap(to, token, amount, swapParams);
        } else {
            // If there's no swap, or deadline check is not passed,
            // mint|withdraw bridged token to needed address
            (isMint ? vault.mintToken : vault.withdrawToken)(
                to,
                token,
                amount,
                fee,
                kappa
            );

            // TODO: if bridge wrapper is used, its address will be emitted.
            // Is this what we want?
            swapResult = SwapResult(token, amount);
        }

        // Finally, emit BridgeIn Event
        emit TokenBridgedIn(
            to,
            token,
            amount + fee,
            fee,
            swapResult.tokenReceived,
            swapResult.amountReceived,
            isMint,
            kappa
        );
    }

    // -- INTERNAL HELPERS --

    function _burnFromCaller(ERC20Burnable token, uint256 amount)
        internal
        returns (uint256 amountBurnt)
    {
        uint256 balanceBefore = token.balanceOf(msg.sender);
        token.burnFrom(msg.sender, amount);
        amountBurnt = balanceBefore - token.balanceOf(msg.sender);
        require(amountBurnt > 0, "No burn happened");
    }

    function _depositToVault(IERC20 token, uint256 amount)
        internal
        returns (uint256 amountDeposited)
    {
        uint256 balanceBefore = token.balanceOf(address(vault));
        token.safeTransferFrom(msg.sender, address(vault), amount);
        amountDeposited = token.balanceOf(address(vault)) - balanceBefore;
        require(amountDeposited > 0, "No deposit happened");
    }

    function _getMaxAmount(address tokenAddress)
        internal
        view
        returns (uint256)
    {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(msg.sender);
        uint256 allowance = token.allowance(msg.sender, address(this));
        return balance < allowance ? balance : allowance;
    }

    function _handleSwap(
        address to,
        IERC20 token,
        uint256 amountPostFee,
        SwapParams calldata swapParams
    ) internal returns (SwapResult memory swapResult) {
        // We're limiting amount of gas forwarded to Router,
        // so we always have some leftover gas to transfer
        // bridged token, should the swap run out of gas
        try
            router.postBridgeSwap{gas: maxGasForSwap}(
                amountPostFee,
                swapParams,
                to
            )
        returns (uint256 _amountOut) {
            swapResult = SwapResult(
                IERC20(swapParams.path[swapParams.path.length - 1]),
                _amountOut
            );
        } catch {
            swapResult = SwapResult(token, amountPostFee);
            router.refundToAddress(address(token), amountPostFee, to);
        }
    }

    function _isDeadlineFailed(uint256 deadline) internal view returns (bool) {
        //solhint-disable-next-line
        return block.timestamp > deadline;
    }

    function _isSwapPresent(SwapParams calldata params)
        internal
        pure
        returns (bool)
    {
        if (params.adapters.length == 0) {
            require(
                params.path.length == 0,
                "Path must be empty, if no adapters"
            );
            return false;
        }
        return true;
    }

    function _transferGasDrop(address to) internal {
        if (address(this).balance >= chainGasAmount) {
            //solhint-disable-next-line
            (bool success, ) = to.call{value: chainGasAmount}("");
        }
    }
}
