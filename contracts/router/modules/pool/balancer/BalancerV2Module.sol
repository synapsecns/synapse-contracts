// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";

import {IBalancerV2Asset} from "../../../interfaces/balancer/IBalancerV2Asset.sol";
import {IBalancerV2Vault} from "../../../interfaces/balancer/IBalancerV2Vault.sol";
import {IBalancerV2Pool} from "../../../interfaces/balancer/IBalancerV2Pool.sol";

/// @notice PoolModule for Balancer V2 pools
contract BalancerV2Module is IPoolModule {
    using SafeERC20 for IERC20;

    IBalancerV2Vault public immutable vault;

    constructor(address _vault) {
        vault = IBalancerV2Vault(_vault);
    }

    function _poolId(address pool) internal view returns (bytes32 poolId) {
        poolId = IBalancerV2Pool(pool).getPoolId();
    }

    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        IBalancerV2Vault.SingleSwap memory singleSwap = IBalancerV2Vault.SingleSwap({
            poolId: _poolId(pool),
            kind: IBalancerV2Vault.SwapKind.GIVEN_IN,
            assetIn: IBalancerV2Asset(tokenFrom.token), // TODO: check ok
            assetOut: IBalancerV2Asset(tokenTo.token), // TODO: check ok
            amount: amountIn,
            userData: ""
        });
        IBalancerV2Vault.FundManagement memory funds = IBalancerV2Vault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });
        uint256 limit = 0;
        uint256 deadline = type(uint256).max;

        IERC20(tokenFrom.token).safeApprove(address(vault), amountIn);
        amountOut = vault.swap(singleSwap, funds, limit, deadline);
    }

    // TODO: vault.queryBatchSwap() if ok with getPoolQuote as non-view
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) external view returns (uint256 amountOut) {}

    function getPoolTokens(address pool) external view returns (address[] memory tokens) {
        bytes32 poolId = _poolId(pool);
        (tokens, , ) = vault.getPoolTokens(poolId); // TODO: check ok implicit cast from IERC20[] to address[]
    }
}
