// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable-4.4.2/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable-4.4.2/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable-4.4.2/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable-4.4.2/security/PausableUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts-4.4.2/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.4.2/token/ERC20/utils/SafeERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts-4.4.2/token/ERC20/extensions/ERC20Burnable.sol";

import {IWETH9} from "./interfaces/IWETH9.sol";

import {ISynapseBridgeV2} from "./interfaces-8/ISynapseBridgeV2.sol";

import {ISynapseBridge} from "./interfaces-8/ISynapseBridge.sol";
import {IERC20Mintable} from "./interfaces-8/IERC20Mintable.sol";
import {ISwap} from "./interfaces-8/ISwap.sol";
import {IRouter} from "./interfaces-8/IRouter.sol";

import {WETHUtils} from "./utils/WETHUtils.sol";

abstract contract Modifiers is
    Initializable,
    AccessControlUpgradeable
{
    bytes32 public constant NODEGROUP_ROLE  = keccak256("NODEGROUP_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    function __Modifiers_init()
        internal
        onlyInitializing
    {
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
}

contract SynapseBridgeV2 is
    Modifiers,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    ISynapseBridgeV2
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Mintable;

    uint256 public constant BRIDGE_VERSION = 1;

    mapping(address => uint256) private FEES;
    mapping(bytes32 => bool)    private KAPPA_MAP;

    uint256 public START_BLOCK_NUMBER;
    uint256 public CHAIN_GAS_AMOUNT;

    ISynapseBridge  public BRIDGE_V1;
    IRouter         public ROUTER;
    IWETH9          public WETH;

    address payable internal BRIDGE_V1_ADDRESS;
    address payable internal ROUTER_ADDRESS;
    address payable internal WETH_ADDRESS;

    receive() external payable {}

    function initialize(address payable _router)
        external
        initializer
    {
        __Modifiers_init();

        START_BLOCK_NUMBER = block.number;

        _setRouterAddress(_router);
    }

    // admin-only functions

    function setChainGasAmount(uint256 amount)
        governanceOnly
        external
    {
        _setChainGasAmount(amount);
    }

    function _setChainGasAmount(uint256 amount)
        internal
    {
        CHAIN_GAS_AMOUNT = amount;
    }

    function setWethAddress(address payable _wethAddress)
        adminOnly
        external
    {
        _setWethAddress(_wethAddress);
    }

    function _setWethAddress(address payable _wethAddress)
        internal
    {
        WETH_ADDRESS = _wethAddress;
        WETH = IWETH9(_wethAddress);
    }

    function setRouterAddress(address payable _router)
        adminOnly
        external
    {
        _setRouterAddress(_router);
    }

    function _setRouterAddress(address payable _router)
        internal
    {
        ROUTER_ADDRESS = _router;
        ROUTER = IRouter(_router);
    }

    function setBridgeV1Address(address payable _bridgeV1)
        adminOnly
        external
    {
        _setBridgeV1Address(_bridgeV1);
    }

    function _setBridgeV1Address(address payable _bridgeV1)
        internal
    {
        BRIDGE_V1_ADDRESS = _bridgeV1;
        BRIDGE_V1 = ISynapseBridge(_bridgeV1);
    }


    // governance-only

    function addKappas(bytes32[] calldata kappas)
        governanceOnly
        external
    {
        for (uint256 i = 0; i < kappas.length; ++i) {
            KAPPA_MAP[kappas[i]] = true;
        }
    }

    // VIEW FUNCTIONS ***/

    function getFeeBalance(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return FEES[tokenAddress];
    }

    function kappaExists(bytes32 kappa)
        external
        view
        returns (bool)
    {
        return KAPPA_MAP[kappa];
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
        try ROUTER.selfSwap(
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
    {
        uint256 amountSubFee = _preBridge(to, token, amount, fee, kappa);

        token.mint(ROUTER_ADDRESS, amountSubFee);
        token.mint(address(this), fee);

        bool swapSuccess = handleRouterSwap(to, amountSubFee, _trade);
        if (!swapSuccess) {
            token.safeTransferFrom(ROUTER_ADDRESS, to, amountSubFee);
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

        KAPPA_MAP[kappa] = true;
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
    {
        uint256 amountSubFee = _preBridge(payable(to), token, amount, fee, kappa);

        token.safeTransfer(ROUTER_ADDRESS, amountSubFee);
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
            token.safeTransferFrom(ROUTER_ADDRESS, to, amountSubFee);
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

        KAPPA_MAP[kappa] = true;
    }

    function checkChainGasAmount()
        internal
        view
        returns (bool)
    {
        return CHAIN_GAS_AMOUNT != 0 && address(this).balance >= CHAIN_GAS_AMOUNT;
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
        if (WETHUtils.validWETHAddress(WETH_ADDRESS, address(token))) {
            WETHUtils.transferWETH(WETH_ADDRESS, to, amount);
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
        require(
            amount > fee,
            "Amount must be greater than fee"
        );

        require(
            !KAPPA_MAP[kappa],
            "Kappa is already present"
        );

        if (_hasV1Bridge()) {
            require(
                !BRIDGE_V1.kappaExists(kappa),
                "Kappa is already present"
            );
        }

        address _token = address(token);
        uint256 amountSubFee = amount - fee;
        FEES[_token] = FEES[_token] + fee;

        _doGasDrop(to);

        return amountSubFee;
    }

    function _doGasDrop(address payable to)
        internal
    {
        // Transfer gas airdrop
        if (checkChainGasAmount()) {
            (bool success, ) = to.call{value: CHAIN_GAS_AMOUNT}("");
            require(success, "GAS_AIRDROP_FAILED");
        }
    }

    function _hasV1Bridge() internal view returns (bool) {
        return BRIDGE_V1_ADDRESS != address(0);
    }
}
