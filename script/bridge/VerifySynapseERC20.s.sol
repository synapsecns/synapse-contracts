// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseERC20} from "../../contracts/bridge/SynapseERC20.sol";

import {BasicSynapseScript, StringUtils} from "../templates/BasicSynapse.s.sol";

contract VerifySynapseERC20 is BasicSynapseScript {
    struct Address {
        string label;
        address addr;
    }

    uint256 public constant NOT_FOUND = type(uint256).max;

    SynapseERC20 public token;

    Address[] public admins;
    Address[] public minters;

    function run(string memory symbol) external {
        // Setup the BasicSynapseScript
        setUp();
        printLog(StringUtils.concat("Current chain: ", activeChain));
        token = SynapseERC20(getDeploymentAddress(symbol));
        addAddress(admins, "DevMultisig");
        addAddress(admins, "DevMultisigLegacy");
        addAddress(minters, "SynapseBridge");
        // Log Metadata
        printMetadata(symbol);
        // Check roles
        checkRole(admins, "Admin", token.DEFAULT_ADMIN_ROLE());
        checkRole(minters, "Minter", token.MINTER_ROLE());
    }

    function printMetadata(string memory symbol) internal {
        printLog(StringUtils.concat("Checking ", symbol, ": ", vm.toString(address(token))));
        increaseIndent();
        printLog(StringUtils.concat("Name: ", token.name()));
        printLog(StringUtils.concat("Symbol: ", token.symbol()));
        printLog(StringUtils.concat("Decimals: ", vm.toString(uint256(token.decimals()))));
        decreaseIndent();
    }

    function addAddress(Address[] storage addresses, string memory label) internal {
        address addr = tryGetDeploymentAddress(label);
        if (addr != address(0)) {
            addresses.push(Address(label, addr));
        }
    }

    function checkRole(
        Address[] storage potentialMembers,
        string memory roleName,
        bytes32 role
    ) internal {
        uint256 count = token.getRoleMemberCount(role);
        printLog(StringUtils.concat("Role ", roleName, " has ", vm.toString(count), " members"));
        increaseIndent();
        if (count == 0) {
            printCondition(false, "No members");
        }
        for (uint256 i = 0; i < count; i++) {
            address member = token.getRoleMember(role, i);
            uint256 index = findMember(potentialMembers, member);
            if (index != NOT_FOUND) {
                printCondition(true, StringUtils.concat(vm.toString(member), " [", potentialMembers[index].label, "]"));
            } else {
                printCondition(false, StringUtils.concat(vm.toString(member), " is not an expected member"));
            }
        }
        decreaseIndent();
    }

    function findMember(Address[] storage potentialMembers, address member) internal view returns (uint256) {
        for (uint256 i = 0; i < potentialMembers.length; i++) {
            if (potentialMembers[i].addr == member) {
                return i;
            }
        }
        return NOT_FOUND;
    }

    function printCondition(bool condition, string memory message) internal {
        printLog(StringUtils.concat(condition ? "✅ " : "❌ ", message));
    }
}
