// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {SynapseDeployFactory} from "../../contracts/factory/SynapseDeployFactory.sol";

import "@openzeppelin/contracts-4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-4.5.0/access/AccessControl.sol";
import "@openzeppelin/contracts-4.5.0/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/token/ERC20/ERC20Upgradeable.sol";

interface ISynapseERC20 {
    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address owner
    ) external;
}

// solhint-disable func-name-mixedcase
contract SynapseDeployFactoryTest is Test {
    SynapseDeployFactory internal factory;
    address internal synapseERC20;

    struct SynapseERC20Params {
        string name;
        string symbol;
        uint8 decimals;
        address owner;
    }

    function setUp() public {
        factory = new SynapseDeployFactory();
        synapseERC20 = deployCode("SynapseERC20.sol");
    }

    function test_deploy(
        address deployer,
        bytes32 salt,
        string memory name,
        string memory symbol
    ) public {
        vm.assume(deployer != address(0));
        // We're deploying ERC20(name, symbol) to a predetermined address
        address predicted = factory.predictAddress(deployer, salt);
        bytes memory args = abi.encode(name, symbol);
        // Simulate a deploy call from the deployer
        vm.prank(deployer);
        address deployment = factory.deploy(salt, abi.encodePacked(type(ERC20).creationCode, args));
        // Check deployment address and correctness of constructor args
        assertEq(deployment, predicted, "Predicted address wrong");
        ERC20 token = ERC20(deployment);
        assertEq(token.name(), name, "Wrong name");
        assertEq(token.symbol(), symbol, "Wrong symbol");
    }

    function test_deploySynapseERC20(
        address deployer,
        bytes32 salt,
        SynapseERC20Params memory params
    ) public {
        vm.assume(deployer != address(0));
        // We're deploying SynapseERC20 to a predetermined address
        // And calling initialize(name, symbol, decimals, owner)
        address predicted = factory.predictCloneAddress(deployer, salt, synapseERC20);
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,uint8,address)",
            params.name,
            params.symbol,
            params.decimals,
            params.owner
        );
        // Simulate a deploy call from the deployer
        vm.prank(deployer);
        address deployment = factory.deployClone(salt, synapseERC20, initData);
        // Check deployment address and correctness of initializer args
        assertEq(deployment, predicted, "Predicted address wrong");
        ERC20 token = ERC20(deployment);
        assertEq(token.name(), params.name, "Wrong name");
        assertEq(token.symbol(), params.symbol, "Wrong symbol");
        assertEq(token.decimals(), params.decimals, "Wrong decimals");
        assertTrue(AccessControl(deployment).hasRole(0x00, params.owner), "Default admin role not setup");
    }

    function test_deployTransparentUpgradeableProxy(
        address deployer,
        bytes32 adminSalt,
        bytes32 proxySalt,
        address adminOwner,
        SynapseERC20Params memory params
    ) public {
        vm.assume(deployer != address(0));
        vm.assume(adminOwner != address(0));
        vm.assume(params.owner != address(0));
        vm.assume(adminSalt != proxySalt);

        address predictedAdmin = factory.predictAddress(deployer, adminSalt);
        bytes memory adminArgs = abi.encode(adminOwner);
        // Simulate a deploy call from the deployer
        vm.prank(deployer);
        address deploymentAdmin = factory.deploy(
            adminSalt,
            abi.encodePacked(vm.getCode("FactoryProxyAdmin.sol"), adminArgs)
        );
        // Check deployment address and correctness of constructor args
        assertEq(deploymentAdmin, predictedAdmin, "Predicted admin address wrong");
        assertEq(Ownable(deploymentAdmin).owner(), adminOwner, "Admin owner wrong");

        address predictedProxy = factory.predictAddress(deployer, proxySalt);
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,uint8,address)",
            params.name,
            params.symbol,
            params.decimals,
            params.owner
        );
        bytes memory proxyArgs = abi.encode(synapseERC20, deploymentAdmin, initData);
        // Simulate a deploy call from the deployer
        vm.prank(deployer);
        // address deploymentProxy = address(new TransparentUpgradeableProxy(synapseERC20, deploymentAdmin, initData));
        address deploymentProxy = factory.deploy(
            proxySalt,
            abi.encodePacked(type(TransparentUpgradeableProxy).creationCode, proxyArgs)
        );
        // Check deployment address and correctness of initializer args
        assertEq(deploymentProxy, predictedProxy, "Predicted proxy address wrong");
        ERC20 token = ERC20(deploymentProxy);
        assertEq(token.name(), params.name, "Wrong name");
        assertEq(token.symbol(), params.symbol, "Wrong symbol");
        assertEq(token.decimals(), params.decimals, "Wrong decimals");
        assertTrue(AccessControl(deploymentProxy).hasRole(0x00, params.owner), "Default admin role not setup");

        // Check that proxy admin can upgrade the implementation
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(deploymentProxy));
        ProxyAdmin admin = ProxyAdmin(deploymentAdmin);
        assertEq(admin.getProxyImplementation(proxy), synapseERC20, "Wrong initial implementation");
        address newImpl = deployCode("SynapseERC20.sol");
        vm.prank(adminOwner);
        admin.upgrade(proxy, newImpl);
        assertEq(admin.getProxyImplementation(proxy), newImpl, "Wrong new implementation");
    }
}
