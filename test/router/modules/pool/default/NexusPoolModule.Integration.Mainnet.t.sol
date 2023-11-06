// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../../../utils/IntegrationUtils.sol";

import {LinkedPool} from "../../../../../contracts/router/LinkedPool.sol";
import {IndexedToken, NexusPoolModule} from "../../../../../contracts/router/modules/pool/default/NexusPoolModule.sol";

import {DelegateCaller} from "../../bridge/DelegateCaller.sol";
import {IPausable} from "../../../../interfaces/IPausable.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract NexusPoolModuleEthTestFork is IntegrationUtils {
    using SafeERC20 for IERC20;

    LinkedPool public linkedPool;
    NexusPoolModule public nexusPoolModule;

    DelegateCaller public caller;

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
        nexusPoolModule = new NexusPoolModule();
        linkedPool = new LinkedPool(USDC, address(this));
        user = makeAddr("User");
        caller = new DelegateCaller();
    }

    // ═══════════════════════════════════════════ TESTS: REVERTS (SWAP) ═══════════════════════════════════════════════

    function testPoolSwapRevertsWhenDirectCall() public {
        vm.expectRevert("Not a delegate call");
        nexusPoolModule.poolSwap({
            pool: NEXUS_POOL,
            tokenFrom: IndexedToken({token: USDC, index: 0}),
            tokenTo: IndexedToken({token: DAI, index: 1}),
            amountIn: 100 * 10**6
        });
    }

    function testPoolSwapRevertsWhenUnsupportedPool() public {
        bytes memory encodedCall = abi.encodeCall(
            nexusPoolModule.poolSwap,
            (address(1337), IndexedToken({token: USDC, index: 0}), IndexedToken({token: DAI, index: 1}), 100 * 10**6)
        );
        vm.expectRevert(
            abi.encodeWithSelector(NexusPoolModule.NexusPoolModule__UnsupportedPool.selector, address(1337))
        );
        caller.performDelegateCall(address(nexusPoolModule), encodedCall);
    }

    function testPoolSwapRevertsWhenEqualIndexes() public {
        for (uint8 index = 0; index <= 3; ++index) {
            address token = nexusPoolModule.getPoolTokens(NEXUS_POOL)[index];
            bytes memory encodedCall = abi.encodeCall(
                nexusPoolModule.poolSwap,
                (
                    NEXUS_POOL,
                    IndexedToken({token: token, index: index}),
                    IndexedToken({token: token, index: index}),
                    100 * 10**6
                )
            );
            vm.expectRevert(abi.encodeWithSelector(NexusPoolModule.NexusPoolModule__EqualIndexes.selector, index));
            caller.performDelegateCall(address(nexusPoolModule), encodedCall);
        }
    }

    function testPoolSwapRevertsWhenUnsupportedToIndex() public {
        bytes memory encodedCall = abi.encodeCall(
            nexusPoolModule.poolSwap,
            (NEXUS_POOL, IndexedToken({token: USDC, index: 0}), IndexedToken({token: NUSD, index: 4}), 100 * 10**6)
        );
        vm.expectRevert(abi.encodeWithSelector(NexusPoolModule.NexusPoolModule__UnsupportedIndex.selector, 4));
        caller.performDelegateCall(address(nexusPoolModule), encodedCall);
    }

    function testPoolSwapRevertsWhenUnsupportedFromIndex() public {
        bytes memory encodedCall = abi.encodeCall(
            nexusPoolModule.poolSwap,
            (NEXUS_POOL, IndexedToken({token: NUSD, index: 4}), IndexedToken({token: USDC, index: 0}), 100 * 10**6)
        );
        vm.expectRevert(abi.encodeWithSelector(NexusPoolModule.NexusPoolModule__UnsupportedIndex.selector, 4));
        caller.performDelegateCall(address(nexusPoolModule), encodedCall);
    }

    // ══════════════════════════════════════════ TESTS: REVERTS (VIEWS) ═══════════════════════════════════════════════

    function testGetPoolTokensRevertsWhenUnsupportedPool() public {
        vm.expectRevert(
            abi.encodeWithSelector(NexusPoolModule.NexusPoolModule__UnsupportedPool.selector, address(1337))
        );
        nexusPoolModule.getPoolTokens(address(1337));
    }

    function testGetPoolQuoteRevertsWhenUnsupportedPool() public {
        vm.expectRevert(
            abi.encodeWithSelector(NexusPoolModule.NexusPoolModule__UnsupportedPool.selector, address(1337))
        );
        nexusPoolModule.getPoolQuote(
            address(1337),
            IndexedToken({token: USDC, index: 0}),
            IndexedToken({token: DAI, index: 1}),
            100 * 10**6,
            false
        );
    }

    function testGetPoolQuoteRevertsWhenEqualIndexes() public {
        for (uint8 index = 0; index <= 3; ++index) {
            address token = nexusPoolModule.getPoolTokens(NEXUS_POOL)[index];
            vm.expectRevert(abi.encodeWithSelector(NexusPoolModule.NexusPoolModule__EqualIndexes.selector, index));
            nexusPoolModule.getPoolQuote(
                NEXUS_POOL,
                IndexedToken({token: token, index: index}),
                IndexedToken({token: token, index: index}),
                100 * 10**6,
                false
            );
        }
    }

    function testGetPoolQuoteRevertsWhenUnsupportedToIndex() public {
        vm.expectRevert(abi.encodeWithSelector(NexusPoolModule.NexusPoolModule__UnsupportedIndex.selector, 4));
        nexusPoolModule.getPoolQuote(
            NEXUS_POOL,
            IndexedToken({token: USDC, index: 0}),
            IndexedToken({token: NUSD, index: 4}),
            100 * 10**6,
            false
        );
    }

    function testGetPoolQuoteRevertsWhenUnsupportedFromIndex() public {
        vm.expectRevert(abi.encodeWithSelector(NexusPoolModule.NexusPoolModule__UnsupportedIndex.selector, 4));
        nexusPoolModule.getPoolQuote(
            NEXUS_POOL,
            IndexedToken({token: NUSD, index: 4}),
            IndexedToken({token: USDC, index: 0}),
            100 * 10**6,
            false
        );
    }

    function pausePool() public {
        address owner = Ownable(NEXUS_POOL).owner();
        vm.prank(owner);
        IPausable(NEXUS_POOL).pause();
    }

    function testGetPoolQuoteRevertsWhenPoolPaused() public {
        pausePool();
        vm.expectRevert(NexusPoolModule.NexusPoolModule__Paused.selector);
        nexusPoolModule.getPoolQuote(
            NEXUS_POOL,
            IndexedToken({token: USDC, index: 0}),
            IndexedToken({token: DAI, index: 1}),
            100 * 10**6,
            true
        );
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

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
