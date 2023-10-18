// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../../../utils/IntegrationUtils.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken} from "../../../../../contracts/router/modules/pool/gmx/GMXV1Module.sol";
import {GMXV1StableAvalancheModule} from "../../../../../contracts/router/modules/pool/gmx/GMXV1StableAvalancheModule.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract GMXV1ModuleAvaxTestFork is IntegrationUtils {
    LinkedPool public linkedPool;
    GMXV1StableAvalancheModule public gmxV1Module;

    // 2023-09-05
    uint256 public constant AVAX_BLOCK_NUMBER = 34807165;

    // GMX V1 router on Avalanche
    address public constant GMX_V1_ROUTER = 0x5F719c2F1095F7B9fc68a68e35B51194f4b6abe8;

    // GMX V1 vault pool on Avalanche
    address public constant GMX_V1_VAULT = 0x9ab2De34A33fB459b538c43f251eB825645e8595;

    // GMX V1 reader on Avalanche
    address public constant GMX_V1_READER = 0x67b789D48c926006F5132BFCe4e976F0A7A63d5D;

    // Native WAVAX on Avalanche
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    // Bridged WBTC on Avalanche
    address public constant WBTC_E = 0x50b7545627a5162F82A992c33b87aDc75187B218;

    // Bridged WETH on Avalanche
    address public constant WETH_E = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;

    // MIM on Avalanche
    address public constant MIM = 0x130966628846BFd36ff31a822705796e8cb8C18D;

    // Bridged USDC on Avalance
    address public constant USDC_E = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;

    // Native USDC on Avalanche
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    // Bridged BTC on Avalanche
    address public constant BTC_B = 0x152b9d0FdC40C096757F570A51E494bd4b943E50;

    address public user;

    constructor() IntegrationUtils("avalanche", "GMXV1StableAvalancheModule", AVAX_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        gmxV1Module = new GMXV1StableAvalancheModule(GMX_V1_ROUTER, GMX_V1_READER);
        linkedPool = new LinkedPool(USDC_E, address(this));
        user = makeAddr("User");

        vm.label(GMX_V1_ROUTER, "GMXV1Router");
        vm.label(GMX_V1_VAULT, "GMXV1Vault");

        vm.label(WAVAX, "WAVAX");
        vm.label(WBTC_E, "WBTC.e");
        vm.label(WETH_E, "WETH.e");
        vm.label(MIM, "MIM");
        vm.label(USDC_E, "USDC.e");
        vm.label(USDC, "USDC");
        vm.label(BTC_B, "BTC.b");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = gmxV1Module.getPoolTokens(GMX_V1_VAULT);
        assertEq(tokens.length, 2);

        assertEq(tokens[0], USDC_E);
        assertEq(tokens[1], USDC);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: GMX_V1_VAULT, poolModule: address(gmxV1Module)});
    }

    function testAddPool() public {
        addPool();

        assertEq(linkedPool.getToken(0), USDC_E);
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

    function testSwapFromUSDCetoUSDC() public {
        addPool();
        uint256 amount = 10 * 10**6;
        prepareUser(USDC_E, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC_E).balanceOf(user), 0);
        assertEq(IERC20(USDC).balanceOf(user), amountOut);
    }

    function testSwapFromUSDCtoUSDCe() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC).balanceOf(user), 0);
        assertEq(IERC20(USDC_E).balanceOf(user), amountOut);
    }

    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        gmxV1Module.poolSwap({
            pool: GMX_V1_VAULT,
            tokenFrom: IndexedToken({index: 0, token: USDC_E}),
            tokenTo: IndexedToken({index: 1, token: USDC}),
            amountIn: 100 * 10**6
        });
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
