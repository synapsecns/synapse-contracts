// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ITokenMessenger, SynapseCCTP} from "../../contracts/cctp/SynapseCCTP.sol";

import {BasicSynapseScript, StringUtils} from "../templates/BasicSynapse.s.sol";
import {stdJson} from "forge-std/Script.sol";

import {ProxyAdmin} from "@openzeppelin/contracts-4.9.5/proxy/transparent/ProxyAdmin.sol";
// prettier-ignore
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts-4.9.5/proxy/transparent/TransparentUpgradeableProxy.sol";

// solhint-disable no-console
contract DeploySynapseCCTPImplementation is BasicSynapseScript {
    using stdJson for string;
    using StringUtils for string;

    string public constant SYNAPSE_CCTP = "SynapseCCTP";
    string public constant IMPLEMENTATION_SUFFIX = ".Implementation";
    string public constant PROXY_NAME = "TransparentUpgradeableProxy";
    string public constant PROXY_ADMIN = "ProxyAdmin";

    address public tokenMessenger;
    address public implementation;

    string public proxyAdminName = PROXY_ADMIN.concat(".", SYNAPSE_CCTP);
    address public proxyAdmin;
    address public proxy;

    address public owner;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        loadConfig();
        vm.startBroadcast();
        skipNonces();
        deployAndSaveProxy();
        vm.stopBroadcast();
        finalChecks();
    }

    function loadConfig() public {
        string memory config = getDeployConfig(SYNAPSE_CCTP);
        // Read tokenMessenger from config
        tokenMessenger = config.readAddress(".tokenMessenger");
        require(tokenMessenger != address(0), "TokenMessenger not set");
        // Load contracts
        implementation = getDeploymentAddress(SYNAPSE_CCTP.concat(IMPLEMENTATION_SUFFIX));
        printLog("Using [implementation = %s]", implementation);
        proxyAdmin = getDeploymentAddress(proxyAdminName);
        printLog("Using [proxyAdmin = %s]", proxyAdmin);
        // Load owner address
        owner = vm.envAddress("CCTP_TESTNET_ADDR");
        require(owner != address(0), "Owner not set");
        printLog("Using [owner = %s]", owner);
    }

    function skipNonces() public {
        uint256 deploymentNonce = vm.envUint("SYNAPSE_CCTP_NONCE");
        uint256 initialNonce = vm.getNonce(msg.sender);
        if (initialNonce > deploymentNonce) {
            printLog(unicode"❗ Initial nonce higher than expected, DOUBLE CHECK THE ADDRESS");
            return;
        }
        if (initialNonce == deploymentNonce) {
            printLog(unicode"💬 Nonce already configured");
            return;
        }
        increaseIndent();
        for (uint256 i = initialNonce; i < deploymentNonce; i++) {
            printLog(string.concat("Skipping nonce ", vm.toString(i)));
            payable(msg.sender).transfer(0);
        }
        decreaseIndent();
    }

    function deployAndSaveProxy() public {
        string memory cctpProxyName = PROXY_NAME.concat(".", SYNAPSE_CCTP);
        bool alreadyDeployed = tryGetDeploymentAddress(cctpProxyName) != address(0);
        proxy = deployAndSaveAs({
            contractName: PROXY_NAME,
            contractAlias: cctpProxyName,
            deployContract: cdDeploySynapseCCTPProxy
        });
        // Save deployment for the proxy contract using implementation ABI if it hasn't been deployed yet
        if (!alreadyDeployed) {
            saveProxyDeployment({
                contractName: SYNAPSE_CCTP,
                implementationAlias: SYNAPSE_CCTP.concat(IMPLEMENTATION_SUFFIX),
                deployedAt: proxy
            });
        }
    }

    /// @notice Callback function to deploy the SynapseCCTP contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function cdDeploySynapseCCTPProxy() internal returns (address deployedAt, bytes memory constructorArgs) {
        // SynapseCCTP.initialize(owner)
        bytes memory initData = abi.encodeCall(SynapseCCTP.initialize, (owner));
        deployedAt = address(
            new TransparentUpgradeableProxy({_logic: implementation, admin_: proxyAdmin, _data: initData})
        );
        constructorArgs = abi.encode(implementation, proxyAdmin, initData);
    }

    function finalChecks() internal view {
        require(address(SynapseCCTP(proxy).tokenMessenger()) == tokenMessenger, "Failed to set tokenMessenger");
        require(SynapseCCTP(proxy).owner() == owner, "Failed to set owner");
    }
}
