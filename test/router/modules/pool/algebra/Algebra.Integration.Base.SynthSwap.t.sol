// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../../../utils/IntegrationUtils.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken, IPoolModule, AlgebraModule} from "../../../../../contracts/router/modules/pool/algebra/AlgebraModule.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract AlgebraModuleSynthSwapBaseTestFork is IntegrationUtils {
    LinkedPool public linkedPool;
    IPoolModule public synthSwapModule;

    // 2023-10-25
    uint256 public constant BASE_BLOCK_NUMBER = 5731450;

    // Algebra Router on Base
    address public constant SYNTH_SWAP_ROUTER = 0x2dD788D8B399caa4eE92B5492A6A238Fdf2437de;

    // Eden's Algebra Static Quoter on Base
    address public constant SYNTH_SWAP_STATIC_QUOTER = 0x1Db5a1d5D80fDEfc098635d3869Fa94d6fA44F5a;

    // Algebra USDC.e/DAI pool on Base
    address public constant SYNTH_SWAP_DAI_POOL = 0x2C1E1A69ee809d3062AcE40fB83A9bFB59623d95;

    // Bridged USDC (USDC_E) on Base
    address public constant USDC_E = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;

    // DAI on Base
    address public constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;

    address public user;

    constructor() IntegrationUtils("base", "AlgebraModule.SynthSwap", BASE_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        synthSwapModule = new AlgebraModule(SYNTH_SWAP_ROUTER, SYNTH_SWAP_STATIC_QUOTER);
        linkedPool = new LinkedPool(DAI, address(this));
        user = makeAddr("User");

        vm.label(SYNTH_SWAP_ROUTER, "AlgebraRouter");
        vm.label(SYNTH_SWAP_STATIC_QUOTER, "AlgebraStaticQuoter");
        vm.label(SYNTH_SWAP_DAI_POOL, "AlgebraDAIPool");
        vm.label(USDC_E, "USDC.e");
        vm.label(DAI, "DAI");
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetPoolTokens() public {
        address[] memory tokens = synthSwapModule.getPoolTokens(SYNTH_SWAP_DAI_POOL);
        assertEq(tokens.length, 2);
        // DAI address is lexicographically lower than USDC_E address
        assertEq(tokens[0], DAI);
        assertEq(tokens[1], USDC_E);
    }

    // ══════════════════════════════════════════════ TESTS: ADD POOL ══════════════════════════════════════════════════

    function addPool() public {
        linkedPool.addPool({nodeIndex: 0, pool: SYNTH_SWAP_DAI_POOL, poolModule: address(synthSwapModule)});
    }

    function testAddPool() public {
        addPool();
        assertEq(linkedPool.getToken(0), DAI);
        assertEq(linkedPool.getToken(1), USDC_E);
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

    function testSwapFromDAItoUSDCe() public {
        addPool();
        uint256 amount = 100 * 10**18;
        prepareUser(DAI, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 0, nodeIndexTo: 1, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 0, tokenIndexTo: 1, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(DAI).balanceOf(user), 0);
        assertEq(IERC20(USDC_E).balanceOf(user), amountOut);
    }

    function testSwapFromUSDCetoDAI() public {
        addPool();
        uint256 amount = 100 * 10**6;
        prepareUser(USDC_E, amount);
        uint256 expectedAmountOut = linkedPool.calculateSwap({nodeIndexFrom: 1, nodeIndexTo: 0, dx: amount});
        uint256 amountOut = swap({tokenIndexFrom: 1, tokenIndexTo: 0, amount: amount});
        assertGt(amountOut, 0);
        assertEq(amountOut, expectedAmountOut);
        assertEq(IERC20(USDC_E).balanceOf(user), 0);
        assertEq(IERC20(DAI).balanceOf(user), amountOut);
    }

    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        synthSwapModule.poolSwap({
            pool: SYNTH_SWAP_DAI_POOL,
            tokenFrom: IndexedToken({index: 0, token: DAI}),
            tokenTo: IndexedToken({index: 1, token: USDC_E}),
            amountIn: 100 * 10**6
        });
    }

    function prepareUser(address token, uint256 amount) public {
        deal(token, user, amount);
        vm.prank(user);
        IERC20(token).approve(address(linkedPool), amount);
    }
}
