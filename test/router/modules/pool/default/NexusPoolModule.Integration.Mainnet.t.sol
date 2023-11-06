// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../../../utils/IntegrationUtils.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken, NexusPoolModule} from "../../../../../contracts/router/modules/pool/default/NexusPoolModule.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract NexusPoolModuleEthTestFork is IntegrationUtils {
    using SafeERC20 for IERC20;

    LinkedPool public linkedPool;
    NexusPoolModule public nexusPoolModule;

    // 2023-11-03
    uint256 public constant ETH_BLOCK_NUMBER = 18490000;

    // DAI/USDC/USDT Nexus DefaultPool on Ethereum
    address public constant NEXUS_POOL = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;
    address public constant NUSD = 0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F;
    address public constant DEFAULT_POOL_CALC = 0x0000000000F54b784E70E1Cf1F99FB53b08D6FEA;

    // Native USDC on Ethereum
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // Native USDT on Ethereum
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    // Native DAI on Ethereum
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public user;

    constructor() IntegrationUtils("mainnet", "NexusPoolModule", ETH_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        nexusPoolModule = new NexusPoolModule({defaultPoolCalc_: DEFAULT_POOL_CALC, nexusPool_: NEXUS_POOL});
        linkedPool = new LinkedPool(USDC, address(this));
        user = makeAddr("User");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testImmutables() public {
        assertEq(address(nexusPoolModule.defaultPoolCalc()), DEFAULT_POOL_CALC);
        assertEq(nexusPoolModule.nexusPool(), NEXUS_POOL);
        assertEq(nexusPoolModule.nexusPoolNumTokens(), 3);
        assertEq(nexusPoolModule.nexusPoolLpToken(), NUSD);
    }

    function testGetPoolTokens() public {
        address[] memory tokens = nexusPoolModule.getPoolTokens(NEXUS_POOL);
        assertEq(tokens.length, 4);
        assertEq(tokens[0], DAI);
        assertEq(tokens[1], USDC);
        assertEq(tokens[2], USDT);
        assertEq(tokens[3], NUSD);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: NEXUS_POOL, poolModule: address(nexusPoolModule)});
    }

    function testAddPool() public {
        addPool();
        assertEq(linkedPool.getToken(0), USDC);
        assertEq(linkedPool.getToken(1), DAI);
        assertEq(linkedPool.getToken(2), USDT);
        assertEq(linkedPool.getToken(3), NUSD);
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

    function testSwapFromNusdToUsdc() public {
        addPool();
        uint256 amount = 100 * 10**18;
        prepareUser(NUSD, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 3, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 3, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(NUSD).balanceOf(user), 0);
        assertEq(IERC20(USDC).balanceOf(user), amountOut);
    }

    function testSwapFromUsdcToDai() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC).balanceOf(user), 0);
        assertEq(IERC20(DAI).balanceOf(user), amountOut);
    }

    function testSwapFromDaiToNusd() public {
        addPool();
        uint256 amount = 100 * 10**18;
        prepareUser(DAI, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 3, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 3, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(DAI).balanceOf(user), 0);
        assertEq(IERC20(NUSD).balanceOf(user), amountOut);
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount, false);
        vm.startPrank(user);
        IERC20(token).safeApprove(address(linkedPool), amount);
        vm.stopPrank();
    }
}
