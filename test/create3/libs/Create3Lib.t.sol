// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Create3Lib, Create3LibHarness} from "../harnesses/Create3LibHarness.sol";
import {SimpleContract, SimpleArgContract} from "../mocks/SimpleContracts.sol";

import {Test} from "forge-std/Test.sol";

contract Create3LibraryTest is Test {
    Create3LibHarness public create3LibHarness;

    address public simpleReference;
    address public simpleArgReference;

    function setUp() public {
        create3LibHarness = new Create3LibHarness();
        simpleReference = address(new SimpleContract());
        simpleArgReference = address(new SimpleArgContract(42));
    }

    function testCreate3NoArgs(bytes32 salt) public {
        address predictedAddress = create3LibHarness.predictAddress(salt);
        address deployedAddress = create3LibHarness.create3(salt, type(SimpleContract).creationCode, 0);
        assertEq(predictedAddress, deployedAddress);
        assertEq(deployedAddress.code, simpleReference.code);
    }

    function testCreate3WithEther(
        bytes32 salt,
        uint256 totalValue,
        uint256 forwardedValue
    ) public {
        deal(address(this), totalValue);
        forwardedValue = bound(forwardedValue, 0, totalValue);
        address predictedAddress = create3LibHarness.predictAddress(salt);
        // Use different ether values for constructor and msg.value for testing
        address deployedAddress = create3LibHarness.create3{value: totalValue}(
            salt,
            type(SimpleContract).creationCode,
            forwardedValue
        );
        assertEq(predictedAddress, deployedAddress);
        assertEq(deployedAddress.code, simpleReference.code);
        assertEq(address(deployedAddress).balance, forwardedValue);
    }

    function testCreate3WithArgs(bytes32 salt, uint256 arg) public {
        address predictedAddress = create3LibHarness.predictAddress(salt);
        bytes memory creationCode = abi.encodePacked(type(SimpleArgContract).creationCode, abi.encode(arg));
        address deployedAddress = create3LibHarness.create3(salt, creationCode, 0);
        assertEq(predictedAddress, deployedAddress);
        assertEq(deployedAddress.code, simpleArgReference.code);
        assertEq(SimpleArgContract(deployedAddress).arg(), arg);
    }

    function testCreate3RevertsWhenDeploymentExists() public {
        bytes32 salt = "Very random salt";
        address predictedAddress = create3LibHarness.predictAddress(salt);
        // Put some nonsense bytecode at the predicted address
        vm.etch(predictedAddress, "Mocked existing contract bytecode");
        vm.expectRevert(abi.encodeWithSelector(Create3Lib.Create3__DeploymentAlreadyExists.selector, predictedAddress));
        create3LibHarness.create3(salt, type(SimpleContract).creationCode, 0);
    }

    function testCreate3RevertsWhenSaltReusedDifferentContract() public {
        bytes32 salt = "Not so very random salt";
        bytes memory creationCode = abi.encodePacked(type(SimpleArgContract).creationCode, abi.encode(69));
        address occupied = create3LibHarness.create3(salt, creationCode, 0);
        // Deploying a different contract with the same salt should fail
        vm.expectRevert(abi.encodeWithSelector(Create3Lib.Create3__DeploymentAlreadyExists.selector, occupied));
        create3LibHarness.create3(salt, type(SimpleContract).creationCode, 0);
    }

    function testCreate3RevertsWhenSaltReusedSameContract() public {
        bytes32 salt = "Quite random salt";
        address occupied = create3LibHarness.create3(salt, type(SimpleContract).creationCode, 0);
        // Deploying the same contract with the same salt should fail
        vm.expectRevert(abi.encodeWithSelector(Create3Lib.Create3__DeploymentAlreadyExists.selector, occupied));
        create3LibHarness.create3(salt, type(SimpleContract).creationCode, 0);
    }

    function testCreate3RevertsWhenProxyDeployerDeploymentFails() public {
        bytes32 salt = "Is this random?";
        // Make the deployment of proxy deployer fail by putting some nonsense bytecode at the proxy address
        address proxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(create3LibHarness),
                            salt,
                            Create3Lib.DEPLOYER_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
        vm.etch(proxy, "Mocked existing proxy bytecode");
        vm.expectRevert(abi.encodeWithSelector(Create3Lib.Create3__ProxyDeployerDeploymentFailed.selector));
        create3LibHarness.create3(salt, type(SimpleContract).creationCode, 0);
    }

    function testCreate3RevertsWhenFinalDeploymentFails() public {
        bytes32 salt = "The saltiest salt";
        // Make the final deployment fail by not providing enough arguments to the constructor
        vm.expectRevert(abi.encodeWithSelector(Create3Lib.Create3__DeploymentFailed.selector));
        // should be abi.encodePacked(type(SimpleArgContract).creationCode, abi.encode(42))
        create3LibHarness.create3(salt, type(SimpleArgContract).creationCode, 0);
    }
}
