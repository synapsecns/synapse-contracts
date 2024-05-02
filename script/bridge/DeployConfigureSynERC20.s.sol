// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseERC20Factory} from "../../contracts/bridge/SynapseERC20Factory.sol";
import {SynapseERC20} from "../../contracts/bridge/SynapseERC20.sol";

import {BasicSynapseScript, StringUtils} from "../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/StdJson.sol";

contract DeployConfigureSynERC20 is BasicSynapseScript {
    using stdJson for string;
    using StringUtils for string;

    string public config;
    string public keyPrefix;
    address public synapseERC20Impl;
    SynapseERC20Factory public factory;

    SynapseERC20 public token;
    address public multisig;
    address public bridge;

    function run(string memory symbol) external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        loadConfig(symbol);
        token = SynapseERC20(
            deployAndSaveAs({contractName: "SynapseERC20", contractAlias: symbol, deployContract: cbDeploySynapseERC20})
        );
        grantRoles();
        vm.stopBroadcast();
        checkRoles();
    }

    function loadConfig(string memory symbol) internal {
        config = getGlobalConfig({contractName: "SynapseERC20", globalProperty: "symbols"});
        keyPrefix = StringUtils.concat(".", symbol, ".", activeChain);

        synapseERC20Impl = getDeploymentAddress("SynapseERC20");
        factory = SynapseERC20Factory(getDeploymentAddress("SynapseERC20Factory"));

        multisig = getDeploymentAddress("DevMultisig");
        bridge = getDeploymentAddress("SynapseBridge");
    }

    /// @notice Callback function to deploy the SynapseERC20 contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function cbDeploySynapseERC20() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = factory.deploy({
            synapseERC20Address: synapseERC20Impl,
            name: config.readString(keyPrefix.concat(".name")),
            symbol: config.readString(keyPrefix.concat(".symbol")),
            decimals: uint8(config.readUint(keyPrefix.concat(".decimals"))),
            owner: msg.sender
        });
        constructorArgs = "";
    }

    function grantRoles() internal {
        printLog("Granting roles");
        bytes32 adminRole = token.DEFAULT_ADMIN_ROLE();
        bytes32 minterRole = token.MINTER_ROLE();
        if (!token.hasRole(adminRole, msg.sender)) {
            printLog(TAB.concat("Skipping: ", vm.toString(msg.sender), " is not an admin"));
            return;
        }

        grantRole("DEFAULT_ADMIN_ROLE", adminRole, multisig);
        grantRole("MINTER_ROLE", minterRole, bridge);

        token.renounceRole(adminRole, msg.sender);
        printLog(TAB.concat("Renounced admin role for ", vm.toString(msg.sender)));
    }

    function grantRole(
        string memory roleName,
        bytes32 role,
        address account
    ) internal {
        if (!token.hasRole(role, account)) {
            token.grantRole(role, account);
            printLog(TAB.concat("Granted ", roleName, " to ", vm.toString(account)));
        } else {
            printLog(TAB.concat("Skipping: ", roleName, " already granted to ", vm.toString(account)));
        }
    }

    function checkRoles() internal {
        printLog("Checking roles");
        increaseIndent();
        checkCondition(token.hasRole(token.DEFAULT_ADMIN_ROLE(), multisig), "DevMultisig is the admin");
        checkCondition(token.hasRole(token.MINTER_ROLE(), bridge), "SynapseBridge is the minter");
        checkCondition(token.getRoleMemberCount(token.DEFAULT_ADMIN_ROLE()) == 1, "Admin count is 1");
        checkCondition(token.getRoleMemberCount(token.MINTER_ROLE()) == 1, "Minter count is 1");
        decreaseIndent();
    }

    function checkCondition(bool condition, string memory message) internal {
        if (condition) {
            printLog(StringUtils.concat("✅ ", message));
        } else {
            printLog(StringUtils.concat("❌ ", message));
            assert(false);
        }
    }
}
