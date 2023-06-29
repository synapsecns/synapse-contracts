// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TokenNotContract} from "../../../contracts/router/libs/Errors.sol";
import {UniversalTokenLibHarness} from "../harnesses/UniversalTokenLibHarness.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockRevertingRecipient} from "../mocks/MockRevertingRecipient.sol";

import {Test} from "forge-std/Test.sol";

contract UniversalTokenLibraryTest is Test {
    UniversalTokenLibHarness public libHarness;
    MockERC20 public token;
    address public recipient;

    function setUp() public {
        libHarness = new UniversalTokenLibHarness();
        token = new MockERC20("Mock", 18);
        recipient = makeAddr("Recipient");
    }

    function testUniversalTransferToken() public {
        uint256 amount = 12345;
        token.mint(address(libHarness), amount);
        libHarness.universalTransfer(address(token), recipient, amount);
        assertEq(token.balanceOf(address(libHarness)), 0);
        assertEq(token.balanceOf(address(recipient)), amount);
    }

    function testUniversalTransferTokenNoopWhenSameRecipient() public {
        uint256 amount = 12345;
        token.mint(address(libHarness), amount);
        vm.mockCallRevert(
            address(token),
            abi.encodeWithSelector(token.transfer.selector, address(libHarness)),
            "Disabled transfers to harness"
        );
        // Should not revert, as the transfer is a noop due to the same recipient
        libHarness.universalTransfer(address(token), address(libHarness), amount);
        assertEq(token.balanceOf(address(libHarness)), amount);
        // Trying to transfer to the harness should still revert
        token.mint(address(this), amount);
        vm.expectRevert("Disabled transfers to harness");
        token.transfer(address(libHarness), amount);
    }

    function testUniversalTransferETH() public {
        uint256 amount = 12345;
        deal(address(libHarness), amount);
        libHarness.universalTransfer(libHarness.ethAddress(), recipient, amount);
        assertEq(address(libHarness).balance, 0);
        assertEq(address(recipient).balance, amount);
    }

    function testUniversalTransferETHNoopWhenSameRecipient() public {
        uint256 amount = 12345;
        deal(address(libHarness), amount);
        // Should not revert, as the transfer is a noop due to the same recipient
        libHarness.universalTransfer(libHarness.ethAddress(), address(libHarness), amount);
        assertEq(address(libHarness).balance, amount);
        // Simply sending ETH to the harness should still revert (no receive/fallback)
        deal(address(this), amount);
        (bool success, ) = address(libHarness).call{value: amount}("");
        assertEq(success, false);
    }

    function testUniversalTransferETHRevertsWhenRecipientDeclined() public {
        uint256 amount = 12345;
        deal(address(libHarness), amount);
        address eth = libHarness.ethAddress();
        address revertingRecipient = address(new MockRevertingRecipient());
        vm.expectRevert("ETH transfer failed");
        libHarness.universalTransfer(eth, revertingRecipient, amount);
    }

    function testEthAddress() public {
        // ETH address should have all bytes set to 0xEE
        address ethAddress = libHarness.ethAddress();
        for (uint256 i = 0; i < 20; i++) {
            assertEq(uint8(bytes20(ethAddress)[i]), 0xEE);
        }
    }

    function testUniversalBalanceOfWhenToken(uint256 amount) public {
        token.mint(address(libHarness), amount);
        assertEq(libHarness.universalBalanceOf(address(token), address(libHarness)), amount);
    }

    function testUniversalBalanceOfWhenETH(uint256 amount) public {
        deal(address(libHarness), amount);
        assertEq(libHarness.universalBalanceOf(libHarness.ethAddress(), address(libHarness)), amount);
    }

    function testAssertIsContractWhenContract() public view {
        // Should not revert
        libHarness.assertIsContract(address(token));
    }

    function testAssertIsContractRevertsWhenETHAddress() public {
        address eth = libHarness.ethAddress();
        vm.expectRevert(TokenNotContract.selector);
        libHarness.assertIsContract(eth);
    }

    function testAssertIsContractRevertsWhenETHAddressWithCode() public {
        address eth = libHarness.ethAddress();
        vm.etch(eth, address(token).code);
        require(eth.code.length > 0, "ETH address should have code");
        vm.expectRevert(TokenNotContract.selector);
        libHarness.assertIsContract(eth);
    }

    function testAssertIsContractRevertsWhenEOA() public {
        address eoa = makeAddr("EOA");
        vm.expectRevert(TokenNotContract.selector);
        libHarness.assertIsContract(eoa);
    }
}
