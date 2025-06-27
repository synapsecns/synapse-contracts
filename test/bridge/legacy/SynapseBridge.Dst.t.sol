// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseBridge, IERC20, ERC20Burnable, IERC20Mintable, ISwap} from "../../../contracts/bridge/SynapseBridge.sol";

import {ReenteringToken} from "./ReenteringToken.sol";
import {PoolMock} from "./PoolMock.sol";
import {SynapseBridgeProxyTest} from "./SynapseBridge.Proxy.t.sol";

// solhint-disable func-name-mixedcase
contract SynapseBridgeLegacyDstTest is SynapseBridgeProxyTest {
    ReenteringToken internal token;
    address internal pool;

    address internal nodeGroup = makeAddr("NodeGroup");
    address internal user = makeAddr("User");
    bytes32 internal kappa = keccak256("kappa");

    uint256 internal initialLockedBalance = 1000 ether;
    uint256 internal amount = 1 ether;
    uint256 internal fee = 0.01 ether;

    event TokenWithdraw(address indexed to, address token, uint256 amount, uint256 fee, bytes32 indexed kappa);
    event TokenMint(address indexed to, address token, uint256 amount, uint256 fee, bytes32 indexed kappa);
    event TokenMintAndSwap(
        address indexed to,
        address token,
        uint256 amount,
        uint256 fee,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bool swapSuccess,
        bytes32 indexed kappa
    );
    event TokenWithdrawAndRemove(
        address indexed to,
        address token,
        uint256 amount,
        uint256 fee,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bool swapSuccess,
        bytes32 indexed kappa
    );

    event TokenDeposit(address indexed to, uint256 chainId, address token, uint256 amount);

    modifier withMintToken() {
        token.grantRole(token.MINTER_ROLE(), address(bridge));
        _;
    }

    modifier withWithdrawToken() {
        deal(address(token), address(bridge), initialLockedBalance, true);
        _;
    }

    modifier withRevertingPool() {
        vm.mockCallRevert({callee: address(pool), data: "", revertData: "GM"});
        _;
    }

    modifier withLegacySendDisabled() {
        bridge.setLegacySendDisabled(true);
        _;
    }

    function prepareReentrancyData() public {
        token.setReenteringData(
            address(bridge),
            abi.encodeWithSelector(bridge.deposit.selector, address(user), 1, address(token), 0)
        );
    }

    function expectMintEvent() public {
        vm.expectEmit(address(bridge));
        emit TokenMint(user, address(token), amount - fee, fee, kappa);
    }

    function expectMintAndSwapEvent() public {
        vm.expectEmit(address(bridge));
        emit TokenMintAndSwap(user, address(token), amount - fee, fee, 0, 0, 1, 0, false, kappa);
    }

    function expectWithdrawEvent() public {
        // Note: TokenWithdraw emits amount before fees, which is left as is to preserve legacy behavior
        vm.expectEmit(address(bridge));
        emit TokenWithdraw(user, address(token), amount, fee, kappa);
    }

    function expectWithdrawAndRemoveEvent() public {
        vm.expectEmit(address(bridge));
        emit TokenWithdrawAndRemove(user, address(token), amount - fee, fee, 0, 1, 0, false, kappa);
    }

    function expectReentrancyDepositEvent() public {
        vm.expectEmit(address(bridge));
        emit TokenDeposit(user, 1, address(token), 0);
    }

    function expectBalances(
        uint256 bridgeBalance,
        uint256 userBalance,
        uint256 bridgeFees
    ) public {
        assertEq(token.balanceOf(address(bridge)), bridgeBalance);
        assertEq(token.balanceOf(user), userBalance);
        assertEq(bridge.getFeeBalance(address(token)), bridgeFees);
    }

    function setUp() public virtual override {
        super.setUp();
        bridge.initialize();
        bridge.grantRole(bridge.GOVERNANCE_ROLE(), address(this));
        bridge.grantRole(bridge.NODEGROUP_ROLE(), nodeGroup);

        token = new ReenteringToken();
        token.initialize("Test", "TST", 18, address(this));

        pool = address(new PoolMock());
    }

    function test_mint() public withMintToken {
        expectMintEvent();
        vm.prank(nodeGroup);
        bridge.mint(payable(user), IERC20Mintable(address(token)), amount, fee, kappa);
        expectBalances({bridgeBalance: fee, userBalance: amount - fee, bridgeFees: fee});
        assertTrue(bridge.kappaExists(kappa));
    }

    function test_mintAndSwap() public withMintToken {
        expectMintAndSwapEvent();
        vm.prank(nodeGroup);
        // Use minDy > 0 so that it exceeds calculateSwap = 0 (swapSuccess = false).
        bridge.mintAndSwap(payable(user), IERC20Mintable(address(token)), amount, fee, ISwap(pool), 0, 0, 1, 0, kappa);
        expectBalances({bridgeBalance: fee, userBalance: amount - fee, bridgeFees: fee});
        assertTrue(bridge.kappaExists(kappa));
    }

    function test_mintAndSwap_reverts_withRevertingPool() public withMintToken withRevertingPool {
        vm.expectRevert(bytes("GM"));
        vm.prank(nodeGroup);
        bridge.mintAndSwap(payable(user), IERC20Mintable(address(token)), amount, fee, ISwap(pool), 0, 0, 1, 0, kappa);
    }

    /// @notice Should behave the same way as the legacy workflow.
    function test_mint_legacySendDisabled() public withLegacySendDisabled {
        test_mint();
    }

    /// @notice Should ignore andSwap instructions in legacySendDisabled mode.
    function test_mintAndSwap_legacySendDisabled_mintFallback() public withLegacySendDisabled withMintToken {
        expectMintEvent();
        vm.prank(nodeGroup);
        bridge.mintAndSwap(payable(user), IERC20Mintable(address(token)), amount, fee, ISwap(pool), 0, 0, 1, 0, kappa);
        expectBalances({bridgeBalance: fee, userBalance: amount - fee, bridgeFees: fee});
        assertTrue(bridge.kappaExists(kappa));
    }

    /// @notice Pool is never called in legacySendDisabled mode, so should be identical to mint fallback.
    function test_mintAndSwap_legacySendDisabled_mintFallback_withRevertingPool() public withRevertingPool {
        test_mintAndSwap_legacySendDisabled_mintFallback();
    }

    function test_withdraw() public withWithdrawToken {
        expectWithdrawEvent();
        vm.prank(nodeGroup);
        bridge.withdraw(payable(user), IERC20(address(token)), amount, fee, kappa);
        expectBalances({
            bridgeBalance: initialLockedBalance - amount + fee,
            userBalance: amount - fee,
            bridgeFees: fee
        });
        assertTrue(bridge.kappaExists(kappa));
    }

    function test_withdrawAndRemove() public withWithdrawToken {
        expectWithdrawAndRemoveEvent();
        vm.prank(nodeGroup);
        // Use swapMinAmount > 0 so that it exceeds calculateRemoveLiquidityOneToken = 0 (swapSuccess = false).
        bridge.withdrawAndRemove(payable(user), IERC20(address(token)), amount, fee, ISwap(pool), 0, 1, 0, kappa);
        expectBalances({
            bridgeBalance: initialLockedBalance - amount + fee,
            userBalance: amount - fee,
            bridgeFees: fee
        });
        assertTrue(bridge.kappaExists(kappa));
    }

    function test_withdrawAndRemove_reverts_withRevertingPool() public withRevertingPool {
        vm.expectRevert(bytes("GM"));
        vm.prank(nodeGroup);
        bridge.withdrawAndRemove(payable(user), IERC20(address(token)), amount, fee, ISwap(pool), 0, 1, 0, kappa);
    }

    /// @notice Should behave the same way as the legacy workflow.
    function test_withdraw_legacySendDisabled() public withLegacySendDisabled {
        test_withdraw();
    }

    /// @notice Should ignore andRemove instructions in legacySendDisabled mode.
    function test_withdrawAndRemove_legacySendDisabled_withdrawFallback()
        public
        withLegacySendDisabled
        withWithdrawToken
    {
        expectWithdrawEvent();
        vm.prank(nodeGroup);
        bridge.withdrawAndRemove(payable(user), IERC20(address(token)), amount, fee, ISwap(pool), 0, 1, 0, kappa);
        expectBalances({
            bridgeBalance: initialLockedBalance - amount + fee,
            userBalance: amount - fee,
            bridgeFees: fee
        });
        assertTrue(bridge.kappaExists(kappa));
    }

    /// @notice Pool is never called in legacySendDisabled mode, so should be identical to withdraw fallback.
    function test_withdrawAndRemove_legacySendDisabled_withdrawFallback_withRevertingPool() public withRevertingPool {
        test_withdrawAndRemove_legacySendDisabled_withdrawFallback();
    }

    // ═════════════════════════════════════════════ TESTS: REENTRANCY ═════════════════════════════════════════════════

    function test_setupReentrancyMint() public withMintToken {
        token.grantRole(token.MINTER_ROLE(), address(this));
        prepareReentrancyData();
        expectReentrancyDepositEvent();
        token.mint(address(user), 0);
    }

    function test_setupReentrancyTransfer() public withWithdrawToken {
        prepareReentrancyData();
        expectReentrancyDepositEvent();
        token.transfer(address(user), 0);
    }

    function test_mint_reverts_withReentrancy() public withMintToken {
        prepareReentrancyData();
        vm.expectRevert("ReentrancyGuard: reentrant call");
        vm.prank(nodeGroup);
        bridge.mint(payable(user), IERC20Mintable(address(token)), amount, fee, kappa);
    }

    function test_mintAndSwap_reverts_withReentrancy() public withMintToken {
        prepareReentrancyData();
        vm.expectRevert("ReentrancyGuard: reentrant call");
        vm.prank(nodeGroup);
        bridge.mintAndSwap(payable(user), IERC20Mintable(address(token)), amount, fee, ISwap(pool), 0, 0, 1, 0, kappa);
    }

    function test_mint_legacySendDisabled_reverts_withReentrancy() public withLegacySendDisabled {
        test_mint_reverts_withReentrancy();
    }

    function test_mintAndSwap_legacySendDisabled_reverts_withReentrancy() public withLegacySendDisabled {
        test_mintAndSwap_reverts_withReentrancy();
    }

    function test_withdraw_reverts_withReentrancy() public withWithdrawToken {
        prepareReentrancyData();
        vm.expectRevert("ReentrancyGuard: reentrant call");
        vm.prank(nodeGroup);
        bridge.withdraw(payable(user), IERC20(address(token)), amount, fee, kappa);
    }

    function test_withdrawAndRemove_reverts_withReentrancy() public withWithdrawToken {
        prepareReentrancyData();
        vm.expectRevert("ReentrancyGuard: reentrant call");
        vm.prank(nodeGroup);
        bridge.withdrawAndRemove(payable(user), IERC20(address(token)), amount, fee, ISwap(pool), 0, 1, 0, kappa);
    }

    function test_withdraw_legacySendDisabled_reverts_withReentrancy() public withLegacySendDisabled {
        test_withdraw_reverts_withReentrancy();
    }

    function test_withdrawAndRemove_legacySendDisabled_reverts_withReentrancy() public withLegacySendDisabled {
        test_withdrawAndRemove_reverts_withReentrancy();
    }

    // ══════════════════════════════════════════ TESTS: NODE GROUP ONLY ═══════════════════════════════════════════════

    function test_mint_reverts_callerNotNodeGroup(address caller) public withMintToken {
        vm.assume(caller != nodeGroup);
        vm.prank(caller);
        vm.expectRevert("Caller is not a node group");
        bridge.mint(payable(user), IERC20Mintable(address(token)), amount, fee, kappa);
    }

    function test_mintAndSwap_reverts_callerNotNodeGroup(address caller) public withMintToken {
        vm.assume(caller != nodeGroup);
        vm.prank(caller);
        vm.expectRevert("Caller is not a node group");
        bridge.mintAndSwap(payable(user), IERC20Mintable(address(token)), amount, fee, ISwap(pool), 0, 0, 1, 0, kappa);
    }

    function test_mint_legacySendDisabled_reverts_callerNotNodeGroup(address caller) public withLegacySendDisabled {
        test_mint_reverts_callerNotNodeGroup(caller);
    }

    function test_mintAndSwap_legacySendDisabled_reverts_callerNotNodeGroup(address caller)
        public
        withLegacySendDisabled
    {
        test_mintAndSwap_reverts_callerNotNodeGroup(caller);
    }

    function test_withdraw_reverts_callerNotNodeGroup(address caller) public withWithdrawToken {
        vm.assume(caller != nodeGroup);
        vm.prank(caller);
        vm.expectRevert("Caller is not a node group");
        bridge.withdraw(payable(user), IERC20(address(token)), amount, fee, kappa);
    }

    function test_withdrawAndRemove_reverts_callerNotNodeGroup(address caller) public withWithdrawToken {
        vm.assume(caller != nodeGroup);
        vm.prank(caller);
        vm.expectRevert("Caller is not a node group");
        bridge.withdrawAndRemove(payable(user), IERC20(address(token)), amount, fee, ISwap(pool), 0, 1, 0, kappa);
    }

    function test_withdraw_legacySendDisabled_reverts_callerNotNodeGroup(address caller) public withLegacySendDisabled {
        test_withdraw_reverts_callerNotNodeGroup(caller);
    }

    function test_withdrawAndRemove_legacySendDisabled_reverts_callerNotNodeGroup(address caller)
        public
        withLegacySendDisabled
    {
        test_withdrawAndRemove_reverts_callerNotNodeGroup(caller);
    }
}
