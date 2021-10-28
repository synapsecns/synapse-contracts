// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './interfaces/IMetaSwapDeposit.sol';
import './interfaces/ISwap.sol';
import './interfaces/IWETH9.sol';
import "./interfaces/ISynapseBridge.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract BridgeAuthProxy is Initializable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Mintable;
    using SafeMath for uint256;

    ISynapseBridge public BRIDGE;

    bytes32 public constant GOVERNANCE_ROLE = keccak256('GOVERNANCE_ROLE');

    receive() external payable {
        // TODO: pass payments to synapse bridge
    }

    function initialize() external initializer {
        // initialize initializes the auth proxy
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();
    }

    function setBridgeAddress(address payable _bridgeAddress){
        require(hasRole(GOVERNANCE_ROLE, msg.sender));
        BRIDGE = ISynapseBridge(_bridgeAddress);
    }

    /**
     * @notice Relays to nodes to transfers an ERC20 token cross-chain
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   **/
    function deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint256 signature
    ) external nonReentrant() whenNotPaused() {
        require(verifySignature(signature));
        BRIDGE.deposit(to, chainId, token, amount, signature);
    }

    /**
     * @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   **/
    function redeem(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    ) external nonReentrant() whenNotPaused() {
        emit TokenRedeem(to, chainId, token, amount);
        token.burnFrom(msg.sender, amount);
    }

    /**
     * @notice Function to be called by the node group to withdraw the underlying assets from the contract
   * @param to address on chain to send underlying assets to
   * @param token ERC20 compatible token to withdraw from the bridge
   * @param amount Amount in native token decimals to withdraw
   * @param fee Amount in native token decimals to save to the contract as fees
   * @param kappa kappa
   **/
    function withdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external nonReentrant() whenNotPaused() {
        require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
        require(amount > fee, 'Amount must be greater than fee');
        require(!kappaMap[kappa], 'Kappa is already present');
        kappaMap[kappa] = true;
        fees[address(token)] = fees[address(token)].add(fee);
        if (address(token) == WETH_ADDRESS && WETH_ADDRESS != address(0)) {
            IWETH9(WETH_ADDRESS).withdraw(amount.sub(fee));
            (bool success, ) = to.call{value: amount.sub(fee)}("");
            require(success, "ETH_TRANSFER_FAILED");
            emit TokenWithdraw(to, token, amount, fee, kappa);
        } else {
            emit TokenWithdraw(to, token, amount, fee, kappa);
            token.safeTransfer(to, amount.sub(fee));
        }
    }


    /**
     * @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to). This is called by the nodes after a TokenDeposit event is emitted.
   * @dev This means the SynapseBridge.sol contract must have minter access to the token attempting to be minted
   * @param to address on other chain to redeem underlying assets to
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain post-fees
   * @param fee Amount in native token decimals to save to the contract as fees
   * @param kappa kappa
   **/
    function mint(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external nonReentrant() whenNotPaused() {
        require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
        require(amount > fee, 'Amount must be greater than fee');
        require(!kappaMap[kappa], 'Kappa is already present');
        kappaMap[kappa] = true;
        fees[address(token)] = fees[address(token)].add(fee);
        emit TokenMint(to, token, amount.sub(fee), fee, kappa);
        token.mint(address(this), amount);
        IERC20(token).safeTransfer(to, amount.sub(fee));
        if (chainGasAmount != 0 && address(this).balance > chainGasAmount) {
            to.transfer(chainGasAmount);
        }
    }

    /**
     * @notice Relays to nodes to both transfer an ERC20 token cross-chain, and then have the nodes execute a swap through a liquidity pool on behalf of the user.
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   * @param tokenIndexFrom the token the user wants to swap from
   * @param tokenIndexTo the token the user wants to swap to
   * @param minDy the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.
   * @param deadline latest timestamp to accept this transaction
   **/
    function depositAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external nonReentrant() whenNotPaused() {
        emit TokenDepositAndSwap(
            to,
            chainId,
            token,
            amount,
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline
        );
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   * @param tokenIndexFrom the token the user wants to swap from
   * @param tokenIndexTo the token the user wants to swap to
   * @param minDy the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.
   * @param deadline latest timestamp to accept this transaction
   **/
    function redeemAndSwap(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external nonReentrant() whenNotPaused() {
        emit TokenRedeemAndSwap(
            to,
            chainId,
            token,
            amount,
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline
        );
        token.burnFrom(msg.sender, amount);
    }

    /**
     * @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   * @param swapTokenIndex Specifies which of the underlying LP assets the nodes should attempt to redeem for
   * @param swapMinAmount Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap
   * @param swapDeadline Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token
   **/
    function redeemAndRemove(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline
    ) external nonReentrant() whenNotPaused() {
        emit TokenRedeemAndRemove(
            to,
            chainId,
            token,
            amount,
            swapTokenIndex,
            swapMinAmount,
            swapDeadline
        );
        token.burnFrom(msg.sender, amount);
    }

    /**
     * @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to), and then attempt to swap the SynERC20 into the desired destination asset. This is called by the nodes after a TokenDepositAndSwap event is emitted.
   * @dev This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted
   * @param to address on other chain to redeem underlying assets to
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain post-fees
   * @param fee Amount in native token decimals to save to the contract as fees
   * @param pool Destination chain's pool to use to swap SynERC20 -> Asset. The nodes determine this by using PoolConfig.sol.
   * @param tokenIndexFrom Index of the SynERC20 asset in the pool
   * @param tokenIndexTo Index of the desired final asset
   * @param minDy Minumum amount (in final asset decimals) that must be swapped for, otherwise the user will receive the SynERC20.
   * @param deadline Epoch time of the deadline that the swap is allowed to be executed.
   * @param kappa kappa
   **/
    function mintAndSwap(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        IMetaSwapDeposit pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bytes32 kappa
    ) external nonReentrant() whenNotPaused() {
        require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
        require(amount > fee, 'Amount must be greater than fee');
        require(!kappaMap[kappa], 'Kappa is already present');
        kappaMap[kappa] = true;
        fees[address(token)] = fees[address(token)].add(fee);
        // Transfer gas airdrop
        if (chainGasAmount != 0 && address(this).balance > chainGasAmount) {
            to.transfer(chainGasAmount);
        }
        // first check to make sure more will be given than min amount required
        uint256 expectedOutput = IMetaSwapDeposit(pool).calculateSwap(
            tokenIndexFrom,
            tokenIndexTo,
            amount.sub(fee)
        );

        if (expectedOutput >= minDy) {
            // proceed with swap
            token.mint(address(this), amount);
            token.safeIncreaseAllowance(address(pool), amount);
            try
            IMetaSwapDeposit(pool).swap(
                tokenIndexFrom,
                tokenIndexTo,
                amount.sub(fee),
                minDy,
                deadline
            )
            returns (uint256 finalSwappedAmount) {
                // Swap succeeded, transfer swapped asset
                IERC20 swappedTokenTo = IMetaSwapDeposit(pool).getToken(tokenIndexTo);
                if (address(swappedTokenTo) == WETH_ADDRESS && WETH_ADDRESS != address(0)) {
                    IWETH9(WETH_ADDRESS).withdraw(finalSwappedAmount);
                    (bool success, ) = to.call{value: finalSwappedAmount}("");
                    require(success, "ETH_TRANSFER_FAILED");
                    emit TokenMintAndSwap(to, token, finalSwappedAmount, fee, tokenIndexFrom, tokenIndexTo, minDy, deadline, true, kappa);
                } else {
                    swappedTokenTo.safeTransfer(to, finalSwappedAmount);
                    emit TokenMintAndSwap(to, token, finalSwappedAmount, fee, tokenIndexFrom, tokenIndexTo, minDy, deadline, true, kappa);
                }
            } catch {
                IERC20(token).safeTransfer(to, amount.sub(fee));
                emit TokenMintAndSwap(to, token, amount.sub(fee), fee, tokenIndexFrom, tokenIndexTo, minDy, deadline, false, kappa);
            }
        } else {
            token.mint(address(this), amount);
            IERC20(token).safeTransfer(to, amount.sub(fee));
            emit TokenMintAndSwap(to, token, amount.sub(fee), fee, tokenIndexFrom, tokenIndexTo, minDy, deadline, false, kappa);
        }
    }

    /**
     * @notice Function to be called by the node group to withdraw the underlying assets from the contract
   * @param to address on chain to send underlying assets to
   * @param token ERC20 compatible token to withdraw from the bridge
   * @param amount Amount in native token decimals to withdraw
   * @param fee Amount in native token decimals to save to the contract as fees
   * @param pool Destination chain's pool to use to swap SynERC20 -> Asset. The nodes determine this by using PoolConfig.sol.
   * @param swapTokenIndex Specifies which of the underlying LP assets the nodes should attempt to redeem for
   * @param swapMinAmount Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap
   * @param swapDeadline Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token
   * @param kappa kappa
   **/
    function withdrawAndRemove(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        ISwap pool,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bytes32 kappa
    ) external nonReentrant() whenNotPaused() {
        require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
        require(amount > fee, 'Amount must be greater than fee');
        require(!kappaMap[kappa], 'Kappa is already present');
        kappaMap[kappa] = true;
        fees[address(token)] = fees[address(token)].add(fee);
        // first check to make sure more will be given than min amount required
        uint256 expectedOutput = ISwap(pool).calculateRemoveLiquidityOneToken(
            amount.sub(fee),
            swapTokenIndex
        );

        if (expectedOutput >= swapMinAmount) {
            token.safeIncreaseAllowance(address(pool), amount.sub(fee));
            try
            ISwap(pool).removeLiquidityOneToken(
                amount.sub(fee),
                swapTokenIndex,
                swapMinAmount,
                swapDeadline
            )
            returns (uint256 finalSwappedAmount) {
                // Swap succeeded, transfer swapped asset
                IERC20 swappedTokenTo = ISwap(pool).getToken(swapTokenIndex);
                swappedTokenTo.safeTransfer(to, finalSwappedAmount);
                emit TokenWithdrawAndRemove(to, token, finalSwappedAmount, fee, swapTokenIndex, swapMinAmount, swapDeadline, true, kappa);
            } catch {
                IERC20(token).safeTransfer(to, amount.sub(fee));
                emit TokenWithdrawAndRemove(to, token, amount.sub(fee), fee, swapTokenIndex, swapMinAmount, swapDeadline, false, kappa);
            }
        } else {
            token.safeTransfer(to, amount.sub(fee));
            emit TokenWithdrawAndRemove(to, token, amount.sub(fee), fee, swapTokenIndex, swapMinAmount, swapDeadline, false, kappa);
        }
    }
}
