// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;


import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

import {IWETH9} from "./interfaces/IWETH9.sol";
import {IERC20Mintable} from "./interfaces/IERC20Mintable.sol";

import {ISwap} from "./interfaces/ISwap.sol";
import {IRouter} from "./interfaces/IRouter.sol";

contract SynapseBridge is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Mintable;

    bytes32 public constant NODEGROUP_ROLE = keccak256("NODEGROUP_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    mapping(address => uint256) private fees;

    uint256 public startBlockNumber;
    uint256 public constant bridgeVersion = 6;
    uint256 public chainGasAmount;
    address payable public WETH_ADDRESS;

    mapping(bytes32 => bool) private kappaMap;

    receive() external payable {}

    function initialize() external initializer {
        startBlockNumber = block.number;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();
    }

    modifier adminOnly() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not admin"
        );

        _;
    }

    modifier governanceOnly() {
        require(
            hasRole(GOVERNANCE_ROLE, msg.sender),
            "Not governance"
        );

        _;
    }

    modifier nodegroupOnly() {
        require(
            hasRole(NODEGROUP_ROLE, msg.sender),
            "Caller is not a node group"
        );

        _;
    }

    function setChainGasAmount(uint256 amount)
        governanceOnly
        external
    {
        chainGasAmount = amount;
    }

    function setWethAddress(address payable _wethAddress)
        adminOnly
        external
    {
        WETH_ADDRESS = _wethAddress;
    }

    function addKappas(bytes32[] calldata kappas)
        governanceOnly
        external
    {
        for (uint256 i = 0; i < kappas.length; ++i) {
            kappaMap[kappas[i]] = true;
        }
    }

    event TokenDeposit(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    );
    event TokenRedeem(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    );
    event TokenWithdraw(
        address indexed to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 indexed kappa
    );
    event TokenMint(
        address indexed to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        bytes32 indexed kappa
    );
    event TokenDepositAndSwap(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenMintAndSwap(
        address indexed to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bool swapSuccess,
        bytes32 indexed kappa
    );
    event TokenRedeemAndSwap(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenRedeemAndRemove(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline
    );
    event TokenWithdrawAndRemove(
        address indexed to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bool swapSuccess,
        bytes32 indexed kappa
    );


    // VIEW FUNCTIONS ***/
    function getFeeBalance(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return fees[tokenAddress];
    }

    function kappaExists(bytes32 kappa)
        external
        view
        returns (bool)
    {
        return kappaMap[kappa];
    }

    function checkChainGasAmount()
        internal
        view
        returns (bool)
    {
        return chainGasAmount != 0 && address(this).balance >= chainGasAmount;
    }

    function getMaxAmount(IERC20 token)
        internal
        view
        returns (uint256)
    {
        uint256 allowance = token.allowance(msg.sender, address(this));
        uint256 tokenBalance = token.balanceOf(msg.sender);
        return (allowance > tokenBalance) ? tokenBalance : allowance;
    }

    // FEE FUNCTIONS ***/
    /**
     * * @notice withdraw specified ERC20 token fees to a given address
     * * @param token ERC20 token in which fees acccumulated to transfer
     * * @param to Address to send the fees to
     */
    function withdrawFees(IERC20 token, address to)
        external
        governanceOnly
        whenNotPaused
    {
        require(to != address(0), "Address is 0x000");
        if (fees[address(token)] != 0) {
            token.safeTransfer(to, fees[address(token)]);
            fees[address(token)] = 0;
        }
    }

    // PAUSABLE FUNCTIONS ***/
    function pause() external {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
        _pause();
    }

    function unpause() external {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
        _unpause();
    }

    // ******* STANDARD FUNCTIONS

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
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
    {
        _deposit(to, chainId, token, amount);
    }

    /**
     * @notice Relays to nodes to transfers an ERC20 token cross-chain
     * @param to address on other chain to bridge assets to
     * @param chainId which chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     **/
    function depositMax(
        address to,
        uint256 chainId,
        IERC20 token
    )
        external
        nonReentrant
        whenNotPaused
    {
        _deposit(to, chainId, token, getMaxAmount(token));
    }

    function _deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) internal {
        emit TokenDeposit(to, chainId, token, amount);
        token.safeTransferFrom(msg.sender, address(this), amount);
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
    )
        external
        nonReentrant
        whenNotPaused
    {
        _redeem(to, chainId, token, amount);
    }

    /**
     * @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     **/
    function redeemMax(
        address to,
        uint256 chainId,
        ERC20Burnable token
    )
        external
        nonReentrant
        whenNotPaused
    {
        _redeem(to, chainId, token, getMaxAmount(token));
    }

    function _redeem(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    ) internal {
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
    )
        external
        nodegroupOnly
        nonReentrant
        whenNotPaused
    {
        uint256 amountSubFee = _preBridge(payable(to), token, amount, fee, kappa);

        transferToken(to, token, amountSubFee);
        emit TokenWithdraw(to, token, amount, fee, kappa);

        kappaMap[kappa] = true;
    }

    /**
     * @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to). This is called by the nodes after a TokenDepositV2 event is emitted.
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
    )
        external
        nodegroupOnly
        nonReentrant
        whenNotPaused
    {
        uint256 amountSubFee = _preBridge(to, token, amount, fee, kappa);

        emit TokenMint(to, token, amountSubFee, fee, kappa);
        token.mint(to, amountSubFee);
        token.mint(address(this), fee);

        kappaMap[kappa] = true;
    }

    // ******* V1 FUNCTIONS

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
    )
        external
        nonReentrant
        whenNotPaused
    {
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
    )
        external
        nonReentrant
        whenNotPaused
    {
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
    )
        external
        nonReentrant
        whenNotPaused
    {
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
        ISwap pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bytes32 kappa
    )
        external
        nodegroupOnly
        nonReentrant
        whenNotPaused
    {
        uint256 amountSubFee = _preBridge(to, token, amount, fee, kappa);
        {
            _mintToken(pool, token, amount, amountSubFee);
        }

        (bool swapSuccess, uint256 _swapAmt) = _poolSwap(pool, tokenIndexFrom, tokenIndexTo, amountSubFee, minDy, deadline);
        {
            _onSwapResult(to, pool, token, tokenIndexTo, _swapAmt, swapSuccess);
        }

        emit TokenMintAndSwap(
            to,
            token,
            _swapAmt,
            fee,
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline,
            swapSuccess,
            kappa
        );

        kappaMap[kappa] = true;
    }

    function _poolSwap(
        ISwap pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 amountSubFee,
        uint256 minDy,
        uint256 deadline
    )
        internal
        returns (bool, uint256)
    {
        try pool.swap(
            tokenIndexFrom,
            tokenIndexTo,
            amountSubFee,
            minDy,
            deadline
        ) returns (uint256 finalSwappedAmount) {
            // Swap succeeded, transfer swapped asset
            return (true, finalSwappedAmount);
        } catch {
            // Swap failed, transfer minted token instead
            // Additionally, revoke unspent allowance
            return (false, amountSubFee);
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
    )
        external
        nodegroupOnly
        nonReentrant
        whenNotPaused
    {
        address payable _payableTo = payable(to);
        uint256 amountSubFee = _preBridge(_payableTo, token, amount, fee, kappa);

        // We don't need to check expected output, as
        // removeLiquidityOneToken()  will revert if the output amount is too small
        {
            token.safeIncreaseAllowance(address(pool), amountSubFee);
        }


        (bool swapSuccess, uint256 _swapAmt) = _poolRemoveLiquidity(pool, swapTokenIndex, amountSubFee, swapMinAmount, swapDeadline);
        _onSwapResult(_payableTo, pool, token, swapTokenIndex, _swapAmt, swapSuccess);

        emit TokenWithdrawAndRemove(
            to,
            token,
            _swapAmt,
            fee,
            swapTokenIndex,
            swapMinAmount,
            swapDeadline,
            swapSuccess,
            kappa
        );

        kappaMap[kappa] = true;
    }

    function _poolRemoveLiquidity(
        ISwap pool,
        uint8 swapTokenIndex,
        uint256 amountSubFee,
        uint256 swapMinAmount,
        uint256 swapDeadline
    )
        internal
        returns (bool, uint256)
    {
        try pool.removeLiquidityOneToken(
            amountSubFee,
            swapTokenIndex,
            swapMinAmount,
            swapDeadline
        ) returns (uint256 finalSwappedAmount) {
            // Swap succeeded, transfer swapped asset
            return (true, finalSwappedAmount);
        } catch {
            // Swap failed, transfer minted token instead
            // Additionally, revoke unspent allowance
            return (false, amountSubFee);
        }
    }

    function transferToken(
        address to,
        IERC20 token,
        uint256 amount
    )
        internal
    {
        if (_validWETHAddress(token)) {
            _transferWETH(to, amount);
            return;
        }

        token.safeTransfer(to, amount);
    }

    function _preBridge(
        address payable to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    )
        internal
        returns (uint256)
    {
        require(amount > fee, "Amount must be greater than fee");
        require(!kappaMap[kappa], "Kappa is already present");

        address _token = address(token);

        uint256 amountSubFee = amount - fee;
        fees[_token] = fees[_token] + fee;

        _doGasDrop(to);

        return amountSubFee;
    }

    function _validWETHAddress(IERC20 token)
        internal
        view
        returns (bool)
    {
        return address(token) == WETH_ADDRESS && WETH_ADDRESS != address(0);
    }

    function _transferWETH(address to, uint256 amount)
        internal
    {
        IWETH9(WETH_ADDRESS).withdraw(amount);
        (bool success,) = payable(to).call{value: amount}("");
        require(
            success,
            "ETH transfer failed"
        );
    }

    function _mintToken(
        ISwap pool,
        IERC20Mintable token,
        uint256 amount,
        uint256 amountSubFee
    )
        internal
    {
        // We don't need to check expected output amount,
        // as swap() will revert if the output amount is too small
        token.mint(address(this), amount);
        token.safeIncreaseAllowance(address(pool), amountSubFee);
    }

    function _doGasDrop(address payable to)
        internal
    {
        // Transfer gas airdrop
        if (checkChainGasAmount()) {
            (bool success, ) = to.call{value: chainGasAmount}("");
            require(success, "GAS_AIRDROP_FAILED");
        }
    }

    function _onSwapResult(
        address payable to,
        ISwap pool,
        IERC20 _token,
        uint8 tokenIndexTo,
        uint256 amount,
        bool swapSuccess
    )
        internal
    {
        IERC20 token;

        if (swapSuccess) {
            token = pool.getToken(tokenIndexTo);
        } else {
            token = _token;
            token.safeApprove(address(pool), 0);
        }

        transferToken(to, token, amount);
    }
}
