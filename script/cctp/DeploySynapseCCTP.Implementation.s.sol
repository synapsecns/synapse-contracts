// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ITokenMessenger, SynapseCCTP} from "../../contracts/cctp/SynapseCCTP.sol";

import {BasicSynapseScript, StringUtils} from "../templates/BasicSynapse.s.sol";
import {stdJson} from "forge-std/Script.sol";

import {ProxyAdmin} from "@openzeppelin/contracts-4.9.5/proxy/transparent/ProxyAdmin.sol";

// solhint-disable no-console
contract DeploySynapseCCTPImplementation is BasicSynapseScript {
    using stdJson for string;
    using StringUtils for string;

    string public constant SYNAPSE_CCTP = "SynapseCCTP";
    string public constant IMPLEMENTATION_SUFFIX = ".Implementation";
    string public constant PROXY_ADMIN = "ProxyAdmin";
    address public tokenMessenger;

    string public proxyAdminName = PROXY_ADMIN.concat(".", SYNAPSE_CCTP);
    address public proxyAdmin;
    address public devMultisig;

    address public implementation;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        loadConfig();
        vm.startBroadcast();
        deployAndInitialize();
        deployProxyAdmin();
        vm.stopBroadcast();
        finalChecks();
    }

    function loadConfig() public {
        string memory config = getDeployConfig(SYNAPSE_CCTP);
        // Read tokenMessenger from config
        tokenMessenger = config.readAddress(".tokenMessenger");
        require(tokenMessenger != address(0), "TokenMessenger not set");
        // Read DevMultisig deployment address for the current chain
        // devMultisig = getDeploymentAddress("DevMultisig");
        // printLog("Using [devMultisig = %s]", devMultisig);
    }

    function deployAndInitialize() public {
        implementation = deployAndSaveAs({
            contractName: SYNAPSE_CCTP,
            contractAlias: SYNAPSE_CCTP.concat(IMPLEMENTATION_SUFFIX),
            deployContract: cbDeploySynapseCCTP
        });
        // Initialize the implementation just in case
        address owner = SynapseCCTP(implementation).owner();
        if (owner == address(0)) {
            SynapseCCTP(implementation).initialize(msg.sender);
            printLog("Initialized SynapseCCTP implementation");
        } else {
            printLog("SynapseCCTP implementation already initialized");
            printLog(string.concat(TAB, "owner = ", vm.toString(owner)));
        }
    }

    function deployProxyAdmin() public {
        // Check if the ProxyAdmin has already been deployed
        proxyAdmin = tryGetDeploymentAddress(proxyAdminName);
        if (proxyAdmin == address(0)) {
            // Deploy the ProxyAdmin
            proxyAdmin = deployAndSaveAs({
                contractName: PROXY_ADMIN,
                contractAlias: proxyAdminName,
                deployContract: cbDeployProxyAdmin
            });
        }
        // Transfer ownership of the ProxyAdmin to DevMultisig
        // printLog("Transferring ownership of ProxyAdmin to DevMultisig");
        // increaseIndent();
        // address adminOwner = ProxyAdmin(proxyAdmin).owner();
        // if (adminOwner == msg.sender) {
        //     address multisig = getDeploymentAddress("DevMultisig");
        //     ProxyAdmin(proxyAdmin).transferOwnership(multisig);
        //     printLog("Ownership transferred to %s", multisig);
        // } else {
        //     printLog("Skipping: ProxyAdmin owned by %s", adminOwner);
        // }
        // decreaseIndent();
    }

    /// @notice Callback function to deploy the ProxyAdmin contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function cbDeployProxyAdmin() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new ProxyAdmin());
        constructorArgs = "";
    }

    /// @notice Callback function to deploy the SynapseCCTP contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function cbDeploySynapseCCTP() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new SynapseCCTP(ITokenMessenger(tokenMessenger)));
        constructorArgs = abi.encode(tokenMessenger);
    }

    function finalChecks() internal view {
        require(
            address(SynapseCCTP(implementation).tokenMessenger()) == tokenMessenger,
            "Failed to set tokenMessenger"
        );
        require(SynapseCCTP(implementation).owner() == msg.sender, "Failed to set owner");
        // require(ProxyAdmin(proxyAdmin).owner() == devMultisig, "Failed to set ProxyAdmin owner");
    }
}
