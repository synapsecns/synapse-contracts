// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Arrays} from "../../../contracts/router/libs/Arrays.sol";
import {BridgeToken} from "../../../contracts/router/libs/Structs.sol";

contract ArraysLibHarness {
    function flatten(BridgeToken[][] memory unflattened, uint256 count) external pure returns (BridgeToken[] memory) {
        return Arrays.flatten(unflattened, count);
    }

    function flatten(address[][] memory unflattened, uint256 count) external pure returns (address[] memory) {
        return Arrays.flatten(unflattened, count);
    }

    function tokens(BridgeToken[] memory b) external pure returns (address[] memory) {
        return Arrays.tokens(b);
    }

    function symbols(BridgeToken[] memory b) external pure returns (string[] memory) {
        return Arrays.symbols(b);
    }

    function unique(address[] memory unfiltered) external pure returns (address[] memory) {
        return Arrays.unique(unfiltered);
    }

    function contains(address[] memory l, address el) external pure returns (bool) {
        return Arrays.contains(l, el);
    }

    function append(address[] memory l, address el) external pure returns (address[] memory) {
        return Arrays.append(l, el);
    }
}
