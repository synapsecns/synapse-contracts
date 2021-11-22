// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import {SafeMath} from '@openzeppelin/contracts/math/SafeMath.sol';
import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

import {ISwap} from '../interfaces/ISwap.sol';
import {IWETH9} from '../interfaces/IWETH9.sol';
import {IERC20Mintable} from '../interfaces/IERC20Mintable.sol';


abstract contract SynapseBridgeBase is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Mintable;
    using SafeMath  for uint256;

    bytes32 public constant NODEGROUP_ROLE  = 0xb5c00e6706c3d213edd70ff33717fac657eacc5fe161f07180cf1fcab13cc4cd; // keccak256('NODEGROUP_ROLE')
    bytes32 public constant GOVERNANCE_ROLE = 0x71840dc4906352362b0cdaf79870196c8e42acafade72d5d5a6d59291253ceb1; // keccak256('GOVERNANCE_ROLE');

    mapping(address => uint256) internal fees;

    uint256 public startBlockNumber;
    uint256 public constant bridgeVersion = 6;
    uint256 public chainGasAmount;
    address payable public WETH_ADDRESS;

    mapping(bytes32 => bool) internal kappaMap;

    function __SynapseBridgeBase_init()
        internal
        initializer
    {
        __SynapseBridgeBase_init_unchained();
        __AccessControl_init();
    }

    function __SynapseBridgeBase_init_unchained()
        internal
        initializer
    {
        startBlockNumber = block.number;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not admin"
        );

        _;
    }

    modifier onlyGovernance() {
        require(
            hasRole(GOVERNANCE_ROLE, msg.sender),
            "Not governance"
        );

        _;
    }

    modifier onlyNodeGroup() {
        require(
            hasRole(NODEGROUP_ROLE, msg.sender),
            "Caller is not a node group"
        );

        _;
    }

    modifier validOutTxn(
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    )
    {
        require(
            amount > fee,
            'Amount must be greater than fee'
        );

        require(
            !kappaMap[kappa],
            'Kappa is already present'
        );

        _;
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

    receive() external payable {}

    // admin/governance -only functions. All write to contract storage.

    function setChainGasAmount(uint256 amount)
        external
        onlyGovernance
    {
        chainGasAmount = amount;
    }

    function setWethAddress(address payable _wethAddress)
        external
        onlyAdmin
    {
        WETH_ADDRESS = _wethAddress;
    }

    function addKappas(bytes32[] calldata kappas)
        external
        onlyGovernance
    {
        for (uint256 i = 0; i < kappas.length; ++i) {
            kappaMap[kappas[i]] = true;
        }
    }

    // PAUSABLE FUNCTIONS ***/
    function pause()
        external
        onlyGovernance
    {
        _pause();
    }

    function unpause()
        external
        onlyGovernance
    {
        _unpause();
    }

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

    // FEE FUNCTIONS ***/
    /**
    * * @notice withdraw specified ERC20 token fees to a given address
    * * @param token ERC20 token in which fees acccumulated to transfer
    * * @param to Address to send the fees to
    */
    function withdrawFees(IERC20 token, address to)
        external
        whenNotPaused
        onlyGovernance
    {
        require(to != address(0), "Address is 0x000");

        uint256 _tokenFees = fees[_tokenAddress];

        if (_tokenFees != 0) {
            address _tokenAddress = address(token);

            token.safeTransfer(to, _tokenFees);
            fees[_tokenAddress] = 0;
        }
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
    )
        external
        nonReentrant
        whenNotPaused
    {
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
        nonReentrant
        whenNotPaused
        onlyNodeGroup
        validOutTxn(amount, fee, kappa)
    {
        (address _tokenAddress, uint256 _amt) = _preOutTxn(token, amount, fee, kappa);

        if (_validWETHAddress(_tokenAddress))
        {
            _sendWETH(payable(to), _amt);

            emit TokenWithdraw(to, token, amount, fee, kappa);
        } else
        {
            emit TokenWithdraw(to, token, amount, fee, kappa);
            token.safeTransfer(to, _amt);
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
    )
        external
        nonReentrant
        whenNotPaused
        onlyNodeGroup
        validOutTxn(amount, fee, kappa)
    {
        _mint(to, token, amount, fee, kappa);
    }

    function _mint(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) internal virtual;

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
        nonReentrant
        whenNotPaused
        onlyNodeGroup
        validOutTxn(amount, fee, kappa)
    {
        (,uint256 _amt) = _preOutTxn(token, amount, fee, kappa);

        _gasDrop(to);

        // first check to make sure more will be given than min amount required
        uint256 expectedOutput = pool.calculateSwap(
            tokenIndexFrom,
            tokenIndexTo,
            _amt
        );

        if (expectedOutput >= minDy) {
            // proceed with swap
            token.mint(address(this), amount);
            token.safeIncreaseAllowance(address(pool), amount);

            try pool.swap(
                tokenIndexFrom,
                tokenIndexTo,
                _amt,
                minDy,
                deadline
            )
            returns (uint256 finalSwappedAmount) {
                // Swap succeeded, transfer swapped asset
                IERC20 swappedTokenTo = pool.getToken(tokenIndexTo);

                if (_validWETHAddress(address(swappedTokenTo)))
                {
                    _sendWETH(to, finalSwappedAmount);

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
                } else
                {
                    _mintAndSwapTokenTransfer(
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
                }
            } catch
            {
                _mintAndSwapTokenTransfer(
                    to,
                    token,
                    _amt,
                    fee,
                    tokenIndexFrom,
                    tokenIndexTo,
                    minDy,
                    deadline,
                    false,
                    kappa
                );
            }
        } else
        {
            token.mint(address(this), amount);
            _mintAndSwapTokenTransfer(
                to,
                token,
                _amt,
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

    function _mintAndSwapTokenTransfer(
        address to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bool swapSuccess,
        bytes32 kappa
    )
        internal
    {
        IERC20(token).safeTransfer(to, amount);

        emit TokenMintAndSwap(
            to,
            token,
            amount,
            fee,
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline,
            swapSuccess,
            kappa
        );
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
        nonReentrant
        whenNotPaused
        onlyNodeGroup
        validOutTxn(amount, fee, kappa)
    {
        (address _tokenAddress, uint256 _amt) = _preOutTxn(token, amount, fee, kappa);

        // first check to make sure more will be given than min amount required
        uint256 expectedOutput = pool.calculateRemoveLiquidityOneToken(
            _amt,
            swapTokenIndex
        );

        if (expectedOutput >= swapMinAmount) {
            token.safeIncreaseAllowance(address(pool), _amt);

            try
            pool.removeLiquidityOneToken(
                _amt,
                swapTokenIndex,
                swapMinAmount,
                swapDeadline
            )
            returns (uint256 finalSwappedAmount)
            {
                // Swap succeeded, transfer swapped asset
                IERC20 swappedTokenTo = pool.getToken(swapTokenIndex);
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
            } catch
            {
                _withdrawAndRemoveTokenTransfer(
                    to,
                    token,
                    _amt,
                    fee,
                    swapTokenIndex,
                    swapMinAmount,
                    swapDeadline,
                    false,
                    kappa
                );
            }
        } else
        {
            _withdrawAndRemoveTokenTransfer(
                to,
                token,
                _amt,
                fee,
                swapTokenIndex,
                swapMinAmount,
                swapDeadline,
                false,
                kappa
            );
        }
    }

    function _withdrawAndRemoveTokenTransfer(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bool swapSuccess,
        bytes32 kappa
    )
        internal
    {
        token.safeTransfer(to, amount);

        emit TokenWithdrawAndRemove(
            to,
            token,
            amount,
            fee,
            swapTokenIndex,
            swapMinAmount,
            swapDeadline,
            swapSuccess,
             kappa
        );
    }

    function _sendWETH(
        address payable _to,
        uint256 _amt
    )
        internal
    {
        IWETH9(WETH_ADDRESS).withdraw(_amt);

        (bool success,) = _to.call{value: _amt}("");

        require(success, "ETH_TRANSFER_FAILED");
    }

    /**
     * @notice Called by functions which are sending tokens or ETH to an address.
     * @dev _preOutTxn will add the transaction's kappa to kappaMap, and add the fee amount to our fee map.
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain post-fees
     * @param fee Amount in native token decimals to save to the contract as fees
     * @param kappa kappa
     **/
    function _preOutTxn(
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    )
        internal
        returns (
            address _tokenAddress,
            uint256 _amt
        )
    {
        _tokenAddress = address(token);
        _amt = amount.sub(fee);

        kappaMap[kappa] = true;
        fees[_tokenAddress] = fees[_tokenAddress].add(fee);

        return (_tokenAddress, _amt);
    }

    function _gasDrop(address payable to)
        internal
    {
        // Transfer gas airdrop
        if (chainGasAmount != 0 && address(this).balance > chainGasAmount) {
            to.call.value(chainGasAmount)("");
        }
    }

    function _validWETHAddress(address _addr)
        internal
        view
        returns (bool)
    {
        return WETH_ADDRESS != address(0) && _addr == WETH_ADDRESS;
    }

    function _makeBurnableERC20(IERC20 token)
        internal
        pure
        returns (ERC20Burnable)
    {
        return ERC20Burnable(address(token));
    }
}