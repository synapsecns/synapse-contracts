// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken} from "../../../../../contracts/router/modules/pool/gmx/GMXV1Module.sol";
import {GMXV1StableArbitrumModule} from "../../../../../contracts/router/modules/pool/gmx/GMXV1StableArbitrumModule.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract GMXV1ModuleArbTestFork is Test {
    LinkedPool public linkedPool;
    GMXV1StableArbitrumModule public gmxV1Module;

    // 2023-07-03
    uint256 public constant ARB_BLOCK_NUMBER = 115816525;

    // GMX V1 router on Arbitrum
    address public constant GMX_V1_ROUTER = 0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064;

    // GMX V1 vault pool on Arbitrum
    address public constant GMX_V1_VAULT = 0x489ee077994B6658eAfA855C308275EAd8097C4A;

    // GMX V1 reader on Arbitrum
    address public constant GMX_V1_READER = 0x22199a49A999c351eF7927602CFB187ec3cae489;

    // Native WBTC on Arbitrum
    address public constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    // Native WETH on Arbitrum
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // Bridged USDC on Arbitrum
    address public constant USDC_E = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    // LINK on Arbitrum
    address public constant LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;

    // UNI on Arbitrum
    address public constant UNI = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;

    // Native USDT on Arbitrum
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    // MIM on Arbitrum
    address public constant MIM = 0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A;

    // FRAX on Arbitrum
    address public constant FRAX = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F;

    // DAI on Arbitrum
    address public constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    // Native USDC on Arbitrum
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address public user;

    function setUp() public {
        string memory arbRPC = vm.envString("ARBITRUM_API");
        vm.createSelectFork(arbRPC, ARB_BLOCK_NUMBER);

        gmxV1Module = new GMXV1StableArbitrumModule(GMX_V1_ROUTER, GMX_V1_READER);
        linkedPool = new LinkedPool(USDC_E, address(this));
        user = makeAddr("User");

        vm.label(GMX_V1_ROUTER, "GMXV1Router");
        vm.label(GMX_V1_VAULT, "GMXV1Vault");

        vm.label(WBTC, "WBTC");
        vm.label(WETH, "WETH");
        vm.label(USDC_E, "USDC.e");
        vm.label(LINK, "LINK");
        vm.label(UNI, "UNI");
        vm.label(USDT, "USDT");
        vm.label(MIM, "MIM");
        vm.label(FRAX, "FRAX");
        vm.label(DAI, "DAI");
        vm.label(USDC, "USDC");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = gmxV1Module.getPoolTokens(GMX_V1_VAULT);
        assertEq(tokens.length, 5);

        assertEq(tokens[0], USDC_E);
        assertEq(tokens[1], USDT);
        assertEq(tokens[2], FRAX);
        assertEq(tokens[3], DAI);
        assertEq(tokens[4], USDC);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: GMX_V1_VAULT, poolModule: address(gmxV1Module)});
    }

    function testAddPool() public {
        addPool();

        assertEq(linkedPool.getToken(0), USDC_E);
        assertEq(linkedPool.getToken(1), USDT);
        assertEq(linkedPool.getToken(2), FRAX);
        assertEq(linkedPool.getToken(3), DAI);
        assertEq(linkedPool.getToken(4), USDC);
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

    function testSwapFromUSDCetoUSDT() public {
        addPool();
        uint256 amount = 10 * 10**6;
        prepareUser(USDC_E, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC_E).balanceOf(user), 0);
        assertEq(IERC20(USDT).balanceOf(user), amountOut);
    }

    function testSwapFromUSDTtoUSDCe() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDT, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDT).balanceOf(user), 0);
        assertEq(IERC20(USDC_E).balanceOf(user), amountOut);
    }

    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        gmxV1Module.poolSwap({
            pool: GMX_V1_VAULT,
            tokenFrom: IndexedToken({index: 0, token: USDC_E}),
            tokenTo: IndexedToken({index: 1, token: USDT}),
            amountIn: 100 * 10**6
        });
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
