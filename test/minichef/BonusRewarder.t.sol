// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import "../../contracts/bridge/MiniChefV2.sol";
import {BonusRewarder} from "../../contracts/bridge/rewarder/BonusRewarder.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
contract BonusRewarderTest is Test {
    IERC20 internal syn;
    IERC20 internal rewardToken;
    IERC20[] internal lpTokens;

    MiniChefV2 internal miniChef;
    BonusRewarder internal bonusRewarder;

    uint256 internal rewardDeadline;
    uint256 internal rewardPerSecond;
    uint256 internal poolsAdded;
    uint256 internal totalAllocPoint;

    uint256 internal constant PRECISION = 10**12;

    uint256 internal constant LP_TOKENS = 4;
    address internal constant OWNER = address(1234567890);

    address internal constant ALICE = address(100);
    address internal constant BOB = address(101);
    address internal constant CAROL = address(102);

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                EVENTS                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    event LogOnReward(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardTime, uint256 lpSupply, uint256 accRewardsPerShare);
    event LogRewardPerSecond(uint256 rewardPerSecond);
    event LogRewardDeadline(uint256 rewardDeadline);

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                SETUP                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function setUp() public {
        syn = _deployERC20("SYN");
        rewardToken = _deployERC20("REWARD");
        lpTokens = new IERC20[](LP_TOKENS);
        for (uint256 i = 0; i < LP_TOKENS; ++i) {
            string memory name = string(abi.encodePacked("LP_", Strings.toString(i)));
            lpTokens[i] = _deployERC20(name);
        }

        miniChef = new MiniChefV2(syn);
        for (uint256 i = 0; i < LP_TOKENS; ++i) {
            miniChef.add({allocPoint: 1, _lpToken: lpTokens[i], _rewarder: IRewarder(address(0))});
        }
        vm.label(address(miniChef), "MiniChef");

        rewardDeadline = type(uint256).max;
        bonusRewarder = new BonusRewarder({
            _rewardToken: rewardToken,
            _rewardPerSecond: 0,
            _miniChefV2: address(miniChef)
        });
        bonusRewarder.transferOwnership({newOwner: OWNER, direct: true, renounce: false});
        vm.label(address(bonusRewarder), "Rewarder");

        _setupUser(ALICE);
        _setupUser(BOB);
        _setupUser(CAROL);

        vm.label(ALICE, "Alice");
        vm.label(BOB, "Bob");
        vm.label(CAROL, "Carol");
        vm.label(OWNER, "Owner");
    }

    function test_setUp() public {
        assertEq(bonusRewarder.miniChefV2(), address(miniChef), "!miniChefV2");
        assertEq(bonusRewarder.owner(), OWNER, "!owner");
        assertEq(bonusRewarder.poolLength(), 0, "!poolLength");
        assertEq(bonusRewarder.rewardDeadline(), type(uint256).max, "!rewardDeadline");
        assertEq(bonusRewarder.rewardPerSecond(), 0, "!rewardPerSecond");
        assertEq(bonusRewarder.totalAllocPoint(), 0, "!totalAllocPoint");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                  TESTS: RESTRICTED ACCESS (REVERTS)                  ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_onSynapseReward_onlyMinichef(address caller) public {
        vm.assume(caller != address(miniChef));
        vm.expectRevert("Only MCV2 can call this function");
        vm.prank(caller);
        bonusRewarder.onSynapseReward(0, address(0), address(0), 0, 0);
    }

    function test_add_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        bonusRewarder.add(0, 0);
    }

    function test_set_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        bonusRewarder.set(0, 0);
    }

    function test_reclaimTokens_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        bonusRewarder.reclaimTokens(address(0), 0, address(0));
    }

    function test_setRewardDeadline_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        bonusRewarder.setRewardDeadline(0);
    }

    function test_setRewardPerSecond_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        bonusRewarder.setRewardPerSecond(0);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TESTS: RESTRICTED ACCESS                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_add(uint8 pid, uint8 allocPoint) public {
        vm.expectEmit(true, true, true, true, address(bonusRewarder));
        emit LogPoolAddition(pid, allocPoint);
        vm.prank(OWNER);
        bonusRewarder.add(allocPoint, pid);
        (
            uint128 _accRewardsPerShare,
            uint64 _lastRewardTime,
            uint64 _allocPoint,
            uint256 _totalLpSupply
        ) = bonusRewarder.poolInfo(pid);
        assertEq(_accRewardsPerShare, uint256(0), "!accRewardsPerShare");
        assertEq(_lastRewardTime, block.timestamp, "!lastRewardTime");
        assertEq(_allocPoint, uint256(allocPoint), "!allocPoint");
        assertEq(_totalLpSupply, 0, "!totalLpSupply");

        ++poolsAdded;
        totalAllocPoint += allocPoint;
        assertEq(bonusRewarder.poolIds(poolsAdded - 1), pid, "!poolIds");
        assertEq(bonusRewarder.totalAllocPoint(), totalAllocPoint, "!totalAllocPoint");
    }

    function test_set(
        uint8 pid,
        uint8 allocPointOld,
        uint8 allocPointNew
    ) public {
        vm.assume(allocPointOld != allocPointNew);
        test_add(pid, allocPointOld);
        vm.expectEmit(true, true, true, true, address(bonusRewarder));
        emit LogSetPool(pid, allocPointNew);
        vm.prank(OWNER);
        bonusRewarder.set(pid, allocPointNew);
        (, , uint64 _allocPoint, ) = bonusRewarder.poolInfo(pid);
        assertEq(_allocPoint, uint256(allocPointNew), "!allocPoint");
        totalAllocPoint = totalAllocPoint - allocPointOld + allocPointNew;
        assertEq(bonusRewarder.totalAllocPoint(), totalAllocPoint, "!totalAllocPoint");
    }

    function test_reclaimTokens() public {
        deal(address(syn), address(bonusRewarder), 10);
        vm.prank(OWNER);
        bonusRewarder.reclaimTokens(address(syn), 1, payable(OWNER));
        assertEq(syn.balanceOf(OWNER), 1, "Token not reclaimed");
    }

    function test_reclaimTokens_ETH() public {
        deal(address(bonusRewarder), 10);
        vm.prank(OWNER);
        bonusRewarder.reclaimTokens(address(0), 1, payable(OWNER));
        assertEq(OWNER.balance, 1, "ETH not reclaimed");
    }

    function test_setRewardDeadline(uint256 _rewardDeadline) public {
        vm.expectEmit(true, true, true, true, address(bonusRewarder));
        emit LogRewardDeadline(_rewardDeadline);
        vm.prank(OWNER);
        bonusRewarder.setRewardDeadline(_rewardDeadline);
        assertEq(bonusRewarder.rewardDeadline(), _rewardDeadline, "!rewardDeadline");
        rewardDeadline = _rewardDeadline;
    }

    function test_setRewardPerSecond(uint32 _rewardPerSecond) public {
        vm.expectEmit(true, true, true, true, address(bonusRewarder));
        emit LogRewardPerSecond(_rewardPerSecond);
        vm.prank(OWNER);
        bonusRewarder.setRewardPerSecond(_rewardPerSecond);
        assertEq(bonusRewarder.rewardPerSecond(), _rewardPerSecond, "!rewardPerSecond");
        rewardPerSecond = _rewardPerSecond;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        TESTS: UPDATING POOLS                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_updatePool() public {
        test_setRewardPerSecond({_rewardPerSecond: 100});
        _setupPools({amount: 1});
        uint256 lpAmount = 42;
        // Alice makes a deposit
        _fakeInteraction({pid: 0, user: ALICE, lpTokenAmount: lpAmount});
        uint256 skipTime = 1 hours;
        skip(skipTime);
        uint256 totalRewards = rewardPerSecond * skipTime;
        uint256 accRewardsPerShare = (totalRewards * PRECISION) / lpAmount;
        vm.expectEmit(true, true, true, true, address(bonusRewarder));
        emit LogUpdatePool({
            pid: 0,
            lastRewardTime: uint64(block.timestamp),
            lpSupply: lpAmount,
            accRewardsPerShare: accRewardsPerShare
        });
        bonusRewarder.updatePool({pid: 0});
        (
            uint128 _accRewardsPerShare,
            uint64 _lastRewardTime,
            uint64 _allocPoint,
            uint256 _totalLpSupply
        ) = bonusRewarder.poolInfo(0);
        assertEq(_accRewardsPerShare, accRewardsPerShare, "!accRewardsPerShare");
        assertEq(_lastRewardTime, block.timestamp, "!lastRewardTime");
        assertEq(_allocPoint, uint256(1), "!allocPoint");
        assertEq(_totalLpSupply, lpAmount, "!totalLpSupply");
    }

    function test_massUpdatePools() public {
        test_setRewardPerSecond({_rewardPerSecond: 100});
        _setupPools({amount: LP_TOKENS});
        uint256[] memory lpAmounts = new uint256[](LP_TOKENS);
        for (uint256 i = 0; i < LP_TOKENS; ++i) {
            lpAmounts[i] = 42 + i;
            // Alice makes a deposit
            _fakeInteraction({pid: i, user: ALICE, lpTokenAmount: lpAmounts[i]});
        }
        uint256 skipTime = 1 hours;
        skip(skipTime);
        uint256 totalRewards = rewardPerSecond * skipTime;
        uint256[] memory accRewardsPerShare = new uint256[](LP_TOKENS);
        uint256[] memory pids = new uint256[](LP_TOKENS);
        for (uint256 i = 0; i < LP_TOKENS; ++i) {
            pids[i] = i;
            // Pool alloc point is (i + 1)
            uint256 totalPoolRewards = (totalRewards * (i + 1)) / totalAllocPoint;
            accRewardsPerShare[i] = (totalPoolRewards * PRECISION) / lpAmounts[i];
            vm.expectEmit(true, true, true, true, address(bonusRewarder));
            emit LogUpdatePool({
                pid: pids[i],
                lastRewardTime: uint64(block.timestamp),
                lpSupply: lpAmounts[i],
                accRewardsPerShare: accRewardsPerShare[i]
            });
        }
        bonusRewarder.massUpdatePools(pids);
        for (uint256 i = 0; i < LP_TOKENS; ++i) {
            (
                uint128 _accRewardsPerShare,
                uint64 _lastRewardTime,
                uint64 _allocPoint,
                uint256 _totalLpSupply
            ) = bonusRewarder.poolInfo(i);
            assertEq(_accRewardsPerShare, accRewardsPerShare[i], "!accRewardsPerShare");
            assertEq(_lastRewardTime, block.timestamp, "!lastRewardTime");
            assertEq(_allocPoint, i + 1, "!allocPoint");
            assertEq(_totalLpSupply, lpAmounts[i], "!totalLpSupply");
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TESTS: ON SYNAPSE REWARD                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_onSynapseReward_deposit() public {
        _setupPools({amount: 1});
        vm.expectEmit(true, true, true, true, address(bonusRewarder));
        emit LogOnReward({user: ALICE, pid: 0, amount: 0, to: ALICE});
        deposit(ALICE, 0, 0);
    }

    function test_onSynapseReward_withdraw() public {
        _setupPools({amount: 1});
        vm.expectEmit(true, true, true, true, address(bonusRewarder));
        emit LogOnReward({user: ALICE, pid: 0, amount: 0, to: ALICE});
        withdraw(ALICE, 0, 0);
    }

    function test_onSynapseReward_harvest() public {
        _setupPools({amount: 1});
        vm.expectEmit(true, true, true, true, address(bonusRewarder));
        emit LogOnReward({user: ALICE, pid: 0, amount: 0, to: ALICE});
        harvest(ALICE, 0);
    }

    function test_onSynapseReward_withdrawAndHarvest() public {
        _setupPools({amount: 1});
        vm.expectEmit(true, true, true, true, address(bonusRewarder));
        emit LogOnReward({user: ALICE, pid: 0, amount: 0, to: ALICE});
        withdrawAndHarvest(ALICE, 0, 0);
    }

    function test_onSynapseReward_emergencyWithdraw() public {
        _setupPools({amount: 1});
        vm.expectEmit(true, true, true, true, address(bonusRewarder));
        emit LogOnReward({user: ALICE, pid: 0, amount: 0, to: ALICE});
        emergencyWithdraw(ALICE, 0);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           END TO END TESTS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_singlePool() public {
        deal(address(rewardToken), address(bonusRewarder), 10**18);
        uint256 expectedA;
        uint256 expectedB;
        uint256 expectedC;
        (uint256 totalA, uint256 totalB, uint256 totalC) = (0, 0, 0);
        uint256 phaseTime = 1000;
        // Alice and Bob deposit before Rewarder is set up
        deposit({user: ALICE, pid: 0, amount: 10});
        deposit({user: BOB, pid: 0, amount: 10});
        test_setRewardPerSecond({_rewardPerSecond: 100});
        uint256 phaseTotalRewards = phaseTime * rewardPerSecond;
        _setupPools({amount: 1});
        skip(phaseTime);
        assertEq(bonusRewarder.pendingToken(0, ALICE), 0, "Alice didn't opt in: phase 0");
        assertEq(bonusRewarder.pendingToken(0, BOB), 0, "Bob didn't opt in: phase 0");
        assertEq(bonusRewarder.pendingToken(0, CAROL), 0, "Carol didn't opt in: phase 0");
        // 1000 seconds later, Carol is the only user who opted in (PHASE 1)
        deposit({user: CAROL, pid: 0, amount: 1});
        assertEq(bonusRewarder.pendingToken(0, CAROL), 0, "Carol just opted in: phase 1");
        skip(phaseTime);
        expectedC = phaseTotalRewards;
        assertEq(bonusRewarder.pendingToken(0, ALICE), 0, "Alice didn't opt in: phase 1");
        assertEq(bonusRewarder.pendingToken(0, BOB), 0, "Bob didn't opt in: phase 1");
        assertEq(bonusRewarder.pendingToken(0, CAROL), expectedC, "Carol mismatch: phase 1");
        // Alice withdraws 1 token, Bob does a harvest: they both opted in by doing so
        // New ratio is Alice : 9, Bob: 10, Carol : 1 (PHASE 2)
        withdraw({user: ALICE, pid: 0, amount: 1});
        harvest({user: BOB, pid: 0});
        skip(phaseTime);
        expectedA = (phaseTotalRewards * 9) / 20;
        expectedB = (phaseTotalRewards * 10) / 20;
        // Carol didn't interact with the pool, so pending rewards roll over
        expectedC = expectedC + (phaseTotalRewards * 1) / 20;
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA, "Alice mismatch: phase 2");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: phase 2");
        assertEq(bonusRewarder.pendingToken(0, CAROL), expectedC, "Carol mismatch: phase 2");
        // Alice withdraws everything, Carol deposits 5 more
        // New ratio is Alice : 0, Bob: 10, Carol : 6 (PHASE 3)
        withdraw({user: ALICE, pid: 0, amount: 9});
        totalA += expectedA;
        deposit({user: CAROL, pid: 0, amount: 5});
        totalC += expectedC;
        skip(phaseTime);
        expectedA = 0;
        // Bob didn't interact with the pool, so pending rewards roll over
        expectedB = expectedB + (phaseTotalRewards * 10) / 16;
        expectedC = (phaseTotalRewards * 6) / 16;
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA, "Alice mismatch: phase 3");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: phase 3");
        assertEq(bonusRewarder.pendingToken(0, CAROL), expectedC, "Carol mismatch: phase 3");
        // Harvest remaining rewards and check total claimed
        harvest({user: ALICE, pid: 0});
        harvest({user: BOB, pid: 0});
        harvest({user: CAROL, pid: 0});
        assertEq(rewardToken.balanceOf(ALICE), totalA + expectedA, "Alice mismatch: total claimed rewards");
        assertEq(rewardToken.balanceOf(BOB), totalB + expectedB, "Alice mismatch: total claimed rewards");
        assertEq(rewardToken.balanceOf(CAROL), totalC + expectedC, "Alice mismatch: total claimed rewards");
    }

    function test_multiplePools() public {
        deal(address(rewardToken), address(bonusRewarder), 10**18);
        uint256 expectedA0 = 0;
        uint256 expectedA1 = 0;
        uint256 expectedB0 = 0;
        uint256 expectedB1 = 0;
        (uint256 totalA, uint256 totalB) = (0, 0);
        uint256 phaseTime = 1000;
        // Alice and Bob deposit before Rewarder is set up
        deposit({user: ALICE, pid: 0, amount: 10});
        deposit({user: ALICE, pid: 1, amount: 10});
        deposit({user: BOB, pid: 0, amount: 10});
        deposit({user: BOB, pid: 1, amount: 10});
        test_setRewardPerSecond({_rewardPerSecond: 100});
        _setupPools({amount: 2});
        // Pool alloc points: [1, 2]
        uint256 expectedP0 = (phaseTime * rewardPerSecond * 1) / 3;
        uint256 expectedP1 = (phaseTime * rewardPerSecond * 2) / 3;
        // Alice opts in for the pool#0 (PHASE 0)
        harvest({user: ALICE, pid: 0});
        skip(phaseTime);
        // Alice should receive all rewards for pool #0
        expectedA0 = expectedP0;
        // No one opted in for pool #1 rewards :(
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA0, "Alice mismatch: phase 0, pool 0");
        assertEq(bonusRewarder.pendingToken(1, ALICE), expectedA1, "Alice mismatch: phase 0, pool 1");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB0, "Bob mismatch: phase 0, pool 0");
        assertEq(bonusRewarder.pendingToken(1, BOB), expectedB1, "Bob mismatch: phase 0, pool 1");
        // Bob opts in for the pool#1 (PHASE 1)
        harvest({user: BOB, pid: 1});
        skip(phaseTime);
        // Alice should receive all rewards for pool#0
        // Alice didn't interact, so pending rewards roll over
        expectedA0 = expectedA0 + expectedP0;
        // Bob should receive all rewards for pool#1
        expectedB1 = expectedP1;
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA0, "Alice mismatch: phase 1, pool 0");
        assertEq(bonusRewarder.pendingToken(1, ALICE), expectedA1, "Alice mismatch: phase 1, pool 1");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB0, "Bob mismatch: phase 1, pool 0");
        assertEq(bonusRewarder.pendingToken(1, BOB), expectedB1, "Bob mismatch: phase 1, pool 1");
        // Alice withdraws 5 from pool#0 and opts in for pool#1 (PHASE 2)
        withdraw({user: ALICE, pid: 0, amount: 5});
        totalA += expectedA0;
        harvest({user: ALICE, pid: 1});
        // Bob opts in for pool#0 and withdraws 8 from pool#1
        harvest({user: BOB, pid: 0});
        withdraw({user: BOB, pid: 1, amount: 8});
        totalB += expectedB1;
        skip(phaseTime);
        // Pool#0 balances: Alice = 5, Bob = 10
        expectedA0 = (expectedP0 * 5) / 15;
        expectedB0 = (expectedP0 * 10) / 15;
        // Pool#1 balances: Alice = 10, Bob = 2
        expectedA1 = (expectedP1 * 10) / 12;
        expectedB1 = (expectedP1 * 2) / 12;
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA0, "Alice mismatch: phase 2, pool 0");
        assertEq(bonusRewarder.pendingToken(1, ALICE), expectedA1, "Alice mismatch: phase 2, pool 1");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB0, "Bob mismatch: phase 2, pool 0");
        assertEq(bonusRewarder.pendingToken(1, BOB), expectedB1, "Bob mismatch: phase 2, pool 1");
        // Harvest remaining rewards and check total claimed
        harvest({user: ALICE, pid: 0});
        harvest({user: ALICE, pid: 1});
        totalA += expectedA0 + expectedA1;
        harvest({user: BOB, pid: 0});
        harvest({user: BOB, pid: 1});
        totalB += expectedB0 + expectedB1;
        assertEq(rewardToken.balanceOf(ALICE), totalA, "Alice mismatch: total claimed rewards");
        assertEq(rewardToken.balanceOf(BOB), totalB, "Alice mismatch: total claimed rewards");
    }

    function test_singlePool_rewardDeadline() public {
        deal(address(rewardToken), address(bonusRewarder), 10**18);
        uint256 rewardPeriod = 1000;
        test_setRewardPerSecond({_rewardPerSecond: 100});
        _setupPools({amount: 1});
        // Alice and Bob deposit 1 token each
        deposit({user: ALICE, pid: 0, amount: 1});
        deposit({user: BOB, pid: 0, amount: 1});
        test_setRewardDeadline(block.timestamp + rewardPeriod);
        skip(2 * rewardPeriod);
        // 2 "reward periods" have passed, but rewards are awarded only before the deadline
        uint256 expectedA = (rewardPerSecond * rewardPeriod) / 2;
        uint256 expectedB = (rewardPerSecond * rewardPeriod) / 2;
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA, "Alice mismatch: post deadline");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: post deadline");
        // Alice harvests the rewards
        harvest({user: ALICE, pid: 0});
        skip(rewardPeriod);
        // A total of 2 "reward periods" have passed since the reward deadline
        // No new pending rewards
        assertEq(bonusRewarder.pendingToken(0, ALICE), 0, "Alice mismatch: post deadline");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: post deadline");
        assertEq(rewardToken.balanceOf(ALICE), expectedA, "Alice mismatch: total claimed rewards");
        assertEq(rewardToken.balanceOf(BOB), 0, "Bob mismatch: total claimed rewards");
    }

    function test_extendDeadline_applyRewardsSinceDeadline() public {
        uint256 rewardPeriod = 1000;
        test_singlePool_rewardDeadline();
        // Rewards from last test
        uint256 totalA = (rewardPerSecond * rewardPeriod) / 2;
        uint256 totalB = 0;
        // Extend the deadline: workflow 1
        {
            // extended deadline by one more period
            test_setRewardDeadline(block.timestamp + rewardPeriod);
        }
        // (2 * rewardPeriod) passed since last deadline: rewards are applied retroactively
        uint256 expectedA = (rewardPerSecond * (2 * rewardPeriod)) / 2;
        // Bob hasn't claimed tokens in the first test
        uint256 expectedB = totalA + (rewardPerSecond * (2 * rewardPeriod)) / 2;
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA, "Alice mismatch: deadline extended");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: deadline extended");
        // Bob harvests rewards
        harvest({user: BOB, pid: 0});
        totalB += expectedB;
        // Skip 2 more periods: but rewards were active only during the first one
        skip(2 * rewardPeriod);
        expectedA += (rewardPerSecond * rewardPeriod) / 2;
        expectedB = (rewardPerSecond * rewardPeriod) / 2;
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA, "Alice mismatch: post new deadline");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: post new deadline");
        // Alice harvests rewards
        harvest({user: ALICE, pid: 0});
        totalA += expectedA;
        assertEq(rewardToken.balanceOf(ALICE), totalA, "Alice mismatch: total claimed rewards");
        assertEq(rewardToken.balanceOf(BOB), totalB, "Bob mismatch: total claimed rewards");
    }

    function test_extendDeadline_denyRewardsSinceDeadline() public {
        uint256 rewardPeriod = 1000;
        test_singlePool_rewardDeadline();
        // Rewards from last test
        uint256 totalA = (rewardPerSecond * rewardPeriod) / 2;
        uint256 totalB = 0;
        uint256 expectedA = 0;
        uint256 expectedB = (rewardPerSecond * rewardPeriod) / 2;
        // Extend the deadline: workflow 2
        {
            vm.startPrank(OWNER);
            bonusRewarder.updatePool(0);
            bonusRewarder.setRewardPerSecond(0);
            // extended deadline by one more period
            bonusRewarder.setRewardDeadline(block.timestamp + rewardPeriod);
            bonusRewarder.updatePool(0);
            bonusRewarder.setRewardPerSecond(rewardPerSecond);
            vm.stopPrank();
        }
        // pending rewards should not change
        assertEq(bonusRewarder.pendingToken(0, ALICE), 0, "Alice mismatch: deadline extended");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: deadline extended");
        // Bob harvests rewards
        harvest({user: BOB, pid: 0});
        totalB += expectedB;
        // Skip 2 more periods: but rewards were active only during the first one
        skip(2 * rewardPeriod);
        expectedA += (rewardPerSecond * rewardPeriod) / 2;
        expectedB = (rewardPerSecond * rewardPeriod) / 2;
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA, "Alice mismatch: post new deadline");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: post new deadline");
        // Alice harvests rewards
        harvest({user: ALICE, pid: 0});
        totalA += expectedA;
        assertEq(rewardToken.balanceOf(ALICE), totalA, "Alice mismatch: total claimed rewards");
        assertEq(rewardToken.balanceOf(BOB), totalB, "Bob mismatch: total claimed rewards");
    }

    function test_claimEndedRewards() public {
        deal(address(rewardToken), address(bonusRewarder), 10**18);
        uint256 phaseTime = 1000;
        test_setRewardPerSecond({_rewardPerSecond: 100});
        _setupPools({amount: 1});
        deposit({user: ALICE, pid: 0, amount: 1});
        skip(phaseTime);
        // Disconnect rewarder from the MinChef
        miniChef.set({_pid: 0, _allocPoint: 1, _rewarder: IRewarder(address(0)), overwrite: true});
        skip(phaseTime);
        uint256 expectedA = 2 * rewardPerSecond * phaseTime;
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA, "Alice mismatch: after disconnect");
        harvest({user: ALICE, pid: 0});
        assertEq(rewardToken.balanceOf(ALICE), 0, "Alice mismatch: claimed when disconnected");
        vm.prank(ALICE);
        bonusRewarder.claimEndedRewards({pid: 0, to: BOB});
        assertEq(rewardToken.balanceOf(ALICE), 0, "Alice mismatch: tokens sent to wrong address");
        assertEq(rewardToken.balanceOf(BOB), expectedA, "Bob mismatch: tokens sent to wrong address");
        skip(phaseTime);
        assertEq(bonusRewarder.pendingToken(0, ALICE), 0, "Alice mismatch: post claim");
        harvest({user: ALICE, pid: 0});
        assertEq(rewardToken.balanceOf(ALICE), 0, "Alice mismatch: total claimed");
    }

    function test_claimEndedRewards_revert_whenConnected() public {
        deal(address(rewardToken), address(bonusRewarder), 10**18);
        uint256 phaseTime = 1000;
        test_setRewardPerSecond({_rewardPerSecond: 100});
        _setupPools({amount: 1});
        deposit({user: ALICE, pid: 0, amount: 1});
        skip(phaseTime);
        vm.expectRevert("Rewarder is connected");
        vm.prank(ALICE);
        bonusRewarder.claimEndedRewards({pid: 0, to: ALICE});
    }

    function test_rewardsRunOut() public {
        uint256 phaseTime = 1000;
        uint256 initialBalance = 10000;
        (uint256 totalA, uint256 totalB) = (0, 0);
        deal(address(rewardToken), address(bonusRewarder), initialBalance);
        test_setRewardPerSecond({_rewardPerSecond: 100});
        _setupPools({amount: 1});
        deposit({user: ALICE, pid: 0, amount: 1});
        deposit({user: BOB, pid: 0, amount: 1});
        skip(phaseTime);
        uint256 expectedA = (phaseTime * rewardPerSecond) / 2;
        uint256 expectedB = (phaseTime * rewardPerSecond) / 2;
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA, "Alice mismatch: phase passed");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: phase passed");
        // Bob withdraws, Alice harvests
        withdraw({user: BOB, pid: 0, amount: 1});
        // Bob interacts first and should receive all bonus tokens available
        expectedB -= initialBalance;
        totalB += initialBalance;
        // No tokens to give to Alice
        harvest({user: ALICE, pid: 0});
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA, "Alice mismatch: after run out");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: after run out");
        assertEq(rewardToken.balanceOf(ALICE), 0, "Alice mismatch: claimed after run out");
        assertEq(rewardToken.balanceOf(BOB), initialBalance, "Bob mismatch: claimed after run out");
        assertEq(rewardToken.balanceOf(address(bonusRewarder)), 0, "Rewarder mismatch: claimed after run out");
        skip(phaseTime);
        // Alice is the only one in the pool, Bob still has unpaid rewards
        expectedA += (phaseTime * rewardPerSecond);
        assertEq(bonusRewarder.pendingToken(0, ALICE), expectedA, "Alice mismatch: phase after run out");
        assertEq(bonusRewarder.pendingToken(0, BOB), expectedB, "Bob mismatch: phase after run out");
        // Refill rewards
        deal(address(rewardToken), address(bonusRewarder), 10**18);
        // Both actors should get their missed rewards
        harvest({user: ALICE, pid: 0});
        harvest({user: BOB, pid: 0});
        totalA += expectedA;
        totalB += expectedB;
        assertEq(bonusRewarder.pendingToken(0, ALICE), 0, "Alice mismatch: claim after refill");
        assertEq(bonusRewarder.pendingToken(0, BOB), 0, "Bob mismatch: claim after refill");
        assertEq(rewardToken.balanceOf(ALICE), totalA, "Alice mismatch: total claimed");
        assertEq(rewardToken.balanceOf(BOB), totalB, "Bob mismatch: total claimed");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          USER INTERACTIONS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function deposit(
        address user,
        uint256 pid,
        uint256 amount
    ) public {
        vm.prank(user);
        miniChef.deposit(pid, amount, user);
    }

    function withdraw(
        address user,
        uint256 pid,
        uint256 amount
    ) public {
        vm.prank(user);
        miniChef.withdraw(pid, amount, user);
    }

    function harvest(address user, uint256 pid) public {
        vm.prank(user);
        miniChef.harvest(pid, user);
    }

    function withdrawAndHarvest(
        address user,
        uint256 pid,
        uint256 amount
    ) public {
        vm.prank(user);
        miniChef.withdrawAndHarvest(pid, amount, user);
    }

    function emergencyWithdraw(address user, uint256 pid) public {
        vm.prank(user);
        miniChef.emergencyWithdraw(pid, user);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _deployERC20(string memory name) internal returns (IERC20 token) {
        token = IERC20(address(new ERC20(name, name)));
        vm.label(address(token), name);
    }

    function _fakeInteraction(
        uint256 pid,
        address user,
        uint256 lpTokenAmount
    ) internal {
        vm.prank(address(miniChef));
        bonusRewarder.onSynapseReward(pid, user, user, 0, lpTokenAmount);
    }

    function _setupPools(uint256 amount) internal {
        for (uint8 i = 0; i < amount; ++i) {
            test_add({pid: i, allocPoint: i + 1});
            miniChef.set({_pid: i, _allocPoint: 0, _rewarder: bonusRewarder, overwrite: true});
        }
    }

    function _setupUser(address user) internal {
        for (uint256 i = 0; i < LP_TOKENS; ++i) {
            vm.prank(user);
            lpTokens[i].approve(address(miniChef), type(uint256).max);
            deal(address(lpTokens[i]), user, 1000);
        }
    }
}
