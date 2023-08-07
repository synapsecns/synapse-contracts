// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract OnlyDelegateCall {
    address private immutable original;

    constructor() {
        original = address(this);
    }

    function assertDelegateCall() internal view {
        require(address(this) != original, "Not a delegate call");
    }
}
