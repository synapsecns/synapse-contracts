// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LPTokenV2, SwapV2, ISwapV2} from "../../contracts/amm08/SwapV2.sol";
import {SwapDeployerV2, IERC20} from "../../contracts/amm08/SwapDeployerV2.sol";

import {SwapQuoterV2} from "../../contracts/router/quoter/SwapQuoterV2.sol";
import {IDefaultExtendedPool} from "../../contracts/router/interfaces/IDefaultExtendedPool.sol";

import {LinkedPool} from "../../contracts/router/LinkedPool.sol";

import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";
import {Test} from "forge-std/Test.sol";

contract PoolUtils08 is Test {
    address private _swapV2Master;
    address private _lpTokenV2Master;

    SwapDeployerV2 public swapDeployerV2;
    mapping(address => address[]) public poolTokens;

    function setUp() public virtual {
        _swapV2Master = address(new SwapV2());
        _lpTokenV2Master = address(new LPTokenV2());
        swapDeployerV2 = new SwapDeployerV2();
    }

    // ════════════════════════════════════════════ DEFAULT POOL UTILS ═════════════════════════════════════════════════

    /// @notice Deploys a default pool with a given name, tokens, and parameters: A, swapFee.
    function deployDefaultPool(
        string memory poolName,
        address[] memory tokens,
        string memory lpTokenName,
        uint256 a,
        uint256 swapFee
    ) public returns (address pool) {
        uint8[] memory decimals = new uint8[](tokens.length);
        IERC20[] memory tokens_ = new IERC20[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            decimals[i] = IERC20Metadata(tokens[i]).decimals();
            tokens_[i] = IERC20(tokens[i]);
        }

        pool = swapDeployerV2.deploy(
            _swapV2Master,
            tokens_,
            decimals,
            lpTokenName,
            lpTokenName, //lpTokenSymbol
            a,
            swapFee,
            0, //admin fee
            _lpTokenV2Master
        );
        vm.label(pool, poolName);
        for (uint256 i = 0; i < tokens.length; i++) {
            poolTokens[pool].push(tokens[i]);
        }

        (, , , , , , address lpToken) = ISwapV2(pool).swapStorage();
        vm.label(lpToken, lpTokenName);
    }

    /// @notice Deploys a default pool with a given name, tokens. Default values are used:
    /// - A = 100
    /// - swapFee = 1 bps
    function deployDefaultPool(
        string memory poolName,
        address[] memory tokens,
        string memory lpTokenName
    ) public returns (address pool) {
        // Default values: A = 100, swapFee = 1 bps
        return deployDefaultPool(poolName, tokens, lpTokenName, 100, 10**6);
    }

    /// @notice Deploys a default pool with a given name, tokens. Default values are used:
    /// - A = 100
    /// - swapFee = 1 bps
    /// - lpTokenName = "LP Token"
    function deployDefaultPool(string memory poolName, address[] memory tokens) public returns (address pool) {
        // Default values: A = 100, swapFee = 1 bps
        return deployDefaultPool(poolName, tokens, "LP Token", 100, 10**6);
    }

    /// @notice Mints tokens using a provided callback function, and adds liquidity to a pool.
    function addLiquidity(
        address pool,
        uint256[] memory amounts,
        function(address, address, uint256) internal mint
    ) internal {
        address[] memory tokens = poolTokens[pool];
        for (uint256 i = 0; i < tokens.length; i++) {
            mint(tokens[i], address(this), amounts[i]);
            IERC20(tokens[i]).approve(pool, amounts[i]);
        }
        ISwapV2(pool).addLiquidity(amounts, 0, block.timestamp);
    }

    function getLpToken(address pool) internal view returns (address lpToken) {
        (, , , , , , lpToken) = IDefaultExtendedPool(pool).swapStorage();
    }

    // ════════════════════════════════════════════════ ARRAY UTILS ════════════════════════════════════════════════════

    function toArray(address token0, address token1) internal pure returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;
    }

    function toArray(
        address token0,
        address token1,
        address token2
    ) internal pure returns (address[] memory tokens) {
        tokens = new address[](3);
        tokens[0] = token0;
        tokens[1] = token1;
        tokens[2] = token2;
    }

    function toArray(uint256 amount0, uint256 amount1) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
    }

    function toArray(
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    ) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](3);
        amounts[0] = amount0;
        amounts[1] = amount1;
        amounts[2] = amount2;
    }

    function toArray(SwapQuoterV2.BridgePool memory pool0)
        internal
        pure
        returns (SwapQuoterV2.BridgePool[] memory pools)
    {
        pools = new SwapQuoterV2.BridgePool[](1);
        pools[0] = pool0;
    }

    function toArray(SwapQuoterV2.BridgePool memory pool0, SwapQuoterV2.BridgePool memory pool1)
        internal
        pure
        returns (SwapQuoterV2.BridgePool[] memory pools)
    {
        pools = new SwapQuoterV2.BridgePool[](2);
        pools[0] = pool0;
        pools[1] = pool1;
    }

    function toArray(
        SwapQuoterV2.BridgePool memory pool0,
        SwapQuoterV2.BridgePool memory pool1,
        SwapQuoterV2.BridgePool memory pool2
    ) internal pure returns (SwapQuoterV2.BridgePool[] memory pools) {
        pools = new SwapQuoterV2.BridgePool[](3);
        pools[0] = pool0;
        pools[1] = pool1;
        pools[2] = pool2;
    }

    function toArray(
        SwapQuoterV2.BridgePool memory pool0,
        SwapQuoterV2.BridgePool memory pool1,
        SwapQuoterV2.BridgePool memory pool2,
        SwapQuoterV2.BridgePool memory pool3
    ) internal pure returns (SwapQuoterV2.BridgePool[] memory pools) {
        pools = new SwapQuoterV2.BridgePool[](4);
        pools[0] = pool0;
        pools[1] = pool1;
        pools[2] = pool2;
        pools[3] = pool3;
    }

    // ═════════════════════════════════════════════ LINKED POOL UTILS ═════════════════════════════════════════════════

    /// @notice Deploys a Linked Pool with a single pool.
    function deployLinkedPool(address bridgeToken, address pool) public returns (address linkedPool) {
        return deployLinkedPool(bridgeToken, pool, address(0));
    }

    /// @notice Deploys a Linked Pool with a single pool, and a given pool module.
    function deployLinkedPool(
        address bridgeToken,
        address pool,
        address poolModule
    ) public returns (address linkedPool) {
        LinkedPool linkedPool_ = new LinkedPool(bridgeToken);
        linkedPool_.addPool(0, pool, poolModule);
        linkedPool = address(linkedPool_);
        vm.label(linkedPool, string.concat("LinkedPool [", IERC20Metadata(bridgeToken).symbol(), "]"));
    }
}
