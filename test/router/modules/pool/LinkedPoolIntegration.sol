// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPool} from "../../../../contracts/router/LinkedPool.sol";

import {console, IntegrationUtils} from "../../../utils/IntegrationUtils.sol";
import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";

// solhint-disable no-console
abstract contract LinkedPoolIntegrationTest is IntegrationUtils {
    using SafeERC20 for IERC20;

    address[] public expectedTokens;
    mapping(address => string) public tokenNames;

    LinkedPool public linkedPool;

    address public user;

    constructor(
        string memory chainName_,
        string memory contractName_,
        uint256 forkBlockNumber
    ) IntegrationUtils(chainName_, contractName_, forkBlockNumber) {}

    function afterBlockchainForked() public virtual override {
        deployModule();
        addExpectedTokens();
        deployLinkedPool();
        addPools();
        user = makeAddr("User");
    }

    function deployModule() public virtual;

    function addExpectedTokens() public virtual;

    function addExpectedToken(address token, string memory tokenName) public virtual {
        expectedTokens.push(token);
        tokenNames[token] = tokenName;
        vm.label(token, tokenName);
    }

    function deployLinkedPool() public virtual {
        require(expectedTokens.length > 0, "No tokens provided");
        linkedPool = new LinkedPool(expectedTokens[0], address(this));
    }

    function addPools() public virtual;

    function addPool(
        string memory poolName,
        uint256 nodeIndex,
        address pool
    ) public {
        addPool(poolName, nodeIndex, pool, address(0));
    }

    function addPool(
        string memory poolName,
        uint256 nodeIndex,
        address pool,
        address poolModule
    ) public virtual {
        linkedPool.addPool(nodeIndex, pool, poolModule);
        vm.label(pool, poolName);
    }

    // ═══════════════════════════════════════════════════ TESTS ═══════════════════════════════════════════════════════

    function testSetup() public {
        uint256 amount = linkedPool.tokenNodesAmount();
        assertEq(amount, expectedTokens.length);
        for (uint8 i = 0; i < amount; i++) {
            console.log("%s: %s [%s]", i, expectedTokens[i], tokenNames[expectedTokens[i]]);
            assertEq(linkedPool.getToken(i), expectedTokens[i]);
        }
    }

    function testSwaps() public {
        uint256 amount = linkedPool.tokenNodesAmount();
        for (uint8 indexFrom = 0; indexFrom < amount; ++indexFrom) {
            for (uint8 indexTo = 0; indexTo < amount; ++indexTo) {
                if (indexFrom == indexTo) {
                    continue;
                }
                checkSwap(indexFrom, indexTo);
            }
        }
    }

    function checkSwap(uint8 indexFrom, uint8 indexTo) public virtual {
        address tokenFrom = linkedPool.getToken(indexFrom);
        address tokenTo = linkedPool.getToken(indexTo);
        uint256 amount = getTestAmount(tokenFrom);
        uint256 expectedAmountOut = linkedPool.calculateSwap({
            nodeIndexFrom: indexFrom,
            nodeIndexTo: indexTo,
            dx: amount
        });
        console.log("Swapping: %s -> %s", tokenNames[tokenFrom], tokenNames[tokenTo]);
        console.log("   Expecting: %s -> %s", amount, expectedAmountOut);
        // Break if the expected amount is 0
        require(expectedAmountOut > 0, "No expected amount out");
        mintToken(tokenFrom, amount);
        approveSpending(tokenFrom, address(linkedPool), amount);
        uint256 balanceFromBefore = IERC20(tokenFrom).balanceOf(user);
        uint256 balanceToBefore = IERC20(tokenTo).balanceOf(user);
        vm.prank(user);
        uint256 amountOut = linkedPool.swap({
            nodeIndexFrom: indexFrom,
            nodeIndexTo: indexTo,
            dx: amount,
            minDy: 0,
            deadline: block.timestamp
        });
        assertEq(amountOut, expectedAmountOut, "Failed to get exact quote");
        assertEq(
            IERC20(tokenFrom).balanceOf(user),
            tokenFrom != tokenTo ? balanceFromBefore - amount : balanceFromBefore - amount + amountOut,
            "Failed to spend tokenFrom"
        );
        assertEq(
            IERC20(tokenTo).balanceOf(user),
            tokenFrom != tokenTo ? balanceToBefore + amountOut : balanceToBefore + amountOut - amount,
            "Failed to receive tokenTo"
        );
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function getTestAmount(address token) public view virtual returns (uint256) {
        // 0.01 units in the token decimals
        return 10**uint256(IERC20Metadata(token).decimals() - 2);
    }

    // Could be overridden if `deal` does not work with the token
    function mintToken(address token, uint256 amount) public virtual {
        deal(token, user, amount);
    }

    function approveSpending(
        address token,
        address spender,
        uint256 amount
    ) public {
        vm.startPrank(user);
        IERC20(token).safeApprove(spender, amount);
        vm.stopPrank();
    }
}
