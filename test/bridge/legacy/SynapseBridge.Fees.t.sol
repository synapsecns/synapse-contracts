// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseBridge, IERC20} from "../../../contracts/bridge/SynapseBridge.sol";
import {ReenteringToken} from "./ReenteringToken.sol";

import {Test} from "forge-std/Test.sol";

contract Governance {
    function withdrawFees(SynapseBridge bridge, address token) public {
        bridge.withdrawFees(IERC20(token), address(this));
    }
}

// solhint-disable func-name-mixedcase
contract SynapseBridgeLegacyFeesTest is Test {
    SynapseBridge internal bridge;
    ReenteringToken internal token;
    Governance internal governance;

    uint256 internal feesAmount = 1 ether;
    uint256 internal lockedAmount = 10 ether;

    function setUp() public {
        governance = new Governance();
        bridge = new SynapseBridge();
        bridge.initialize();
        bridge.grantRole(bridge.GOVERNANCE_ROLE(), address(governance));
        bridge.grantRole(bridge.NODEGROUP_ROLE(), address(this));

        token = new ReenteringToken();
        token.initialize("Test", "TST", 18, address(this));
        token.grantRole(token.MINTER_ROLE(), address(this));

        token.mint(address(bridge), lockedAmount);
        // Withdraw to self to set up the fees without moving any tokens
        bridge.withdraw(address(bridge), IERC20(address(token)), lockedAmount, feesAmount, 0);
    }

    function test_withdrawFees() public {
        governance.withdrawFees(bridge, address(token));
        assertEq(token.balanceOf(address(governance)), feesAmount);
        assertEq(token.balanceOf(address(bridge)), lockedAmount - feesAmount);
        assertEq(bridge.getFeeBalance(address(token)), 0);
    }

    function test_withdrawFees_reentrancy() public {
        // Governance reenters withdrawFees after receiving the fees
        token.setReenteringData(
            address(governance),
            abi.encodeWithSelector(Governance.withdrawFees.selector, bridge, token)
        );
        // Second withdrawFees should be with 0 fees, so exact same end state
        test_withdrawFees();
    }

    function test_withdrawFees_reverts_notGovernance(address caller) public {
        vm.assume(caller != address(governance));
        vm.prank(caller);
        vm.expectRevert("Not governance");
        bridge.withdrawFees(IERC20(address(token)), address(1));
    }

    function test_withdrawFees_reverts_zeroRecipient() public {
        vm.prank(address(governance));
        vm.expectRevert("Address is 0x000");
        bridge.withdrawFees(IERC20(address(token)), address(0));
    }
}
