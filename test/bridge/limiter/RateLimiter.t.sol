// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {RateLimiter} from "src-bridge/RateLimiter.sol";
import {Utilities} from "../utilities/Utilities.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract RateLimiterFoundryTest is Test {
    RateLimiter internal immutable rateLimiter;
    Utilities internal immutable utils;
    IERC20 internal immutable token;

    uint256 internal constant TIMESTAMP = 1200000;
    uint32 internal constant RESET_BASE_MIN = uint32(TIMESTAMP / 60);

    constructor() {
        rateLimiter = new RateLimiter();
        utils = new Utilities();
        rateLimiter.initialize();
        token = IERC20(deployCode("artifacts/GenericERC20.sol/GenericERC20.json", abi.encode("USDC", "USDC", 6)));
    }

    function setUp() public {
        rateLimiter.grantRole(rateLimiter.LIMITER_ROLE(), address(this));
        rateLimiter.grantRole(rateLimiter.BRIDGE_ROLE(), address(this));

        vm.warp(TIMESTAMP);
    }

    function testSetAllowance(uint96 amount) public {
        vm.assume(amount > 0);

        _setAllowance(amount);
        _checkAllowance(amount, 0, 60, RESET_BASE_MIN);

        // Try overwriting the allowance settings
        rateLimiter.setAllowance(address(token), amount / 2, 120, RESET_BASE_MIN - 60);
        _checkAllowance(amount / 2, 0, 120, RESET_BASE_MIN - 60);
    }

    struct TestToken {
        address tokenAddress;
        uint96 tokenAmount;
        uint16 resetTimeMin;
        uint32 resetBaseMin;
    }

    function testBulkSetAllowance(uint96 amount, uint8 token_count) public {
        vm.assume(amount > 0);
        vm.assume(token_count > 0);

        // mock out some tokens
        address[] memory tokens = new address[](token_count);
        uint96[] memory allowanceAmounts = new uint96[](token_count);
        uint16[] memory resetTimeMins = new uint16[](token_count);
        uint32[] memory resetBaseMins = new uint32[](token_count);

        for (uint256 i = 0; i < token_count; i++) {
            TestToken memory newToken = TestToken({
                tokenAddress: address(4),
                tokenAmount: uint96(token_count) * 10,
                resetTimeMin: uint16(token_count) * 2,
                resetBaseMin: uint32(token_count) * 3
            });

            tokens[i] = (newToken.tokenAddress);
            allowanceAmounts[i] = (newToken.tokenAmount);
            resetTimeMins[i] = (newToken.resetTimeMin);
            resetBaseMins[i] = (newToken.resetBaseMin);
        }

        // bulk set allowances
        rateLimiter.setAllowances(tokens, allowanceAmounts, resetTimeMins, resetBaseMins);

        for (uint256 i = 0; i < token_count; i++) {
            uint256[4] memory res = rateLimiter.getTokenAllowance(tokens[i]);
            assertEq(res[0], allowanceAmounts[i]);
            assertEq(res[1], 0);
            assertEq(res[2], resetTimeMins[i]);
        }
    }

    function testUpdateAllowance(uint96 amount) public {
        vm.assume(amount > 10);

        _setAllowance(type(uint96).max);

        uint96[] memory amounts = new uint96[](4);
        amounts[0] = amount / 10;
        amounts[1] = amounts[0] * 2;
        amounts[2] = amounts[0] * 3;
        amounts[3] = amount - (amounts[0] + amounts[1] + amounts[2]);

        uint96 spent = 0;

        for (uint256 i = 0; i < amounts.length; ++i) {
            assertTrue(rateLimiter.checkAndUpdateAllowance(address(token), amounts[i]), "Failed to spend below max");
            spent += amounts[i];
            _checkAllowance(type(uint96).max, spent, 60, RESET_BASE_MIN);
        }
    }

    function testSpendFull(uint96 amount) public {
        vm.assume(amount > 0);

        _setAllowance(amount);

        assertTrue(rateLimiter.checkAndUpdateAllowance(address(token), amount), "Failed to spend exactly max");
        _checkAllowance(amount, amount, 60, RESET_BASE_MIN);
    }

    function testOverSpend(uint96 amount) public {
        vm.assume(amount > 1);
        --amount;

        _setAllowance(amount);

        assertTrue(!rateLimiter.checkAndUpdateAllowance(address(token), amount + 1), "Managed to spend over max");

        _checkAllowance(amount, 0, 60, RESET_BASE_MIN);
    }

    function testResetAllowance(uint96 amount) public {
        testUpdateAllowance(amount);
        rateLimiter.resetAllowance(address(token));

        // Check that allowance was reset: spend = 0
        _checkAllowance(type(uint96).max, 0, 60, RESET_BASE_MIN);
    }

    function testResetAllowanceOverTime(uint96 amount) public {
        testUpdateAllowance(amount);
        // Skip 60 minutes
        skip(60 * 60);

        // Check that allowance was reset: spend = 0, lastTimeReset += 60
        _checkAllowance(type(uint96).max, 0, 60, RESET_BASE_MIN + 60);
    }

    function testGetTransactionAt(uint96 tx_count) public {
        vm.assume(tx_count > 1);
        vm.assume(tx_count < 10);

        for (uint256 i = 0; i < tx_count; ++i) {
            bytes32 kappa = utils.getNextKappa();
            bytes memory expectedPayload = abi.encodePacked(kappa, i);
            rateLimiter.addToRetryQueue(kappa, expectedPayload);

            (bytes memory payload, uint32 storedAtMin) = rateLimiter.getTransactionByKappa(kappa);
            assertEq(payload, expectedPayload);

            // without removing anything these txes should be in order
            (bytes32 atKappa, bytes memory atPayload, uint32 atStoredAtMin) = rateLimiter.getTransactionAt(i);
            assertEq(atPayload, expectedPayload);
            assertEq(atKappa, kappa);
            assertEq(atStoredAtMin, storedAtMin);
        }
    }

    function _checkAllowance(
        uint96 amount,
        uint96 spent,
        uint32 resetTimeMin,
        uint32 lastResetMin
    ) internal {
        uint256[4] memory allowance = rateLimiter.getTokenAllowance(address(token));
        assertEq(allowance[0], amount, "amount differs");
        assertEq(allowance[1], spent, "spent differs");
        assertEq(allowance[2], resetTimeMin, "resetTimeMin differs");
        assertEq(allowance[3], lastResetMin, "lastResetMin differs");
    }

    function _setAllowance(uint96 amount) internal {
        rateLimiter.setAllowance(address(token), amount, 60, RESET_BASE_MIN);
    }
}
