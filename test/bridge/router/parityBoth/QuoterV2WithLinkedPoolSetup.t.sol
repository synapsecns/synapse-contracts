// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {ILinkedPool} from "../parityLinkedPool/LinkedPoolSetup.t.sol";
import {ISwapQuoterV2} from "../parityQuoterV2/SwapQuoterV2Setup.t.sol";

import {Test} from "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract QuoterV2WithLinkedPoolSetup is Test {
    mapping(address => address) internal tokenToLinkedPool;

    // Deploys a LinkedPool for a bridge token with a single pool, if it doesn't exist yet.
    function deployLinkedPool(address bridgeToken, address pool) public returns (address linkedPool) {
        // Check if LinkedPool already exists
        if (tokenToLinkedPool[bridgeToken] != address(0)) {
            return tokenToLinkedPool[bridgeToken];
        }
        // Deploy 0.8 LinkedPool contract: new LinkedPool(bridgeToken, address(this))
        linkedPool = deployCode("LinkedPool.sol", abi.encode(bridgeToken, address(this)));
        string memory symbol = ERC20(bridgeToken).symbol();
        vm.label(linkedPool, string(abi.encodePacked("LinkedPool[", symbol, "]")));
        // Add pool to LinkedPool
        ILinkedPool(linkedPool).addPool(0, pool, address(0));
        // Save LinkedPool address for later use
        tokenToLinkedPool[bridgeToken] = linkedPool;
    }

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

    function addBridgePool(
        address swapQuoterV2,
        address bridgeToken,
        ISwapQuoterV2.PoolType poolType,
        address pool
    ) internal virtual {
        ISwapQuoterV2.BridgePool[] memory pools = new ISwapQuoterV2.BridgePool[](1);
        pools[0] = ISwapQuoterV2.BridgePool({bridgeToken: bridgeToken, poolType: poolType, pool: pool});
        beforeOwnerOperation();
        ISwapQuoterV2(swapQuoterV2).addPools(pools);
    }

    function addBridgeDefaultPool(
        address swapQuoterV2,
        address bridgeToken,
        address pool
    ) internal virtual {
        addBridgePool(swapQuoterV2, bridgeToken, ISwapQuoterV2.PoolType.Default, pool);
    }

    function addBridgeLinkedPool(address swapQuoterV2, address bridgeToken) internal virtual {
        addBridgePool(swapQuoterV2, bridgeToken, ISwapQuoterV2.PoolType.Linked, tokenToLinkedPool[bridgeToken]);
    }

    function removeBridgePool(
        address swapQuoterV2,
        address bridgeToken,
        ISwapQuoterV2.PoolType poolType,
        address pool
    ) internal virtual {
        ISwapQuoterV2.BridgePool[] memory pools = new ISwapQuoterV2.BridgePool[](1);
        pools[0] = ISwapQuoterV2.BridgePool({bridgeToken: bridgeToken, poolType: poolType, pool: pool});
        beforeOwnerOperation();
        ISwapQuoterV2(swapQuoterV2).removePools(pools);
    }

    function removeBridgeDefaultPool(
        address swapQuoterV2,
        address bridgeToken,
        address pool
    ) internal virtual {
        removeBridgePool(swapQuoterV2, bridgeToken, ISwapQuoterV2.PoolType.Default, pool);
    }

    function removeBridgeLinkedPool(address swapQuoterV2, address bridgeToken) internal virtual {
        removeBridgePool(swapQuoterV2, bridgeToken, ISwapQuoterV2.PoolType.Linked, tokenToLinkedPool[bridgeToken]);
    }

    function beforeOwnerOperation() public virtual {}
}
