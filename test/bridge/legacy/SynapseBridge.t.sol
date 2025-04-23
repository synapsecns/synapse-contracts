// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseBridge, IERC20, ERC20Burnable} from "../../../contracts/bridge/SynapseBridge.sol";
import {SynapseERC20} from "../../../contracts/bridge/SynapseERC20.sol";

import {Test} from "forge-std/Test.sol";

// solhint-disable func-name-mixedcase
contract SynapseBridgeLegacyTest is Test {
    SynapseBridge internal bridge;
    SynapseERC20 internal token;

    address internal user = makeAddr("User");
    address internal governance = makeAddr("Governance");

    event TokenDeposit(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenRedeem(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenDepositAndSwap(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenRedeemAndSwap(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenRedeemAndRemove(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline
    );

    event TokenRedeemV2(bytes32 indexed to, uint256 chainId, address token, uint256 amount);

    function setUp() public {
        bridge = new SynapseBridge();
        bridge.initialize();
        bridge.grantRole(bridge.GOVERNANCE_ROLE(), governance);

        token = new SynapseERC20();
        token.initialize("Test", "TST", 18, address(this));
        token.grantRole(token.MINTER_ROLE(), address(this));

        token.mint(user, 1 ether);
        vm.prank(user);
        token.approve(address(bridge), type(uint256).max);
    }

    function disableLegacySend() public {
        vm.prank(governance);
        bridge.setLegacySendDisabled(true);
    }

    function enableLegacySend() public {
        vm.prank(governance);
        bridge.setLegacySendDisabled(false);
    }

    function test_disableLegacySend() public {
        disableLegacySend();
        assertTrue(bridge.isLegacySendDisabled());
    }

    function test_enableLegacySend() public {
        disableLegacySend();
        enableLegacySend();
        assertFalse(bridge.isLegacySendDisabled());
    }

    function test_setLegacySendDisabled_revert_notGovernance(address caller) public {
        vm.assume(caller != governance);
        vm.prank(caller);
        vm.expectRevert("Not governance");
        bridge.setLegacySendDisabled(true);
    }

    function test_withdrawChainGas() public {
        deal(address(bridge), 123456);
        vm.prank(governance);
        bridge.withdrawChainGas();
        assertEq(governance.balance, 123456);
    }

    function test_withdrawChainGas_revert_notGovernance(address caller) public {
        deal(address(bridge), 123456);
        vm.assume(caller != governance);
        vm.prank(caller);
        vm.expectRevert("Not governance");
        bridge.withdrawChainGas();
    }

    function test_deposit() public {
        vm.expectEmit(address(bridge));
        emit TokenDeposit({to: address(1), chainId: 2, token: address(token), amount: 3});
        vm.prank(user);
        bridge.deposit({to: address(1), chainId: 2, token: IERC20(address(token)), amount: 3});
    }

    function test_deposit_reenabled() public {
        disableLegacySend();
        enableLegacySend();
        test_deposit();
    }

    function test_deposit_revert_disabled() public {
        disableLegacySend();
        vm.expectRevert("Legacy bridge is disabled");
        vm.prank(user);
        bridge.deposit({to: address(1), chainId: 2, token: IERC20(address(token)), amount: 3});
    }

    function test_depositAndSwap() public {
        vm.expectEmit(address(bridge));
        emit TokenDepositAndSwap({
            to: address(1),
            chainId: 2,
            token: address(token),
            amount: 3,
            tokenIndexFrom: 4,
            tokenIndexTo: 5,
            minDy: 6,
            deadline: 7
        });
        vm.prank(user);
        bridge.depositAndSwap({
            to: address(1),
            chainId: 2,
            token: IERC20(address(token)),
            amount: 3,
            tokenIndexFrom: 4,
            tokenIndexTo: 5,
            minDy: 6,
            deadline: 7
        });
    }

    function test_depositAndSwap_reenabled() public {
        disableLegacySend();
        enableLegacySend();
        test_depositAndSwap();
    }

    function test_depositAndSwap_revert_disabled() public {
        disableLegacySend();
        vm.expectRevert("Legacy bridge is disabled");
        vm.prank(user);
        bridge.depositAndSwap({
            to: address(1),
            chainId: 2,
            token: IERC20(address(token)),
            amount: 3,
            tokenIndexFrom: 4,
            tokenIndexTo: 5,
            minDy: 6,
            deadline: 7
        });
    }

    function test_redeem() public {
        vm.expectEmit(address(bridge));
        emit TokenRedeem({to: address(1), chainId: 2, token: address(token), amount: 3});
        vm.prank(user);
        bridge.redeem({to: address(1), chainId: 2, token: ERC20Burnable(address(token)), amount: 3});
    }

    function test_redeem_reenabled() public {
        disableLegacySend();
        enableLegacySend();
        test_redeem();
    }

    function test_redeem_revert_disabled() public {
        disableLegacySend();
        vm.expectRevert("Legacy bridge is disabled");
        vm.prank(user);
        bridge.redeem({to: address(1), chainId: 2, token: ERC20Burnable(address(token)), amount: 3});
    }

    function test_redeemAndSwap() public {
        vm.expectEmit(address(bridge));
        emit TokenRedeemAndSwap({
            to: address(1),
            chainId: 2,
            token: address(token),
            amount: 3,
            tokenIndexFrom: 4,
            tokenIndexTo: 5,
            minDy: 6,
            deadline: 7
        });
        vm.prank(user);
        bridge.redeemAndSwap({
            to: address(1),
            chainId: 2,
            token: ERC20Burnable(address(token)),
            amount: 3,
            tokenIndexFrom: 4,
            tokenIndexTo: 5,
            minDy: 6,
            deadline: 7
        });
    }

    function test_redeemAndSwap_reenabled() public {
        disableLegacySend();
        enableLegacySend();
        test_redeemAndSwap();
    }

    function test_redeemAndSwap_revert_disabled() public {
        disableLegacySend();
        vm.expectRevert("Legacy bridge is disabled");
        vm.prank(user);
        bridge.redeemAndSwap({
            to: address(1),
            chainId: 2,
            token: ERC20Burnable(address(token)),
            amount: 3,
            tokenIndexFrom: 4,
            tokenIndexTo: 5,
            minDy: 6,
            deadline: 7
        });
    }

    function test_redeemAndRemove() public {
        vm.expectEmit(address(bridge));
        emit TokenRedeemAndRemove({
            to: address(1),
            chainId: 2,
            token: address(token),
            amount: 3,
            swapTokenIndex: 4,
            swapMinAmount: 5,
            swapDeadline: 6
        });
        vm.prank(user);
        bridge.redeemAndRemove({
            to: address(1),
            chainId: 2,
            token: ERC20Burnable(address(token)),
            amount: 3,
            swapTokenIndex: 4,
            swapMinAmount: 5,
            swapDeadline: 6
        });
    }

    function test_redeemAndRemove_reenabled() public {
        disableLegacySend();
        enableLegacySend();
        test_redeemAndRemove();
    }

    function test_redeemAndRemove_revert_disabled() public {
        disableLegacySend();
        vm.expectRevert("Legacy bridge is disabled");
        vm.prank(user);
        bridge.redeemAndRemove({
            to: address(1),
            chainId: 2,
            token: ERC20Burnable(address(token)),
            amount: 3,
            swapTokenIndex: 4,
            swapMinAmount: 5,
            swapDeadline: 6
        });
    }

    function test_redeemV2() public {
        vm.expectEmit(address(bridge));
        emit TokenRedeemV2({to: bytes32(uint256(1)), chainId: 2, token: address(token), amount: 3});
        vm.prank(user);
        bridge.redeemV2({to: bytes32(uint256(1)), chainId: 2, token: ERC20Burnable(address(token)), amount: 3});
    }

    function test_redeemV2_reenabled() public {
        disableLegacySend();
        enableLegacySend();
        test_redeemV2();
    }

    function test_redeemV2_revert_disabled() public {
        disableLegacySend();
        vm.expectRevert("Legacy bridge is disabled");
        vm.prank(user);
        bridge.redeemV2({to: bytes32(uint256(1)), chainId: 2, token: ERC20Burnable(address(token)), amount: 3});
    }
}
