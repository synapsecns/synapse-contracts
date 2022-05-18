pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../contracts/messaging/AuthVerifier.sol";

contract AuthVerifierTest is Test {
    AuthVerifier public authVerifier;

    function setUp() public {
        authVerifier = new AuthVerifier(address(1337));
    }

    function testConstructor() public {
        assertEq(authVerifier.nodegroup(), address(1337));
        assertEq(authVerifier.owner(), address(this));
    }

    function testAuthorizedNodeGroupSet() public {
        authVerifier.setNodeGroup(address(7331));
        assertEq(authVerifier.nodegroup(), address(7331));
    }

    function testFailUnauthorizedNodeGroupSet() public {
        vm.prank(address(9999));
        authVerifier.setNodeGroup(address(7331));
    }

    function testMsgAuth() public {
        bytes memory authData = abi.encode(address(1337));
        bool authenticated = authVerifier.msgAuth(authData);
        assertTrue(authenticated);
    }

    function testCannotMsgAuth() public {
        bytes memory authData = abi.encode(address(420));
        vm.expectRevert("Unauthenticated caller");
        authVerifier.msgAuth(authData);
    }

    // Direclty packing encode will fail on abi.decode
    function testCannotMsgAuthABIPacked() public {
        bytes memory authData = abi.encodePacked(address(1337));
        // expect solc to reject decoding encodePacked
        vm.expectRevert();
        authVerifier.msgAuth(authData);
    }

    // Another way to abi.encode(address) correctly
    function testMsgAuthViaBytes32LeftPadded() public {
        bytes32 authdata32 = bytes32(uint256(uint160(address(1337))));
        bytes memory authdata = abi.encodePacked(authdata32);
        bool authed = authVerifier.msgAuth(authdata);
        assertTrue(authed);
    }

    // Fails, doesn't conform to abi.encode(address) due to being right padded
    function testMsgAuthViaBytes32RightPadded() public {
        bytes32 authdata32 = bytes32(uint256(uint160(address(1337))) << 96);
        console.logBytes32(authdata32);
        bytes memory authdata = abi.encodePacked(authdata32);
        // This successfully is decoded by abi.decode, but the incorrect address is derived due to padding
        // E.g 0x0000000000000539000000000000000000000000 instead of 0x0000000000000000000000000000000000000539
        // This is due to the 64bytes 0000000000000000000000000000000000000539000000000000000000000000
        // instead of 0x0000000000000000000000000000000000000000000000000000000000000539
        console.log(abi.decode(authdata, (address)));
        console.log(address(1337));
        console.logBytes(abi.encode(address(1337)));
        vm.expectRevert("Unauthenticated caller");
        authVerifier.msgAuth(authdata);
    }
}
