// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IBalancerV2Asset} from "./IBalancerV2Asset.sol";

interface IBalancerV2Vault {
    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (
            address[] memory tokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        );

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256 amountCalculated);

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        IBalancerV2Asset assetIn;
        IBalancerV2Asset assetOut;
        uint256 amount;
        bytes userData;
    }

    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }
}
