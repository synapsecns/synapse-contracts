// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "forge-std/Test.sol";

import {Swap} from "../../contracts/amm/Swap.sol";
import {SwapDeployer} from "../../contracts/amm/SwapDeployer.sol";
import {LPToken} from "../../contracts/amm/LPToken.sol";

import {SynapseBridge} from "../../contracts/bridge/SynapseBridge.sol";
import {SynapseERC20} from "../../contracts/bridge/SynapseERC20.sol";
import {ISwap} from "../../contracts/bridge/interfaces/ISwap.sol";
import {IWETH9} from "../../contracts/bridge/interfaces/IWETH9.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Decimals is ERC20 {
    constructor(string memory name_, uint8 decimals_) public ERC20(name_, name_) {
        _setupDecimals(decimals_);
    }
}

contract Utilities06 is Test {
    address internal constant NODE = 0x230A1AC45690B9Ae1176389434610B9526d2f21b;

    LPToken private _lpToken;
    Swap private _swap;
    SwapDeployer private _deployer;

    // Bridge "OUT" Events. `IERC20` replaced with `address` to reduce amount of casts
    event TokenDeposit(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenRedeem(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenDepositAndSwap(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenRedeemAndSwap(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenRedeemAndRemove(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline
    );

    function setUp() public virtual {
        _lpToken = new LPToken();
        _swap = new Swap();
        _deployer = new SwapDeployer();
    }

    /**
     * @notice Deploys and labels an ERC20 mock.
     */
    function deployERC20(string memory name, uint8 decimals) public returns (ERC20 token) {
        token = new ERC20Decimals(name, decimals);
        vm.label(address(token), name);
    }

    /**
     * @notice Deploys and labels a SynapseERC20 token.
     */
    function deploySynapseERC20(string memory name) public returns (SynapseERC20 token) {
        token = new SynapseERC20();
        token.initialize(name, name, 18, address(this));
        vm.label(address(token), name);
    }

    function deployWETH() public returns (IWETH9 token) {
        address weth = deployCode("WETH9.sol");
        vm.label(weth, "WETH");
        token = IWETH9(payable(weth));
    }

    /**
     * @notice Deploys a test pool given the pool tokens.
     */
    function deployPool(IERC20[] memory tokens) public returns (address pool) {
        uint8[] memory decimals = new uint8[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            decimals[i] = ERC20(address(tokens[i])).decimals();
        }
        pool = _deployer.deploy(address(_swap), tokens, decimals, "LP", "LP", 100, 1e6, 0, address(_lpToken));
    }

    /**
     * @notice Deploys a test pool given the pool tokens, and provides initial liquidity.
     * @dev For better readability, `amounts` are provided without decimals.
     */
    function deployPoolWithLiquidity(IERC20[] memory tokens, uint256[] memory amounts) public returns (address pool) {
        pool = deployPool(tokens);
        uint256[] memory amountsWithDecimals = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 decimals = ERC20(address(tokens[i])).decimals();
            amountsWithDecimals[i] = amounts[i] * 10**decimals;
            deal(address(tokens[i]), address(this), amountsWithDecimals[i]);
            tokens[i].approve(pool, type(uint256).max);
        }
        ISwap(pool).addLiquidity(amountsWithDecimals, 0, type(uint256).max);
    }

    function deployBridge() public returns (SynapseBridge bridge) {
        bridge = new SynapseBridge();
        setupBridge(bridge);
    }

    function deployBridge(address at) public returns (SynapseBridge bridge) {
        // Deploy code at requested address
        bytes memory code = vm.getCode("SynapseBridge.sol");
        vm.etch(at, code);
        bridge = SynapseBridge(payable(at));
        setupBridge(bridge);
    }

    function setupBridge(SynapseBridge bridge) public {
        bridge.initialize();
        bridge.grantRole(bridge.NODEGROUP_ROLE(), NODE);
        vm.label(address(bridge), "BRIDGE");
    }
}
