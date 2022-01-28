// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Initializable} from "@openzeppelin/contracts-upgradeable-4.4.2/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable-4.4.2/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable-4.4.2/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable-4.4.2/security/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.4.2/token/ERC20/utils/SafeERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts-4.4.2/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@openzeppelin/contracts-4.4.2/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts-4.4.2/utils/math/SafeMath.sol";

import {IWETH9} from "./interfaces/IWETH9.sol";
import {IERC20Mintable} from "./interfaces/IERC20Mintable.sol";
import {ISynapseBridge} from "./interfaces/ISynapseBridge.sol";


import {ISwap} from "./interfaces-8/ISwap.sol";
import {IRouter} from "./interfaces-8/IRouter.sol";

contract SynapseBridgeV2 is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Mintable;

    bytes32 public constant NODEGROUP_ROLE  = keccak256("NODEGROUP_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    mapping(address => uint256) private fees;

    uint256 public startBlockNumber;
    uint256 public constant bridgeVersion = 1;
    uint256 public chainGasAmount;
    address payable public WETH_ADDRESS;

    mapping(bytes32 => bool) private kappaMap;

    ISynapseBridge public BRIDGE_V1;
    address payable public ROUTER;

    receive() external payable {}

    function initialize(
        ISynapseBridge _bridgeV1,
        address payable _router
    )
        external
        initializer
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();

        startBlockNumber = block.number;

        BRIDGE_V1 = _bridgeV1;
        ROUTER = _router;
    }

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

    modifier validateBridgeFunction(
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    )
    {
        require(
            amount > fee,
            "Amount must be greater than fee"
        );

        require(
            !kappaMap[kappa],
            "Kappa is already present"
        );

        require(
            !BRIDGE_V1.kappaExists(kappa),
            "Kappa is already present"
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

    function setRouterAddress(address _router)
        adminOnly
        external
    {
        ROUTER = _router;
    }

    // ******* V2 FUNCTIONS
    /**
   * @notice Relays to nodes to both transfer an ERC20 token cross-chain, and then have the nodes execute a swap through a liquidity pool on behalf of the user.
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge

   **/
    function depositMaxAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        address[] calldata path,
        address[] calldata adapters,
        uint256 maxBridgeSlippage
    )
        external
        nonReentrant
        whenNotPaused
    {
        uint256 amount = getMaxAmount(token);
        emit TokenDepositAndSwapV2(
            to,
            chainId,
            token,
            amount,
            path,
            adapters,
            maxBridgeSlippage
        );
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
   * @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge

   **/
    function redeemMaxAndSwap(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        address[] calldata path,
        address[] calldata adapters,
        uint256 maxBridgeSlippage
    )
        external
        nonReentrant
        whenNotPaused
    {
        uint256 amount = getMaxAmount(token);
        emit TokenRedeemAndSwapV2(
            to,
            chainId,
            token,
            amount,
            path,
            adapters,
            maxBridgeSlippage
        );
        token.burnFrom(msg.sender, amount);
    }

    function handleRouterSwap(
        address to,
        uint256 amountSubFee,
        RouterTrade calldata _trade
    )
        private
        returns (bool _ok)
    {
        try IRouter(ROUTER).selfSwap(
            amountSubFee,
            0,
            _trade.path,
            _trade.adapters,
            to,
            0
        ) {
            _ok = true;
        } catch {
            _ok = false;
        }
    }

    /**
   * @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to), and then attempt to swap the SynERC20 into the desired destination asset. This is called by the nodes after a TokenDepositAndSwapV2 event is emitted.
   * @dev This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted
   * @param to address on other chain to redeem underlying assets to
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain post-fees
   * @param fee Amount in native token decimals to save to the contract as fees

   * @param kappa kappa
   **/
    function mintAndSwap(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        RouterTrade calldata _trade,
        bytes32 kappa
    )
        external
        nodegroupOnly
        nonReentrant
        whenNotPaused
        validateBridgeFunction(amount, fee, kappa)
    {
        uint256 amountSubFee = amount - fee;
        fees[address(token)] = fees[address(token)] + fee;

        _doGasDrop(to);

        token.mint(ROUTER, amountSubFee);
        token.mint(address(this), fee);

        bool swapSuccess = handleRouterSwap(to, amountSubFee, _trade);
        if (!swapSuccess) {
            token.safeTransferFrom(ROUTER, to, amountSubFee);
        }

        emit TokenMintAndSwapV2(
            to,
            token,
            amountSubFee,
            fee,
            _trade.path,
            _trade.adapters,
            _trade.maxBridgeSlippage,
            swapSuccess,
            kappa
        );

        kappaMap[kappa] = true;
    }

    /**
     * @notice Function to be called by the node group to withdraw the underlying assets from the contract
     * @param to address on chain to send underlying assets to
     * @param token ERC20 compatible token to withdraw from the bridge
     * @param amount Amount in native token decimals to withdraw
     * @param fee Amount in native token decimals to save to the contract as fees
     * @param kappa kappa
     **/
    function withdrawAndSwap(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        RouterTrade calldata _trade,
        bytes32 kappa
    )
        external
        nodegroupOnly
        nonReentrant
        whenNotPaused
        validateBridgeFunction(amount, fee, kappa)
    {
        uint256 amountSubFee = amount - fee;
        fees[address(token)] = fees[address(token)] + fee;

        _doGasDrop(to);

        token.safeTransfer(ROUTER, amountSubFee);
        // (bool success, bytes memory result) = ROUTER.call(routeraction);
        //  if (success) {
        //   // Swap successful
        //   emit TokenWithdrawAndSwapV2(to, token, amount.sub(fee), fee, routeraction, true, kappa);
        // } else {
        //     IERC20(token).safeTransferFrom(ROUTER, to, amount.sub(fee));
        //     emit TokenWithdrawAndSwapV2(to, token, amount.sub(fee), fee, routeraction, false, kappa);
        // }
        bool swapSuccess = handleRouterSwap(to, amountSubFee, _trade);
        if (!swapSuccess) {
            token.safeTransferFrom(ROUTER, to, amountSubFee);
        }

        emit TokenWithdrawAndSwapV2(
            to,
            token,
            amountSubFee,
            fee,
            _trade.path,
            _trade.adapters,
            _trade.maxBridgeSlippage,
            swapSuccess,
            kappa
        );
        // try IRouter(ROUTER).selfSwap(amountSubFee, 0, path, adapters, to, 0) {
        //   emit TokenWithdrawAndSwapV2(to, token, amountSubFee, fee, path, adapters, maxBridgeSlippage, true, kappa);
        // } catch {
        //   IERC20(token).safeTransferFrom(ROUTER, to, amount.sub(fee));
        //   emit TokenWithdrawAndSwapV2(to, token, amountSubFee, fee, path, adapters, maxBridgeSlippage, false, kappa);
        // }

        kappaMap[kappa] = true;
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
        (bool success,) = to.call{value: amount}("");
        require(
            success,
            "ETH transfer failed"
        );
    }

    function _doGasDrop(address to)
        internal
    {
        // Transfer gas airdrop
        if (checkChainGasAmount()) {
            (bool success, ) = to.call{value: chainGasAmount}("");
            require(success, "GAS_AIRDROP_FAILED");
        }
    }
}
