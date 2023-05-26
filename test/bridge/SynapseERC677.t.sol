// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../../contracts/bridge/SynapseERC677.sol";

contract ERC677LogEvents {
    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);

    event LogTokenTransfer(address, uint256, bytes);
}

contract ERC677ReceiverMock is IERC677Receiver, ERC677LogEvents {
    function onTokenTransfer(
        address _sender,
        uint256 _value,
        bytes calldata _data
    ) external override {
        emit LogTokenTransfer(_sender, _value, _data);
    }
}

contract ERC677ConstructorRecipient is IERC677Receiver {
    constructor(SynapseERC677 token) public {
        token.transferAndCall(address(this), 0, "");
    }

    function onTokenTransfer(
        address,
        uint256,
        bytes calldata
    ) external override {
        revert("Called guy");
    }
}

// solhint-disable func-name-mixedcase
contract SynapseERC677Test is ERC677LogEvents, Test {
    SynapseERC677 internal token;
    ERC677ReceiverMock internal recipient;

    function setUp() public {
        token = new SynapseERC677();
        token.initialize({name: "Mock ERC677", symbol: "M677", decimals: 18, owner: address(this)});
        recipient = new ERC677ReceiverMock();
    }

    function test_transferAndCall_toEOA(
        address sender,
        uint256 value,
        bytes memory data
    ) public {
        vm.assume(sender != address(0));
        address user = address(1337);
        deal(address(token), address(sender), value);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(sender, user, value, data);
        vm.prank(sender);
        token.transferAndCall(user, value, data);
    }

    function test_transferAndCall_toContract(
        address sender,
        uint256 value,
        bytes memory data
    ) public {
        vm.assume(sender != address(0));
        deal(address(token), address(sender), value);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(sender, address(recipient), value, data);
        vm.expectEmit(true, true, true, true, address(recipient));
        emit LogTokenTransfer(sender, value, data);
        vm.prank(sender);
        token.transferAndCall(address(recipient), value, data);
    }

    function test_transferAndCall_calledFromConstructor() public {
        // Constructor includes a transferAndCall to guy, but this should not be triggered
        ERC677ConstructorRecipient guy = new ERC677ConstructorRecipient(token);
        // Just calling the guy should lead to the revert though
        vm.expectRevert("Called guy");
        token.transferAndCall(address(guy), 0, "");
    }
}
