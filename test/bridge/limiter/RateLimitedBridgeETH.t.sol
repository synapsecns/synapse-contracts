// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "./RateLimitedBridge.sol";

contract BridgeRateLimiterTestEth is RateLimitedBridge {
    address public constant BRIDGE = 0x2796317b0fF8538F253012862c06787Adfb8cEb6;
    address public constant NUSD_POOL = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;

    IERC20 public constant NUSD = IERC20(0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F);
    IERC20 public constant SYN = IERC20(0x0f2D719407FdBeFF09D87557AbB7232601FD9F29);

    constructor() RateLimitedBridge(BRIDGE, [address(SYN), address(NUSD)]) {
        this;
    }

    function testUpgradedCorrectly() public {
        bytes32[] memory kappas = new bytes32[](4);
        kappas[0] = 0x58b29a4cf220b60a7e46b76b9831686c0bfbdbfea19721ef8f2192ba28514485;
        kappas[1] = 0x3745754e018ed57dce0feda8b027f04b7e1369e7f74f1a247f5f7352d519021c;
        kappas[2] = 0xea5bc18a60d2f1b9ba5e5f8bfef3cd112c3b1a1ef74a0de8e5989441b1722524;
        kappas[3] = 0x1d4f3f6ed7690f1e5c1ff733d2040daa12fa484b3acbf37122ff334b46cf8b6d;

        _testUpgrade(kappas);
    }

    function testExactAllowance() public {
        // let's withdraw 1% of TVL
        uint96 amount = uint96(_getBridgeBalance(NUSD) / 100);

        _setAllowance(NUSD, amount);

        uint96 totalBridged = 0;
        for (uint256 i = 0; i < 3; i++) {
            uint96 amountBridged = (i == 2 ? amount - totalBridged : amount / 3);
            bytes32 kappa = utils.getNextKappa();
            totalBridged += amountBridged;

            _checkCompleted(
                NUSD,
                amountBridged,
                0,
                kappa,
                NODE_GROUP,
                BRIDGE,
                IBridge.withdraw.selector,
                abi.encode(user, NUSD, amountBridged, 0, kappa),
                true
            );
        }

        // This should never happen
        assertEq(totalBridged, amount, "Sanity check failed");

        {
            uint256 amountBridged = 1;
            bytes32 kappa = utils.getNextKappa();
            // This should be rate limited
            _checkDelayed(
                kappa,
                NODE_GROUP,
                BRIDGE,
                IBridge.withdraw.selector,
                abi.encode(user, NUSD, amountBridged, 0, kappa),
                true
            );
        }
    }

    function testMint() public {
        uint96 amount = 10**18;
        _testBridgeFunction(amount, SYN, false, true, IBridge.mint.selector, IBridge.retryMint.selector, bytes(""));
    }

    function testWithdraw() public {
        // let's withdraw 1% of TVL
        uint96 amount = uint96(_getBridgeBalance(NUSD) / 100);
        _testBridgeFunction(
            amount,
            NUSD,
            true,
            true,
            IBridge.withdraw.selector,
            IBridge.retryWithdraw.selector,
            bytes("")
        );
    }

    function testWithdrawAndRemove() public {
        // let's withdraw 1% of TVL
        uint96 amount = uint96(_getBridgeBalance(NUSD) / 100);
        _testBridgeFunction(
            amount,
            NUSD,
            true,
            false,
            IBridge.withdrawAndRemove.selector,
            IBridge.retryWithdrawAndRemove.selector,
            abi.encode(NUSD_POOL, 0, 0, type(uint256).max)
        );
    }

    function testAccessChecksRateLimiter() public {
        address _rl = address(rateLimiter);
        address trap = utils.getNextUserAddress();
        bytes32 fakeKappa = utils.getNextKappa();

        _checkAccess(_rl, rateLimiter.initialize.selector, bytes(""), "Initializable: contract is already initialized");

        _checkAccessControl(
            _rl,
            rateLimiter.setBridgeAddress.selector,
            abi.encode(trap),
            rateLimiter.GOVERNANCE_ROLE()
        );

        _checkAccessControl(_rl, rateLimiter.setRetryTimeout.selector, abi.encode(0), rateLimiter.GOVERNANCE_ROLE());

        _checkAccessControl(
            _rl,
            rateLimiter.setAllowance.selector,
            abi.encode(NUSD, type(uint96).max, 1, 0),
            rateLimiter.LIMITER_ROLE()
        );

        _checkAccessControl(
            _rl,
            rateLimiter.checkAndUpdateAllowance.selector,
            abi.encode(NUSD, 42),
            rateLimiter.BRIDGE_ROLE()
        );

        _checkAccessControl(
            _rl,
            rateLimiter.addToRetryQueue.selector,
            abi.encode(fakeKappa, bytes("I AM HACKOOOOR")),
            rateLimiter.BRIDGE_ROLE()
        );

        _checkAccessControl(_rl, rateLimiter.retryCount.selector, abi.encode(1), rateLimiter.LIMITER_ROLE());

        _checkAccessControl(_rl, rateLimiter.deleteByKappa.selector, abi.encode(fakeKappa), rateLimiter.LIMITER_ROLE());

        _checkAccessControl(_rl, rateLimiter.resetAllowance.selector, abi.encode(NUSD), rateLimiter.LIMITER_ROLE());
    }

    function testAccessChecksBridge() public {
        address trap = utils.getNextUserAddress();

        _checkAccess(bridge, IBridge.initialize.selector, bytes(""), "Initializable: contract is already initialized");

        _checkAccess(bridge, IBridge.setChainGasAmount.selector, abi.encode(69), "Not governance");

        _checkAccess(bridge, IBridge.setWethAddress.selector, abi.encode(trap), "Not admin");

        _checkAccess(bridge, IBridge.setRateLimiter.selector, abi.encode(trap), "Not governance");

        _checkAccess(bridge, IBridge.setRateLimiterEnabled.selector, abi.encode(false), "Not governance");

        _checkAccess(bridge, IBridge.addKappas.selector, abi.encode(new bytes32[](1)), "Not governance");

        _checkAccess(bridge, IBridge.withdrawFees.selector, abi.encode(NUSD, attacker), "Not governance");

        _checkAccess(bridge, IBridge.pause.selector, bytes(""), "Not governance");

        _checkAccess(bridge, IBridge.unpause.selector, bytes(""), "Not governance");
    }
}
