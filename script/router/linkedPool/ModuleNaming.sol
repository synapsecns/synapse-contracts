// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import {StringUtils} from "../../templates/StringUtils.sol";

library ModuleNaming {
    using StringUtils for string;

    function getModuleDeploymentName(string memory moduleName) internal pure returns (string memory) {
        // Check if module name is an alias (contains a dot)
        uint256 dotIndex = moduleName.indexOf(".");
        if (dotIndex != StringUtils.NOT_FOUND) {
            // Should transform something like Uniswap.ForkName into UniswapModule.ForkName
            return moduleName.prefix(dotIndex).concat("Module", moduleName.suffix(dotIndex));
        } else {
            // Just add Module suffix
            return moduleName.concat("Module");
        }
    }
}
