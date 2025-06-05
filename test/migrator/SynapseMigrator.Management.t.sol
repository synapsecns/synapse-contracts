// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseMigrator, ISynapseMigratorErrors} from "../../contracts/migrator/SynapseMigrator.sol";

import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";

import {Test} from "forge-std/Test.sol";

// solhint-disable func-name-mixedcase
contract SynapseMigratorManagementTest is Test, ISynapseMigratorErrors {
    event TokenPairAdded(address indexed oldToken, address indexed newToken);

    SynapseMigrator internal migrator;
    address internal owner = makeAddr("owner");

    address internal oldToken = makeAddr("oldToken");
    address internal newToken = makeAddr("newToken");
    address internal anotherToken = makeAddr("anotherToken");

    function setUp() public {
        migrator = new SynapseMigrator(owner);

        vm.mockCall({
            callee: oldToken,
            data: abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            returnData: abi.encode(18)
        });
        vm.mockCall({
            callee: newToken,
            data: abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            returnData: abi.encode(6)
        });
        vm.mockCall({
            callee: anotherToken,
            data: abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            returnData: abi.encode(6)
        });
    }

    function test_constructor() public {
        assertEq(migrator.owner(), owner);
        assertEq(migrator.getTokenPair(oldToken), address(0));
    }

    function test_constructor_revert_zeroOwner() public {
        vm.expectRevert("Ownable: new owner is the zero address");
        new SynapseMigrator(address(0));
    }

    function test_addTokenPair() public {
        vm.expectEmit(address(migrator));
        emit TokenPairAdded(oldToken, newToken);
        vm.prank(owner);
        migrator.addTokenPair(oldToken, newToken);
        assertEq(migrator.getTokenPair(oldToken), newToken);
        assertEq(migrator.getTokenPair(newToken), address(0));
    }

    function test_addTokenPair_revert_oldTokenZero() public {
        vm.expectRevert(SM__ZeroAddress.selector);
        vm.prank(owner);
        migrator.addTokenPair(address(0), newToken);
    }

    function test_addTokenPair_revert_newTokenZero() public {
        vm.expectRevert(SM__ZeroAddress.selector);
        vm.prank(owner);
        migrator.addTokenPair(oldToken, address(0));
    }

    function test_addTokenPair_revert_sameTokens() public {
        vm.expectRevert(SM__SameAddress.selector);
        vm.prank(owner);
        migrator.addTokenPair(oldToken, oldToken);
    }

    function test_addTokenPair_revert_oldTokenAlreadyAdded() public {
        vm.prank(owner);
        migrator.addTokenPair(oldToken, newToken);
        // Same address
        vm.expectRevert(SM__TokenPairAlreadyAdded.selector);
        vm.prank(owner);
        migrator.addTokenPair(oldToken, newToken);
        // New address
        vm.expectRevert(SM__TokenPairAlreadyAdded.selector);
        vm.prank(owner);
        migrator.addTokenPair(oldToken, anotherToken);
    }

    function test_addTokenPair_revert_callerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        migrator.addTokenPair(oldToken, newToken);
    }
}
