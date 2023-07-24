// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken, DssPsmModule} from "../../../../../contracts/router/modules/pool/dss/DssPsmModule.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract DssPsmModuleEthTestFork is Test {
    LinkedPool public linkedPool;
    DssPsmModule public dssPsmModule;

    // 2023-07-24
    uint256 public constant ETH_BLOCK_NUMBER = 17763746;

    // DSS PSM on Ethereum mainnet
    address public constant DSS_PSM = 0x89B78CfA322F6C5dE0aBcEecab66Aee45393cC5A;

    // Native USDC on Ethereum mainnet
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Native DAI on Ethereum mainne18
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public user;

    function setUp() public {
        string memory ethRPC = vm.envString("ETHEREUM_API");
        vm.createSelectFork(ethRPC, ETH_BLOCK_NUMBER);

        dssPsmModule = new DssPsmModule();
        linkedPool = new LinkedPool(DAI);
        user = makeAddr("User");

        vm.label(DSS_PSM, "DssPsm");
        vm.label(USDC, "USDC");
        vm.label(DAI, "DAI");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = dssPsmModule.getPoolTokens(DSS_PSM);
        assertEq(tokens.length, 2);
        assertEq(tokens[0], DAI);
        assertEq(tokens[1], USDC);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: DSS_PSM, poolModule: address(dssPsmModule)});
    }

    function testAddPool() public {
        addPool();
        assertEq(linkedPool.getToken(0), DAI);
        assertEq(linkedPool.getToken(1), USDC);
    }

    // ════════════════════════════════════════════════ TESTS: SWAP ════════════════════════════════════════════════════

    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 amount
    ) public returns (uint256 amountOut) {
        vm.prank(user);
        amountOut = linkedPool.swap({
            nodeIndexFrom: tokenIndexFrom,
            nodeIndexTo: tokenIndexTo,
            dx: amount,
            minDy: 0,
            deadline: type(uint256).max
        });
    }

    function testSwapFromDAItoUSDC() public {
        addPool();
        uint256 amount = 100 * 10**18;
        prepareUser(DAI, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(DAI).balanceOf(user), 0);
        assertEq(IERC20(USDC).balanceOf(user), amountOut);
    }

    function testSwapFromUSDCtoDAI() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC).balanceOf(user), 0);
        assertEq(IERC20(DAI).balanceOf(user), amountOut);
    }

    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        dssPsmModule.poolSwap({
            pool: DSS_PSM,
            tokenFrom: IndexedToken({index: 0, token: DAI}),
            tokenTo: IndexedToken({index: 1, token: USDC}),
            amountIn: 100 * 10**18
        });
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
