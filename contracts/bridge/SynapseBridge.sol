// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/ISwap.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IRateLimiter.sol";
import "hardhat/console.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract SynapseBridge is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Mintable;
    using SafeMath for uint256;

    bytes32 public constant NODEGROUP_ROLE = keccak256("NODEGROUP_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    mapping(address => uint256) private fees;

    uint256 public startBlockNumber;
    uint256 public constant bridgeVersion = 7;
    uint256 public chainGasAmount;
    address payable public WETH_ADDRESS;

    mapping(bytes32 => bool) private kappaMap;

    // rate limiter
    IRateLimiter public rateLimiter;

    // new role

    bytes32 public constant RATE_LIMITER_ROLE = keccak256("RATE_LIMITER_ROLE");

    receive() external payable {}

    function initialize() external initializer {
        startBlockNumber = block.number;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();
    }

    function setChainGasAmount(uint256 amount) external {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
        chainGasAmount = amount;
    }

    function setWethAddress(address payable _wethAddress) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        WETH_ADDRESS = _wethAddress;
    }

    function setRateLimiter(IRateLimiter _rateLimiter) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        rateLimiter = _rateLimiter;
    }

    function addKappas(bytes32[] calldata kappas) external {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
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

    // v2 events
    event TokenRedeemV2(
        bytes32 indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    );

    // VIEW FUNCTIONS ***/
    function getFeeBalance(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return fees[tokenAddress];
    }

    function kappaExists(bytes32 kappa) external view returns (bool) {
        return kappaMap[kappa];
    }

    // FEE FUNCTIONS ***/
    /**
     * * @notice withdraw specified ERC20 token fees to a given address
     * * @param token ERC20 token in which fees acccumulated to transfer
     * * @param to Address to send the fees to
     */
    function withdrawFees(IERC20 token, address to) external whenNotPaused {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
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

    // RATE LIMITER FUNCTIONS ***/
    // @dev check and update the rate limiter allowances. Bypass the rate limiter
    // if it is a 0-address
    function isRateLimited(address token, uint256 amount)
        internal
        returns (bool)
    {
        if (address(rateLimiter) == address(0)) {
            return false;
        }

        return rateLimiter.checkAndUpdateAllowance(address(token), amount);
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
        uint256 amount
    ) external nonReentrant whenNotPaused {
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
    ) external nonReentrant whenNotPaused {
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
    ) external nonReentrant whenNotPaused {
        require(
            hasRole(NODEGROUP_ROLE, msg.sender),
            "Caller is not a node group"
        );

        bool rateLimited = isRateLimited(address(token), amount);
        if (rateLimited) {
            rateLimiter.addToRetryQueue(
                kappa,
                abi.encodeWithSelector(
                    this.retryWithdraw.selector,
                    to,
                    address(token),
                    amount,
                    fee,
                    kappa
                )
            );
            return;
        }

        doWithdraw(to, token, amount, fee, kappa);
    }

    /**
     * @notice Function to be called by the rate limiter to retry a withdraw bypassing the rate limiter
     * @param to address on chain to send underlying assets to
     * @param token ERC20 compatible token to withdraw from the bridge
     * @param amount Amount in native token decimals to withdraw
     * @param fee Amount in native token decimals to save to the contract as fees
     * @param kappa kappa
     **/
    function retryWithdraw(
        address to,
        address token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external nonReentrant whenNotPaused {
        require(
            hasRole(RATE_LIMITER_ROLE, msg.sender),
            "Caller is not rate limiter"
        );

        doWithdraw(to, IERC20(token), amount, fee, kappa);
    }

    // doWithdraw bypasses the rate limiter. See withdraw for documentation
    function doWithdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) internal {
        require(amount > fee, "Amount must be greater than fee");
        require(!kappaMap[kappa], "Kappa is already present");
        kappaMap[kappa] = true;
        fees[address(token)] = fees[address(token)].add(fee);

        // withdraw can happen on chains other than mainnet
        doGasAirdrop(to);

        // apply fee
        amount = amount.sub(fee);

        // If token is WGAS, this will send native chain GAS
        transferTokenWithUnwrap(to, token, amount);
        emit TokenWithdraw(to, token, amount, fee, kappa);
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
    ) external nonReentrant whenNotPaused {
        require(
            hasRole(NODEGROUP_ROLE, msg.sender),
            "Caller is not a node group"
        );

        bool rateLimited = isRateLimited(address(token), amount);
        if (rateLimited) {
            rateLimiter.addToRetryQueue(
                kappa,
                abi.encodeWithSelector(
                    this.retryMint.selector,
                    to,
                    address(token),
                    amount,
                    fee,
                    kappa
                )
            );
            return;
        }

        doMint(to, token, amount, fee, kappa);
    }

    /**
     * @notice Rate Limiter call this function to retry a mint of a SynERC20 (or any asset that the bridge is given minter access to). This is called by the nodes after a TokenDeposit event is emitted.
     * @dev This means the SynapseBridge.sol contract must have minter access to the token attempting to be minted
     * @param to address on other chain to redeem underlying assets to
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain post-fees
     * @param fee Amount in native token decimals to save to the contract as fees
     * @param kappa kappa
     **/
    function retryMint(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external nonReentrant whenNotPaused {
        require(
            hasRole(RATE_LIMITER_ROLE, msg.sender),
            "Caller is not a node group"
        );

        doMint(to, token, amount, fee, kappa);
    }

    function doMint(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) internal {
        require(amount > fee, "Amount must be greater than fee");
        require(!kappaMap[kappa], "Kappa is already present");
        kappaMap[kappa] = true;
        fees[address(token)] = fees[address(token)].add(fee);
        doGasAirdrop(to);

        token.mint(address(this), amount);
        // apply fee
        amount = amount.sub(fee);
        IERC20(token).safeTransfer(to, amount);

        emit TokenMint(to, token, amount, fee, kappa);
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
    ) external nonReentrant whenNotPaused {
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
    ) external nonReentrant whenNotPaused {
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
    ) external nonReentrant whenNotPaused {
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
    ) external nonReentrant whenNotPaused {
        require(
            hasRole(NODEGROUP_ROLE, msg.sender),
            "Caller is not a node group"
        );

        bool rateLimited = isRateLimited(address(token), amount);
        if (rateLimited) {
            rateLimiter.addToRetryQueue(
                kappa,
                abi.encodeWithSelector(
                    this.retryMintAndSwap.selector,
                    to,
                    address(token),
                    amount,
                    fee,
                    address(pool),
                    tokenIndexFrom,
                    tokenIndexTo,
                    minDy,
                    deadline,
                    kappa
                )
            );
            return;
        }

        doMintAndSwap(
            to,
            token,
            amount,
            fee,
            pool,
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline,
            kappa
        );
    }

    /**
     * @notice RateLimiter call this function to retry a mint of a SynERC20 (or any asset that the bridge is given minter access to), and then attempt to swap the SynERC20 into the desired destination asset. This is called by the nodes after a TokenDepositAndSwap event is emitted.
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
    function retryMintAndSwap(
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
    ) external nonReentrant whenNotPaused {
        require(
            hasRole(RATE_LIMITER_ROLE, msg.sender),
            "Caller is not a node group"
        );

        doMintAndSwap(
            to,
            token,
            amount,
            fee,
            pool,
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline,
            kappa
        );
    }

    function doMintAndSwap(
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
    ) internal {
        require(amount > fee, "Amount must be greater than fee");
        require(!kappaMap[kappa], "Kappa is already present");
        kappaMap[kappa] = true;
        fees[address(token)] = fees[address(token)].add(fee);
        // Transfer gas airdrop
        doGasAirdrop(to);

        // proceed with swap
        token.mint(address(this), amount);
        // apply fee
        amount = amount.sub(fee);
        token.safeIncreaseAllowance(address(pool), amount);
        try
            ISwap(pool).swap(
                tokenIndexFrom,
                tokenIndexTo,
                amount,
                minDy,
                deadline
            )
        returns (uint256 finalSwappedAmount) {
            // Swap succeeded, transfer swapped asset
            IERC20 swappedTokenTo = ISwap(pool).getToken(tokenIndexTo);
            // If token is WGAS, this will send native chain GAS
            transferTokenWithUnwrap(to, swappedTokenTo, finalSwappedAmount);
            emit TokenMintAndSwap(
                to,
                token,
                finalSwappedAmount,
                fee,
                tokenIndexFrom,
                tokenIndexTo,
                minDy,
                deadline,
                true,
                kappa
            );
        } catch {
            token.safeTransfer(to, amount);
            emit TokenMintAndSwap(
                to,
                token,
                amount,
                fee,
                tokenIndexFrom,
                tokenIndexTo,
                minDy,
                deadline,
                false,
                kappa
            );
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
    ) external nonReentrant whenNotPaused {
        require(
            hasRole(NODEGROUP_ROLE, msg.sender),
            "Caller is not a node group"
        );

        bool rateLimited = isRateLimited(address(token), amount);

        if (rateLimited) {
            rateLimiter.addToRetryQueue(
                kappa,
                abi.encodeWithSelector(
                    this.retryWithdrawAndRemove.selector,
                    to,
                    address(token),
                    amount,
                    fee,
                    address(pool),
                    swapTokenIndex,
                    swapMinAmount,
                    swapDeadline,
                    kappa
                )
            );
            return;
        }

        doWithdrawAndRemove(
            to,
            token,
            amount,
            fee,
            pool,
            swapTokenIndex,
            swapMinAmount,
            swapDeadline,
            kappa
        );
    }

    /**
     * @notice Function to be called by the rate limiter to retry a withdraw of the underlying assets from the contract
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
    function retryWithdrawAndRemove(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        ISwap pool,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bytes32 kappa
    ) external nonReentrant whenNotPaused {
        require(
            hasRole(RATE_LIMITER_ROLE, msg.sender),
            "Caller is not a node group"
        );

        doWithdrawAndRemove(
            to,
            token,
            amount,
            fee,
            pool,
            swapTokenIndex,
            swapMinAmount,
            swapDeadline,
            kappa
        );
    }

    // allows withdrawAndRemove retries to bypass rate limiter
    function doWithdrawAndRemove(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        ISwap pool,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bytes32 kappa
    ) internal {
        require(amount > fee, "Amount must be greater than fee");
        require(!kappaMap[kappa], "Kappa is already present");
        kappaMap[kappa] = true;
        // apply fees
        fees[address(token)] = fees[address(token)].add(fee);
        amount = amount.sub(fee);

        // withdrawAndRemove only on Mainnet => no airdrop

        token.safeIncreaseAllowance(address(pool), amount);
        try
            ISwap(pool).removeLiquidityOneToken(
                amount,
                swapTokenIndex,
                swapMinAmount,
                swapDeadline
            )
        returns (uint256 finalSwappedAmount) {
            // Swap succeeded, transfer swapped asset
            IERC20 swappedTokenTo = ISwap(pool).getToken(swapTokenIndex);
            swappedTokenTo.safeTransfer(to, finalSwappedAmount);
            emit TokenWithdrawAndRemove(
                to,
                token,
                finalSwappedAmount,
                fee,
                swapTokenIndex,
                swapMinAmount,
                swapDeadline,
                true,
                kappa
            );
        } catch {
            token.safeTransfer(to, amount);
            emit TokenWithdrawAndRemove(
                to,
                token,
                amount,
                fee,
                swapTokenIndex,
                swapMinAmount,
                swapDeadline,
                false,
                kappa
            );
        }
    }

    // TOKEN TRANSFER

    function transferTokenWithUnwrap(
        address to,
        IERC20 token,
        uint256 amount
    ) internal {
        if (address(token) == WETH_ADDRESS && WETH_ADDRESS != address(0)) {
            IWETH9(WETH_ADDRESS).withdraw(amount);
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH_TRANSFER_FAILED");
        } else {
            token.safeTransfer(to, amount);
        }
    }

    // GAS AIRDROP

    function doGasAirdrop(address to) internal {
        if (chainGasAmount != 0 && address(this).balance >= chainGasAmount) {
            to.call{value: chainGasAmount}("");
        }
    }

    // BRIDGE FUNCTIONS TO HANDLE DIFF ADDRESSES
    /**
     * @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function redeemV2(
        bytes32 to,
        uint256 chainId,
        ERC20Burnable token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        emit TokenRedeemV2(to, chainId, token, amount);
        token.burnFrom(msg.sender, amount);
    }
}
