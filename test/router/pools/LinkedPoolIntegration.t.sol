// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPool} from "../../../contracts/router/LinkedPool.sol";

import {console, Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";

// solhint-disable no-console
abstract contract LinkedPoolIntegrationTest is Test {
    string private _envRPC;
    uint256 private _forkBlockNumber;

    address[] public expectedTokens;
    mapping(address => string) public tokenNames;

    LinkedPool public linkedPool;

    address public user;

    constructor(string memory envRPC, uint256 forkBlockNumber) {
        _envRPC = envRPC;
        _forkBlockNumber = forkBlockNumber;
    }

    function setUp() public virtual {
        forkBlockchain();
        afterBlockchainForked();
        addExpectedTokens();
        deployLinkedPool();
        addPools();
        user = makeAddr("User");
    }

    function forkBlockchain() public virtual {
        string memory rpcURL = vm.envString(_envRPC);
        if (_forkBlockNumber > 0) {
            vm.createSelectFork(rpcURL, _forkBlockNumber);
        } else {
            vm.createSelectFork(rpcURL);
        }
    }

    function afterBlockchainForked() public virtual {}

    function addExpectedTokens() public virtual;

    function addExpectedToken(address token, string memory tokenName) public virtual {
        expectedTokens.push(token);
        tokenNames[token] = tokenName;
        vm.label(token, tokenName);
    }

    function deployLinkedPool() public virtual {
        require(expectedTokens.length > 0, "No tokens provided");
        linkedPool = new LinkedPool(expectedTokens[0]);
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
        assertEq(IERC20(tokenFrom).balanceOf(user), balanceFromBefore - amount, "Failed to spend tokenFrom");
        assertEq(IERC20(tokenTo).balanceOf(user), balanceToBefore + amountOut, "Failed to receive tokenTo");
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function getTestAmount(address token) public view virtual returns (uint256) {
        // 100 units in the token decimals
        return 100 * 10**IERC20Metadata(token).decimals();
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
        vm.prank(user);
        IERC20(token).approve(spender, amount);
    }
}
