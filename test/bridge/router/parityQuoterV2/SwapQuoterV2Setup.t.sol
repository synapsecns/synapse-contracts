// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Test} from "forge-std/Test.sol";

interface ISwapQuoterV2 {
    enum PoolType {
        Default,
        Linked
    }

    struct BridgePool {
        address bridgeToken;
        PoolType poolType;
        address pool;
    }

    function addPools(BridgePool[] memory pools) external;

    function removePools(BridgePool[] memory pools) external;
}

abstract contract SwapQuoterV2Setup is Test {
    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal virtual returns (address quoter_) {
        // Use deployCode to deploy 0.8 contracts from 0.6 test
        // new DefaultPoolCalc();
        address defaultPoolCalc = deployCode("DefaultPoolCalc.sol");
        // new SwapQuoterV2(router, defaultPoolCalc, weth_, owner);
        quoter_ = deployCode("SwapQuoterV2.sol", abi.encode(router_, defaultPoolCalc, weth_, owner));
        vm.label(defaultPoolCalc, "DefaultPoolCalc");
        vm.label(quoter_, "SwapQuoterV2");
    }

    function addBridgeDefaultPool(
        address swapQuoterV2,
        address bridgeToken,
        address pool
    ) internal virtual {
        ISwapQuoterV2.BridgePool[] memory pools = new ISwapQuoterV2.BridgePool[](1);
        pools[0] = ISwapQuoterV2.BridgePool({
            bridgeToken: bridgeToken,
            poolType: ISwapQuoterV2.PoolType.Default,
            pool: pool
        });
        // Add pool to SwapQuoterV2
        beforeOwnerOperation();
        ISwapQuoterV2(swapQuoterV2).addPools(pools);
    }

    function removeBridgeDefaultPool(
        address swapQuoterV2,
        address bridgeToken,
        address pool
    ) internal virtual {
        ISwapQuoterV2.BridgePool[] memory pools = new ISwapQuoterV2.BridgePool[](1);
        pools[0] = ISwapQuoterV2.BridgePool({
            bridgeToken: bridgeToken,
            poolType: ISwapQuoterV2.PoolType.Default,
            pool: pool
        });
        // Remove pool from SwapQuoterV2
        beforeOwnerOperation();
        ISwapQuoterV2(swapQuoterV2).removePools(pools);
    }

    function beforeOwnerOperation() public virtual {}
}
