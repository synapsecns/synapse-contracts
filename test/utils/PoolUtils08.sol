// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LPTokenV2, SwapV2, ISwapV2} from "../../contracts/amm08/SwapV2.sol";
import {SwapDeployerV2, IERC20} from "../../contracts/amm08/SwapDeployerV2.sol";

import {LinkedPool} from "../../contracts/router/LinkedPool.sol";

import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";
import {Test} from "forge-std/Test.sol";

contract PoolUtils08 is Test {
    address private _swapV2Master;
    address private _lpTokenV2Master;

    SwapDeployerV2 public swapDeployerV2;

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
        address[] memory tokens,
        uint256[] memory amounts,
        function(address, address, uint256) internal mint
    ) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            mint(tokens[i], address(this), amounts[i]);
            IERC20(tokens[i]).approve(pool, amounts[i]);
        }
        ISwapV2(pool).addLiquidity(amounts, 0, block.timestamp);
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
