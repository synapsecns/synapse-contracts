// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {UniversalTokenLib} from "../../../contracts/router/libs/UniversalToken.sol";

contract UniversalTokenLibHarness {
    function universalTransfer(
        address token,
        address to,
        uint256 value
    ) public {
        UniversalTokenLib.universalTransfer(token, to, value);
    }

    function ethAddress() public pure returns (address) {
        return UniversalTokenLib.ETH_ADDRESS;
    }
}
