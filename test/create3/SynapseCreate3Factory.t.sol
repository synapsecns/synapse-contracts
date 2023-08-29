// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseCreate3Factory} from "../../contracts/create3/SynapseCreate3Factory.sol";
import {InitializableContract} from "./mocks/InitializableContract.sol";

import {console, Test} from "forge-std/Test.sol";

contract SynapseCreate3FactoryTest is Test {
    SynapseCreate3Factory public factory;
    address public deployer;

    address public initializableReference;

    uint256 public msgValue;
    bytes public initData;

    function setUp() public {
        factory = new SynapseCreate3Factory();
        deployer = makeAddr("Deployer");
        initializableReference = address(new InitializableContract());
    }

    function testSafeCreate3DeploysContract(bytes12 shortSalt) public returns (address deployedAddress) {
        bytes32 salt = constructSalt(deployer, shortSalt);
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

    function testSafeCreate3DeploysContractWithEther(bytes12 shortSalt, uint256 value)
        public
        returns (address deployedAddress)
    {
        deal(deployer, value);
        msgValue = value;
        deployedAddress = testSafeCreate3DeploysContract(shortSalt);
        assertEq(address(deployedAddress).balance, value);
    }

    function testSafeCreate3DeploysContractWithInitData(bytes12 shortSalt, uint256 argValue)
        public
        returns (address deployedAddress)
    {
        initData = abi.encodeWithSelector(InitializableContract.setValue.selector, argValue);
        deployedAddress = testSafeCreate3DeploysContract(shortSalt);
        assertEq(InitializableContract(deployedAddress).value(), argValue);
    }

    function testSafeCreate3DeploysContractWithEtherAndInitData(
        bytes12 shortSalt,
        uint256 value,
        uint256 argValue
    ) public {
        initData = abi.encodeWithSelector(InitializableContract.setValue.selector, argValue);
        address deployedAddress = testSafeCreate3DeploysContractWithEther(shortSalt, value);
        assertEq(InitializableContract(deployedAddress).value(), argValue);
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function constructSalt(address caller, bytes12 shortSalt) public pure returns (bytes32 salt) {
        // Lowest 12 bytes are the "short salt"
        salt = bytes32(uint256(uint96(shortSalt)));
        // Highest 20 bytes are the caller
        salt |= bytes32(uint256(uint160(caller)) << 96);
    }
}
