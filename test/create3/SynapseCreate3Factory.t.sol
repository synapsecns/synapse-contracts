// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Create3Lib, SynapseCreate3Factory} from "../../contracts/create3/SynapseCreate3Factory.sol";
import {InitializableContract} from "./mocks/InitializableContract.sol";
import {RevertingContract} from "./mocks/RevertingContract.sol";

import {console, Test} from "forge-std/Test.sol";

contract SynapseCreate3FactoryTest is Test {
    SynapseCreate3Factory public factory;
    address public deployer;

    address public initializableReference;
    address public revertingReference;

    uint256 public msgValue;
    bytes public initData;

    function setUp() public {
        factory = new SynapseCreate3Factory();
        deployer = makeAddr("Deployer");
        initializableReference = address(new InitializableContract());
        revertingReference = address(new RevertingContract());
    }

    function testSafeCreate3DeploysContract(bytes12 saltSuffix) public returns (address deployedAddress) {
        bytes32 salt = constructSalt(deployer, saltSuffix);
        address predictedAddress = factory.predictAddress(salt);
        // Deploy contract, use msgValue and initData, which are both empty by default
        vm.prank(deployer);
        deployedAddress = factory.safeCreate3{value: msgValue}(
            salt,
            type(InitializableContract).creationCode,
            initData
        );
        assertEq(predictedAddress, deployedAddress);
        assertEq(deployedAddress.code, initializableReference.code);
    }

    function testSafeCreate3DeploysContractWithEther(bytes12 saltSuffix, uint256 value)
        public
        returns (address deployedAddress)
    {
        deal(deployer, value);
        msgValue = value;
        deployedAddress = testSafeCreate3DeploysContract(saltSuffix);
        assertEq(address(deployedAddress).balance, value);
    }

    function testSafeCreate3DeploysContractWithInitData(bytes12 saltSuffix, uint256 argValue)
        public
        returns (address deployedAddress)
    {
        initData = abi.encodeWithSelector(InitializableContract.setValue.selector, argValue);
        deployedAddress = testSafeCreate3DeploysContract(saltSuffix);
        assertEq(InitializableContract(deployedAddress).value(), argValue);
    }

    function testSafeCreate3DeploysContractWithEtherAndInitData(
        bytes12 saltSuffix,
        uint256 value,
        uint256 argValue
    ) public {
        initData = abi.encodeWithSelector(InitializableContract.setValue.selector, argValue);
        address deployedAddress = testSafeCreate3DeploysContractWithEther(saltSuffix, value);
        assertEq(InitializableContract(deployedAddress).value(), argValue);
    }

    // ══════════════════════════════════════ TESTS: UNAUTHORIZED DEPLOYMENT ═══════════════════════════════════════════

    function testSafeCreate3RevertsWhenSaltDoesNotContainCaller(bytes32 salt) public {
        vm.assume(bytes20(salt) != bytes20(deployer));
        // SynapseCreate3Factory__UnauthorizedDeployer(deployed, authorized)
        vm.expectRevert(
            abi.encodeWithSelector(
                SynapseCreate3Factory.SynapseCreate3Factory__UnauthorizedDeployer.selector,
                deployer,
                address(bytes20(salt))
            )
        );
        vm.prank(deployer);
        factory.safeCreate3(salt, type(InitializableContract).creationCode, "");
    }

    function testSafeCreate3RevertsWhenSaltHasSingleBitSwitched(bytes12 saltSuffix) public {
        bytes32 correctSalt = constructSalt(deployer, saltSuffix);
        bytes32 one = bytes32(uint256(1));
        // Iterate over all 160 highest bits of the salt
        for (uint256 i = 0; i < 160; ++i) {
            // Switch one bit at a time
            bytes32 incorrectSalt = correctSalt ^ (one << (96 + i));
            // SynapseCreate3Factory__UnauthorizedDeployer(deployed, authorized)
            vm.expectRevert(
                abi.encodeWithSelector(
                    SynapseCreate3Factory.SynapseCreate3Factory__UnauthorizedDeployer.selector,
                    deployer,
                    address(bytes20(incorrectSalt))
                )
            );
            vm.prank(deployer);
            factory.safeCreate3(incorrectSalt, type(InitializableContract).creationCode, "");
        }
    }

    // ═════════════════════════════════════════════ TESTS: SALT REUSE ═════════════════════════════════════════════════

    function testSafeCreate3RevertsWhenSaltReused(bytes12 saltSuffix) public {
        bytes32 salt = constructSalt(deployer, saltSuffix);
        // Deploy contract with the salt
        vm.prank(deployer);
        address occupied = factory.safeCreate3(salt, type(InitializableContract).creationCode, "");
        // Try to deploy another contract with the same salt
        vm.expectRevert(abi.encodeWithSelector(Create3Lib.Create3__DeploymentAlreadyExists.selector, occupied));
        vm.prank(deployer);
        factory.safeCreate3(salt, type(RevertingContract).creationCode, "");
    }

    function testSafeCreate3AnotherDeployerUsedSaltSuffix(bytes12 saltSuffix) public {
        // Deploy contract using another deployer, but the same salt suffix
        address anotherDeployer = makeAddr("Another deployer");
        bytes32 anotherSalt = constructSalt(anotherDeployer, saltSuffix);
        vm.prank(anotherDeployer);
        factory.safeCreate3(anotherSalt, type(InitializableContract).creationCode, "");
        // Should be able to use the same suffix with the original deployer
        testSafeCreate3DeploysContract(saltSuffix);
    }

    // ══════════════════════════════════════════════ TESTS: REVERTS ═══════════════════════════════════════════════════

    function testSafeCreate3RevertsBubbleErrorWhenInitCallRevertsWithCustomError() public {
        bytes32 salt = constructSalt(deployer, 0);
        initData = abi.encodeWithSelector(RevertingContract.revertWithNoArgError.selector);
        vm.expectRevert(RevertingContract.NoArgError.selector);
        vm.prank(deployer);
        factory.safeCreate3(salt, type(RevertingContract).creationCode, initData);
    }

    function testSafeCreate3RevertsBubbleErrorWhenInitCallRevertsWithCustomErrorWithArgs() public {
        bytes32 salt = constructSalt(deployer, 0);
        uint256 argValue = 42;
        initData = abi.encodeWithSelector(RevertingContract.revertWithOneArgError.selector, argValue);
        vm.expectRevert(abi.encodeWithSelector(RevertingContract.OneArgError.selector, argValue));
        vm.prank(deployer);
        factory.safeCreate3(salt, type(RevertingContract).creationCode, initData);
    }

    function testSafeCreate3RevertsBubbleErrorWhenInitCallRevertsWithMessage() public {
        bytes32 salt = constructSalt(deployer, 0);
        initData = abi.encodeWithSelector(RevertingContract.revertWithMessage.selector);
        vm.expectRevert("Revert: GM");
        vm.prank(deployer);
        factory.safeCreate3(salt, type(RevertingContract).creationCode, initData);
    }

    function testSafeCreate3RevertsWhenInitCallRevertsSilently() public {
        bytes32 salt = constructSalt(deployer, 0);
        initData = abi.encodeWithSelector(RevertingContract.revertNoReason.selector);
        vm.expectRevert(SynapseCreate3Factory.SynapseCreate3Factory__InitCallFailed.selector);
        vm.prank(deployer);
        factory.safeCreate3(salt, type(RevertingContract).creationCode, initData);
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function constructSalt(address caller, bytes12 saltSuffix) public pure returns (bytes32 salt) {
        // Lowest 12 bytes are the "salt suffix"
        salt = bytes32(uint256(uint96(saltSuffix)));
        // Highest 20 bytes are the caller
        salt |= bytes32(uint256(uint160(caller)) << 96);
    }
}
