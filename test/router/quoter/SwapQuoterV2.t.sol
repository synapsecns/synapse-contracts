// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../contracts/router/interfaces/IDefaultExtendedPool.sol";
import {SwapQuoterV2, Pool} from "../../../contracts/router/quoter/SwapQuoterV2.sol";
import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockWETH} from "../mocks/MockWETH.sol";
import {PoolUtils08} from "../../utils/PoolUtils08.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";
import {console2} from "forge-std/Test.sol";

// solhint-disable max-states-count
contract SwapQuoterV2Test is PoolUtils08 {
    using SafeERC20 for IERC20;

    SwapQuoterV2 public quoter;
    address public defaultPoolCalc;
    address public synapseRouter;
    address public owner;

    // L2 tokens
    address public neth;
    address public weth;

    address public nusd;
    address public usdc;
    address public usdcE;
    address public usdt;

    // L1 tokens
    address public nexusNusd;
    address public nexusDai;
    address public nexusUsdc;
    address public nexusUsdt;

    // L2 pools
    // bridge pool for nETH
    address public poolNethWeth;
    // bridge pool for nUSD
    address public poolNusdUsdcEUsdt;
    address public linkedPoolNusd;
    // origin-only pool for USDC
    address public poolUsdcUsdcE;
    address public linkedPoolUsdc;
    // origin-only pool
    address public poolUsdcEUsdt;

    // L1 pools
    address public nexusPoolDaiUsdcUsdt;

    function setUp() public virtual override {
        super.setUp();

        synapseRouter = makeAddr("SynapseRouter");
        owner = makeAddr("Owner");

        weth = address(new MockWETH());
        neth = address(new MockERC20("nETH", 18));

        nusd = address(new MockERC20("nUSD", 18));
        usdc = address(new MockERC20("USDC", 6));
        usdcE = address(new MockERC20("USDC.e", 6));
        usdt = address(new MockERC20("USDT", 6));

        nexusDai = address(new MockERC20("ETH DAI", 18));
        nexusUsdc = address(new MockERC20("ETH USDC", 6));
        nexusUsdt = address(new MockERC20("ETH USDT", 6));

        defaultPoolCalc = address(new DefaultPoolCalc());
        quoter = new SwapQuoterV2({
            synapseRouter_: synapseRouter,
            defaultPoolCalc_: defaultPoolCalc,
            weth_: weth,
            owner_: owner
        });

        // Deploy L2 Default Pools
        poolNethWeth = deployDefaultPool("[nETH,WETH]", toArray(neth, weth));
        poolNusdUsdcEUsdt = deployDefaultPool("[nUSD,USDC.e,USDT]", toArray(nusd, usdcE, usdt));
        poolUsdcUsdcE = deployDefaultPool("[USDC,USDC.e]", toArray(usdc, usdcE));
        poolUsdcEUsdt = deployDefaultPool("[USDC.e,USDT]", toArray(usdcE, usdt));
        // Deploy Linked Pools
        linkedPoolNusd = deployLinkedPool(nusd, poolNusdUsdcEUsdt);
        linkedPoolUsdc = deployLinkedPool(usdc, poolUsdcUsdcE);

        // Deploy L1 Default Pool (Nexus)
        nexusPoolDaiUsdcUsdt = deployDefaultPool(
            "[ETH DAI,ETH USDC,ETH USDT]",
            toArray(nexusDai, nexusUsdc, nexusUsdt)
        );
        // Nexus nUSD is the LP token of the Nexus pool
        nexusNusd = getLpToken(nexusPoolDaiUsdcUsdt);

        // Provide initial liquidity to L2 pools
        addLiquidity(poolNethWeth, toArray(100 * 10**18, 101 * 10**18), mintTestTokens);
        addLiquidity(poolNusdUsdcEUsdt, toArray(1000 * 10**18, 1001 * 10**6, 1002 * 10**6), mintTestTokens);
        addLiquidity(poolUsdcUsdcE, toArray(2000 * 10**6, 2001 * 10**6), mintTestTokens);
        addLiquidity(poolUsdcEUsdt, toArray(4000 * 10**6, 4001 * 10**6), mintTestTokens);

        // Provide deep initial liquidity to L1 pool
        addLiquidity(nexusPoolDaiUsdcUsdt, toArray(100000 * 10**18, 100000 * 10**6, 100000 * 10**6), mintTestTokens);
    }

    function testSetup() public {
        assertEq(quoter.synapseRouter(), synapseRouter);
        assertEq(quoter.defaultPoolCalc(), defaultPoolCalc);
        assertEq(quoter.weth(), weth);
        assertEq(quoter.owner(), owner);
    }

    function testSetSynapseRouterUpdatesSynapseRouter() public {
        address newSynapseRouter = makeAddr("NewSynapseRouter");
        vm.prank(owner);
        quoter.setSynapseRouter(newSynapseRouter);
        assertEq(quoter.synapseRouter(), newSynapseRouter);
    }

    function testSetSynapseRouterRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        quoter.setSynapseRouter(address(1));
    }

    function mintTestTokens(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token == nexusNusd) {
            // Nexus nUSD can not be just minted, instead tokens received from initial liquidity are used
            // Make sure to setup the Nexus pool with big enough initial liquidity!
            IERC20(token).safeTransfer(to, amount);
        } else {
            MockERC20(token).mint(to, amount);
        }
    }
}
