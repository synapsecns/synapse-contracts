// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract RevertingContract {
    error NoArgError();
    error OneArgError(uint256 arg);

    function revertNoReason() external pure {
        revert();
    }

    function revertWithMessage() external pure {
        revert("Revert: GM");
    }

    function revertWithNoArgError() external pure {
        revert NoArgError();
    }

    function revertWithOneArgError(uint256 arg) external pure {
        revert OneArgError(arg);
    }
}

contract RevertingConstructorContract {
    constructor() {
        revert("Revert: GM");
    }
}
