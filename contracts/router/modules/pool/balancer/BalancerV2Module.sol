// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";
import {IBalancerV2Vault} from "../../../interfaces/balancer/IBalancerV2Vault.sol";
import {IBalancerV2Pool} from "../../../interfaces/balancer/IBalancerV2Pool.sol";

/// @notice PoolModule for Balancer V2 pools
contract BalancerV2Module is IPoolModule {
    using SafeERC20 for IERC20;

    IBalancerV2Vault public immutable vault;

    constructor(address _vault) {
        vault = IBalancerV2Vault(_vault);
    }

    function _poolId(address pool) internal returns (bytes32 poolId) {
        poolId = IBalancerV2Pool(pool).getPoolId();
    }

    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        SingleSwap memory singleSwap = SingleSwap({
            poolId: _poolId(pool),
            kind: SwapKind.GIVEN_IN,
            assetIn: tokenFrom.token,
            assetOut: tokenTo.token,
            amount: amountIn,
            userData: bytes(0)
        });
        FundManagement memory funds = FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: address(this),
            toInternalBalance: false
        });
        limit = 0;
        deadline = type(uint256).max;

        IERC20(tokenFrom.token).safeApprove(pool, amountIn);
        amountOut = vault.swap(singleSwap, funds, limit, deadline);
    }

    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) external view returns (uint256 amountOut) {}

    function getPoolTokens(address pool) external view returns (address[] memory tokens) {}
}
