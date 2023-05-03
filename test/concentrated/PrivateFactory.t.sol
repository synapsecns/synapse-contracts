// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "../../contracts/concentrated/PrivateFactory.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockAccessToken.sol";

contract PrivateFactoryTest is Test {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public constant BRIDGE = address(0xB);

    PrivateFactory public factory;
    MockToken public token;
    MockAccessToken public synToken;

    function setUp() public {
        factory = new PrivateFactory(BRIDGE);
        token = new MockToken("X", "X", 18);

        synToken = new MockAccessToken("synX", "synX", 18);
        synToken.grantRole(MINTER_ROLE, BRIDGE);
    }

    function testSetup() public {
        assertEq(token.symbol(), "X");
        assertEq(synToken.symbol(), "synX");
        assertEq(synToken.hasRole(MINTER_ROLE, BRIDGE), true);
    }

    function testConstructor() public {
        assertEq(factory.bridge(), BRIDGE);
    }
}
