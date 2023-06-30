// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SwapQuoter} from "../SynapseRouterSuite.t.sol";

import {Test} from "forge-std/Test.sol";

interface ILinkedPool {
    function addPool(
        uint256 nodeIndex,
        address pool,
        address poolModule
    ) external;
}

/// Helper contract to deploy LinkedPool contract and add it to SwapQuoter instead of the underlying pool.
abstract contract LinkedPoolSetup is Test {
    mapping(address => address) internal tokenToLinkedPool;

    function deployLinkedPool(address bridgeToken, address pool) public returns (address linkedPool) {
        // Deploy 0.8 LinkedPool contract: new LinkedPool(bridgeToken)
        linkedPool = deployCode("LinkedPool.sol", abi.encode(bridgeToken));
        vm.label(linkedPool, "LinkedPool");
        // Add pool to LinkedPool
        ILinkedPool(linkedPool).addPool(0, pool, address(0));
        // Save LinkedPool address for later use
        tokenToLinkedPool[bridgeToken] = linkedPool;
    }

    function addLinkedPool(SwapQuoter swapQuoter, address bridgeToken) public {
        // Add LinkedPool to SwapQuoter as a simple pool
        beforeOwnerOperation();
        swapQuoter.addPool(tokenToLinkedPool[bridgeToken]);
    }

    function removeLinkedPool(SwapQuoter swapQuoter, address bridgeToken) public {
        beforeOwnerOperation();
        swapQuoter.removePool(tokenToLinkedPool[bridgeToken]);
    }

    function beforeOwnerOperation() public virtual {}
}
