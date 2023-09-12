// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockERC20, LinkedPoolTest, TokenTree} from "./LinkedPool.t.sol";

import {MockPoolModule} from "../mocks/MockPoolModule.sol";

// solhint-disable func-name-mixedcase
contract LinkedPoolModuleTest is LinkedPoolTest {
    address public newPoolModule;

    event PoolModuleUpdated(address pool, address oldPoolModule, address newPoolModule);

    function setUp() public virtual override {
        poolModule = address(new MockPoolModule());
        newPoolModule = address(new MockPoolModule());
        super.setUp();
    }

    // ═════════════════════════════════════════ UPDATE POOL MODULE TESTS ══════════════════════════════════════════════

    function test_updatePoolModule() public {
        // Setup with two pools: poolB2 and pool02
        compactSetup();
        vm.prank(owner);
        linkedPool.updatePoolModule(address(poolB2), newPoolModule);
        // Check that poolB2 has new pool module
        assertEq(linkedPool.getPoolModule(address(poolB2)), newPoolModule);
        // Check that pool02 has old pool module
        assertEq(linkedPool.getPoolModule(address(pool02)), poolModule);
    }

    function test_updatePoolModule_emitsEvent() public {
        // Setup with two pools: poolB2 and pool02
        compactSetup();
        vm.expectEmit();
        emit PoolModuleUpdated(address(poolB2), poolModule, newPoolModule);
        vm.recordLogs();
        vm.prank(owner);
        linkedPool.updatePoolModule(address(poolB2), newPoolModule);
        // Should be exactly one event
        assertEq(vm.getRecordedLogs().length, 1);
    }

    function test_updatePoolModule_revert_callerNotOwner(address caller) public {
        vm.assume(caller != owner);
        compactSetup();
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        linkedPool.updatePoolModule(address(poolB2), newPoolModule);
    }

    function test_updatePoolModule_revert_tokenListShorter() public {
        compactSetup();
        // Correct list: [BT, T2]; Wrong list: [BT]
        address[] memory wrongTokensList = new address[](1);
        wrongTokensList[0] = address(bridgeToken);
        // Force newPoolModule.getPoolTokens(poolB2) to return wrongTokensList
        vm.mockCall(
            newPoolModule,
            abi.encodeWithSelector(MockPoolModule.getPoolTokens.selector, poolB2),
            abi.encode(wrongTokensList)
        );
        vm.expectRevert(TokenTree.TokenTree__DifferentTokenLists.selector);
        vm.prank(owner);
        linkedPool.updatePoolModule(address(poolB2), newPoolModule);
    }

    function test_updatePoolModule_revert_tokenListLonger() public {
        compactSetup();
        // Correct list: [BT, T2]; Wrong list: [BT, T2, T3]
        address[] memory wrongTokensList = new address[](3);
        wrongTokensList[0] = address(bridgeToken);
        wrongTokensList[1] = address(token2);
        wrongTokensList[2] = address(token3);
        // Force newPoolModule.getPoolTokens(poolB2) to return wrongTokensList
        vm.mockCall(
            newPoolModule,
            abi.encodeWithSelector(MockPoolModule.getPoolTokens.selector, poolB2),
            abi.encode(wrongTokensList)
        );
        vm.expectRevert(TokenTree.TokenTree__DifferentTokenLists.selector);
        vm.prank(owner);
        linkedPool.updatePoolModule(address(poolB2), newPoolModule);
    }

    function test_updatePoolModule_revert_tokenListSameLengthIncorrectOrder() public {
        compactSetup();
        // Correct list: [BT, T2]; Wrong list: [T2, BT]
        address[] memory wrongTokensList = new address[](2);
        wrongTokensList[0] = address(token2);
        wrongTokensList[1] = address(bridgeToken);
        // Force newPoolModule.getPoolTokens(poolB2) to return wrongTokensList
        vm.mockCall(
            newPoolModule,
            abi.encodeWithSelector(MockPoolModule.getPoolTokens.selector, poolB2),
            abi.encode(wrongTokensList)
        );
        vm.expectRevert(TokenTree.TokenTree__DifferentTokenLists.selector);
        vm.prank(owner);
        linkedPool.updatePoolModule(address(poolB2), newPoolModule);
    }

    function test_updatePoolModule_revert_tokenListSameLengthIncorrectToken0() public {
        compactSetup();
        // Correct list: [BT, T2]; Wrong list: [T3, T2]
        address[] memory wrongTokensList = new address[](2);
        wrongTokensList[0] = address(token3);
        wrongTokensList[1] = address(token2);
        // Force newPoolModule.getPoolTokens(poolB2) to return wrongTokensList
        vm.mockCall(
            newPoolModule,
            abi.encodeWithSelector(MockPoolModule.getPoolTokens.selector, poolB2),
            abi.encode(wrongTokensList)
        );
        vm.expectRevert(TokenTree.TokenTree__DifferentTokenLists.selector);
        vm.prank(owner);
        linkedPool.updatePoolModule(address(poolB2), newPoolModule);
    }

    function test_updatePoolModule_revert_tokenListSameLengthIncorrectToken1() public {
        compactSetup();
        // Correct list: [BT, T2]; Wrong list: [BT, T3]
        address[] memory wrongTokensList = new address[](2);
        wrongTokensList[0] = address(bridgeToken);
        wrongTokensList[1] = address(token3);
        // Force newPoolModule.getPoolTokens(poolB2) to return wrongTokensList
        vm.mockCall(
            newPoolModule,
            abi.encodeWithSelector(MockPoolModule.getPoolTokens.selector, poolB2),
            abi.encode(wrongTokensList)
        );
        vm.expectRevert(TokenTree.TokenTree__DifferentTokenLists.selector);
        vm.prank(owner);
        linkedPool.updatePoolModule(address(poolB2), newPoolModule);
    }
}
