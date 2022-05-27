// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

abstract contract ContextChainId {
    uint256 internal immutable localChainId;

    constructor() {
        localChainId = _chainId();
    }

    function _chainId() internal view virtual returns (uint256) {
        return block.chainid;
    }
}
