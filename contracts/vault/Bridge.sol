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

    modifier preCheckPostGasDrop(
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

    // -- BRIDGE OUT FUNCTIONS: Deposit --

    function deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        _deposit(to, chainId, token, amount);
    }

    function depositMax(
        address to,
        uint256 chainId,
        IERC20 token
    ) external nonReentrant whenNotPaused {
        _deposit(to, chainId, token, _getMaxAmount(address(token)));
    }

    function depositAndSwapV2(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        SwapParams calldata swapParams
    ) external nonReentrant whenNotPaused {
        _depositAndSwapV2(to, chainId, token, amount, swapParams);
    }

    function depositMaxAndSwapV2(
        address to,
        uint256 chainId,
        IERC20 token,
        SwapParams calldata swapParams
    ) external nonReentrant whenNotPaused {
        _depositAndSwapV2(
            to,
            chainId,
            token,
            _getMaxAmount(address(token)),
            swapParams
        );
    }

    function _deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) internal {
        emit TokenDeposit(to, chainId, token, _depositToVault(token, amount));
    }

    function _depositAndSwapV2(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        SwapParams calldata swapParams
    ) internal {
        emit TokenDepositAndSwapV2(
            to,
            chainId,
            token,
            _depositToVault(token, amount),
            swapParams.minAmountOut,
            swapParams.path,
            swapParams.adapters,
            swapParams.deadline
        );
    }

    // -- BRIDGE OUT FUNCTIONS: Redeem --

    function redeem(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        _redeem(to, chainId, token, amount);
    }

    function redeemMax(
        address to,
        uint256 chainId,
        ERC20Burnable token
    ) external nonReentrant whenNotPaused {
        _redeem(to, chainId, token, _getMaxAmount(address(token)));
    }

    function redeemV2(
        bytes32 to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        _redeemV2(to, chainId, token, amount);
    }

    function redeemV2Max(
        bytes32 to,
        uint256 chainId,
        ERC20Burnable token
    ) external nonReentrant whenNotPaused {
        _redeemV2(to, chainId, token, _getMaxAmount(address(token)));
    }

    function redeemAndSwapV2(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount,
        SwapParams calldata swapParams
    ) external nonReentrant whenNotPaused {
        _redeemAndSwapV2(to, chainId, token, amount, swapParams);
    }

    function redeemMaxAndSwapV2(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        SwapParams calldata swapParams
    ) external nonReentrant whenNotPaused {
        _redeemAndSwapV2(
            to,
            chainId,
            token,
            _getMaxAmount(address(token)),
            swapParams
        );
    }

    function _redeem(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    ) internal {
        emit TokenRedeem(to, chainId, token, _burnFromSender(token, amount));
    }

    function _redeemV2(
        bytes32 to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    ) internal {
        emit TokenRedeemV2(to, chainId, token, _burnFromSender(token, amount));
    }

    function _redeemAndSwapV2(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount,
        SwapParams calldata swapParams
    ) internal {
        emit TokenRedeemAndSwapV2(
            to,
            chainId,
            token,
            _burnFromSender(token, amount),
            swapParams.minAmountOut,
            swapParams.path,
            swapParams.adapters,
            swapParams.deadline
        );
    }

    // -- BRIDGE IN FUNCTIONS: Mint --

    function mint(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    )
        external
        onlyRole(NODEGROUP_ROLE)
        nonReentrant
        whenNotPaused
        preCheckPostGasDrop(amount, fee, to)
    {
        // Use amount post fees
        _mint(to, token, amount - fee, fee, kappa, true);
    }

    function mintAndSwapV2(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        SwapParams calldata swapParams,
        bytes32 kappa
    )
        external
        onlyRole(NODEGROUP_ROLE)
        nonReentrant
        whenNotPaused
        preCheckPostGasDrop(amount, fee, to)
    {
        // First, get the amount post fees
        amount = amount - fee;
        if (_isDeadlineFailed(swapParams.deadline)) {
            _mint(to, token, amount, fee, kappa, true);
            return;
        }

        // Mint tokens directly to Router
        _mint(address(router), token, amount, fee, kappa, false);

        // Tokens are in Router, do the swap
        (IERC20 tokenOut, uint256 amountOut) = _handleSwap(
            to,
            token,
            amount,
            swapParams
        );

        emit TokenMintAndSwapV2(
            to,
            token,
            amount + fee,
            fee,
            tokenOut,
            amountOut,
            kappa
        );
    }

    function _mint(
        address to,
        IERC20 token,
        uint256 amountPostFee,
        uint256 fee,
        bytes32 kappa,
        bool emitEvent
    ) internal {
        token.mint(address(vault), fee);
        vault.adjustMintedFees(token, fee, kappa);
        token.mint(to, amountPostFee);

        if (emitEvent) {
            emit TokenMint(to, token, amountPostFee + fee, fee, kappa);
        }
    }

    // -- BRIDGE IN FUNCTIONS: Withdraw --

    function withdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    )
        external
        onlyRole(NODEGROUP_ROLE)
        nonReentrant
        whenNotPaused
        preCheckPostGasDrop(amount, fee, to)
    {
        // Use amount post fees
        _withdraw(to, token, amount - fee, fee, kappa, true);
    }

    function withdrawAndSwapV2(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        SwapParams calldata swapParams,
        bytes32 kappa
    )
        external
        onlyRole(NODEGROUP_ROLE)
        nonReentrant
        whenNotPaused
        preCheckPostGasDrop(amount, fee, to)
    {
        // First, get the amount post fees
        amount = amount - fee;
        if (_isDeadlineFailed(swapParams.deadline)) {
            _withdraw(to, token, amount, fee, kappa, true);
            return;
        }

        // Withdraw tokens directly to Router
        _withdraw(address(router), token, amount, fee, kappa, false);

        // Tokens are in Router, do the swap
        (IERC20 tokenOut, uint256 amountOut) = _handleSwap(
            to,
            token,
            amount,
            swapParams
        );

        emit TokenWithdrawAndSwapV2(
            to,
            token,
            amount + fee,
            fee,
            tokenOut,
            amountOut,
            kappa
        );
    }

    function _withdraw(
        address to,
        IERC20 token,
        uint256 amountPostFee,
        uint256 fee,
        bytes32 kappa,
        bool emitEvent
    ) internal {
        vault.withdrawToken(to, token, amountPostFee, fee, kappa);

        if (emitEvent) {
            emit TokenWithdraw(to, token, amountPostFee + fee, fee, kappa);
        }
    }

    // -- INTERNAL HELPERS --

    function _burnFromSender(ERC20Burnable token, uint256 amount)
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
    ) internal returns (IERC20 tokenOut, uint256 amountOut) {
        // We're limiting amount of gas forwarded to Router,
        // so we always have some leftover gas to transfer
        // bridged token, should the swap run out of gas
        try
            router.selfSwap{gas: maxGasForSwap}(
                amountPostFee,
                swapParams.minAmountOut,
                swapParams.path,
                swapParams.adapters,
                to
            )
        returns (uint256 _amountOut) {
            tokenOut = IERC20(swapParams.path[swapParams.path.length - 1]);
            amountOut = _amountOut;
        } catch {
            tokenOut = token;
            amountOut = amountPostFee;
            router.refundToAddress(address(token), amountPostFee, to);
        }
    }

    function _isDeadlineFailed(uint256 deadline) internal view returns (bool) {
        //solhint-disable-next-line
        return block.timestamp > deadline;
    }

    function _transferGasDrop(address to) internal {
        if (address(this).balance >= chainGasAmount) {
            //solhint-disable-next-line
            (bool success, ) = to.call{value: chainGasAmount}("");
            require(success, "GAS drop failed");
        }
    }
}
