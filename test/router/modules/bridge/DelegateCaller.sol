// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Address} from "@openzeppelin/contracts-4.5.0/utils/Address.sol";

contract DelegateCaller {
    using Address for address;

    function performDelegateCall(address target, bytes memory data) external payable {
        target.functionDelegateCall(data);
    }
}
