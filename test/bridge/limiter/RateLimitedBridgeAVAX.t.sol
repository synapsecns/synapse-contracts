// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "./RateLimitedBridge.sol";

contract BridgeRateLimiterTestAvax is RateLimitedBridge {
    address public constant BRIDGE = 0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE;
    address public constant NUSD_POOL =
        0xED2a7edd7413021d440b09D654f3b87712abAB66;

    IERC20 public constant NUSD =
        IERC20(0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46);

    IERC20 public constant SYN =
        IERC20(0x1f1E7c893855525b303f99bDF5c3c05Be09ca251);

    constructor() RateLimitedBridge(BRIDGE) {
        this;
    }

    function testUpgradedCorrectly() public {
        bytes32[] memory kappas = new bytes32[](4);
        kappas[
            0
        ] = 0x86b8965e37f1cce9f656ba75889b2f2298b263eed1c63aea02bed5c8974f63f8;
        kappas[
            1
        ] = 0x0a0f257cd271a186e37f9a27eba2449eb6e653f8504cdcf1da5a3136457bd352;
        kappas[
            2
        ] = 0x3d8fdbb615d44bd698866ece843f3a61b8c9bfc8d63a7ee59687b9af73132db5;
        kappas[
            3
        ] = 0x9d227741cf4247722bbdcd1a910991a24efbb12e5f538410922d07fa0fa42247;

        _testUpgrade(kappas);
    }

    function testMintAndSwap(uint96 amount) public {
        _testBridgeFunction(
            amount,
            NUSD,
            false,
            false,
            IBridge.mintAndSwap.selector,
            IBridge.retryMintAndSwap.selector,
            abi.encode(NUSD_POOL, 0, 1, 0, type(uint256).max)
        );
    }

    function testRetryCount(uint96 amount, uint8 txs) public {
        vm.assume(amount > 0);
        vm.assume(amount < type(uint96).max);
        vm.assume(txs >= 1);
        vm.assume(txs <= 6);

        _setAllowance(NUSD, amount);
        // use (allowance + 1) to get tx rate limited
        ++amount;

        // should be able to fully clear queue twice
        for (uint256 i = 0; i <= 1; ++i) {
            bytes32[] memory kappas = new bytes32[](txs);
            for (uint256 t = 0; t < txs; ++t) {
                kappas[t] = utils.getNextKappa();
                _checkDelayed(
                    kappas[t],
                    NODE_GROUP,
                    bridge,
                    IBridge.mint.selector,
                    _getPayload(NUSD, amount, 0, bytes(""), kappas[t]),
                    true
                );
            }
            assertEq(
                rateLimiter.retryQueueLength(),
                txs,
                "RateLimiter Queue wrong length"
            );

            uint256 pre = IERC20(NUSD).balanceOf(user);
            hoax(limiter);
            rateLimiter.retryCount(txs);
            assertEq(
                rateLimiter.retryQueueLength(),
                0,
                "RateLimiter Queue should be empty"
            );

            for (uint256 t = 0; t < txs; ++t) {
                assertTrue(
                    IBridge(bridge).kappaExists(kappas[t]),
                    "Kappa doesn't exist post-bridge"
                );
            }

            uint256 post = IERC20(NUSD).balanceOf(user);
            assertTrue(pre != post, "User hasn't received anything");
            assertEq(
                post,
                pre + uint256(amount) * txs,
                "User hasn't received full amount"
            );
        }
    }

    function testRetryBoth(uint96 amount, uint8 txs) public {
        vm.assume(amount > 0);
        vm.assume(amount < type(uint96).max);
        vm.assume(txs >= 5);
        vm.assume(txs <= 11);

        _setAllowance(NUSD, amount);
        // use (allowance + 1) to get tx rate limited
        ++amount;

        // should be able to fully clear queue twice
        for (uint256 i = 0; i <= 1; ++i) {
            bytes32[] memory kappas = new bytes32[](txs);
            for (uint256 t = 0; t < txs; ++t) {
                kappas[t] = utils.getNextKappa();
                _checkDelayed(
                    kappas[t],
                    NODE_GROUP,
                    bridge,
                    IBridge.mint.selector,
                    _getPayload(NUSD, amount, 0, bytes(""), kappas[t]),
                    true
                );
            }
            assertEq(
                rateLimiter.retryQueueLength(),
                txs,
                "RateLimiter Queue wrong length"
            );

            uint256 pre = IERC20(NUSD).balanceOf(user);
            startHoax(limiter);
            // manually push through every third tx
            for (uint256 t = 1; t < txs; t += 3) {
                rateLimiter.retryByKappa(kappas[t]);
                assertTrue(
                    IBridge(bridge).kappaExists(kappas[t]),
                    "Kappa doesn't exist post-bridge"
                );
            }

            uint256 post = IERC20(NUSD).balanceOf(user);
            assertTrue(pre != post, "User hasn't received anything");
            assertEq(
                post,
                pre + uint256(amount) * ((txs + 1) / 3),
                "User hasn't received full amount"
            );

            rateLimiter.retryCount(txs);
            assertEq(
                rateLimiter.retryQueueLength(),
                0,
                "RateLimiter Queue should be empty"
            );
            uint256 _post = IERC20(NUSD).balanceOf(user);
            assertTrue(post != _post, "User hasn't received anything");
            assertEq(
                _post,
                pre + uint256(amount) * txs,
                "User hasn't received full amount"
            );

            vm.stopPrank();
        }
    }

    function testPermissionlessRetry(uint96 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < type(uint96).max);

        _setAllowance(NUSD, amount);
        // use (allowance + 1) to get tx rate limited
        ++amount;

        bytes32 kappa = utils.getNextKappa();

        // should be rate limited
        _checkDelayed(
            kappa,
            NODE_GROUP,
            bridge,
            IBridge.mint.selector,
            _getPayload(NUSD, amount, 0, bytes(""), kappa),
            true
        );

        {
            // solhint-disable-next-line
            uint256 currentMin = block.timestamp / 60;

            uint256 resetTimeMin = currentMin + rateLimiter.retryTimeout();
            // set time: 1 second before timeout
            vm.warp(resetTimeMin * 60 - 1);
        }

        // Too early => should revert (bridgeSuccess = false)
        _checkDelayed(
            kappa,
            user,
            address(rateLimiter),
            rateLimiter.retryByKappa.selector,
            abi.encode(kappa),
            false
        );

        skip(1);

        // Timeout finished => user should be able to push through
        _checkCompleted(
            NUSD,
            amount,
            0,
            kappa,
            user,
            address(rateLimiter),
            rateLimiter.retryByKappa.selector,
            abi.encode(kappa),
            true
        );
    }

    function testRetryFailedTx(uint96 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < type(uint96).max);

        _setAllowance(SYN, amount);
        // use (allowance + 1) to get tx rate limited
        ++amount;

        address admin = utils.getRoleMember(address(SYN), 0x00);
        bytes32 minterRole = ISynapseERC20(address(SYN)).MINTER_ROLE();

        bytes32 kappa = utils.getNextKappa();

        _checkDelayed(
            kappa,
            NODE_GROUP,
            bridge,
            IBridge.mint.selector,
            _getPayload(SYN, amount, 0, bytes(""), kappa),
            true
        );

        assertEq(
            rateLimiter.retryQueueLength(),
            1,
            "RateLimiter Queue wrong length"
        );

        hoax(admin);
        // bridge can no longer mint SYN => part of txs will fail
        ISynapseERC20(address(SYN)).revokeRole(minterRole, bridge);

        hoax(limiter);
        rateLimiter.retryCount(1);
        assertEq(
            rateLimiter.retryQueueLength(),
            0,
            "RateLimiter Queue should be empty"
        );

        assertTrue(
            !IBridge(bridge).kappaExists(kappa),
            "SYN kappa should not exist"
        );

        hoax(user);
        try rateLimiter.retryByKappa(kappa) {
            revert("This should've failed");
        } catch Error(string memory reason) {
            assertEq(
                reason,
                string(
                    abi.encodePacked(
                        "Could not call bridge for kappa: ",
                        StringsUpgradeable.toHexString(uint256(kappa), 32),
                        " reverted with: Not a minter"
                    )
                ),
                "Unexpected revert message"
            );
        }

        hoax(admin);
        ISynapseERC20(address(SYN)).grantRole(minterRole, bridge);

        // user should be able to push a failed tx once the issue is solved
        _checkCompleted(
            SYN,
            amount,
            0,
            kappa,
            user,
            address(rateLimiter),
            rateLimiter.retryByKappa.selector,
            abi.encode(kappa),
            true
        );
    }

    function testRetriesWithFailedTxs(uint96 amount, uint8 txs) public {
        vm.assume(amount > 0);
        vm.assume(amount < type(uint96).max);

        _setAllowance(NUSD, amount);
        _setAllowance(SYN, amount);
        // use (allowance + 1) to get tx rate limited
        ++amount;

        vm.assume(txs >= 5);
        vm.assume(txs <= 11);

        address admin = utils.getRoleMember(address(SYN), 0x00);
        bytes32 minterRole = ISynapseERC20(address(SYN)).MINTER_ROLE();

        uint256 txsSyn = (txs + 1) / 3;

        // should be able to fully clear queue twice
        for (uint256 i = 0; i <= 1; ++i) {
            bytes32[] memory kappas = new bytes32[](txs);

            for (uint256 t = 0; t < txs; t++) {
                kappas[t] = utils.getNextKappa();

                if (t % 3 == 1) {
                    _checkDelayed(
                        kappas[t],
                        NODE_GROUP,
                        bridge,
                        IBridge.mint.selector,
                        _getPayload(SYN, amount, 0, bytes(""), kappas[t]),
                        true
                    );
                } else {
                    _checkDelayed(
                        kappas[t],
                        NODE_GROUP,
                        bridge,
                        IBridge.mint.selector,
                        _getPayload(NUSD, amount, 0, bytes(""), kappas[t]),
                        true
                    );
                }
            }
            assertEq(
                rateLimiter.retryQueueLength(),
                txs,
                "RateLimiter Queue wrong length"
            );

            hoax(admin);
            // bridge can no longer mint SYN => part of txs will fail
            ISynapseERC20(address(SYN)).revokeRole(minterRole, bridge);

            uint256 pre = NUSD.balanceOf(user);
            hoax(limiter);
            rateLimiter.retryCount(txs);
            assertEq(
                rateLimiter.retryQueueLength(),
                0,
                "RateLimiter Queue should be empty"
            );
            for (uint256 t = 0; t < txs; t++) {
                if (t % 3 == 1) {
                    assertTrue(
                        !IBridge(bridge).kappaExists(kappas[t]),
                        "SYN kappa should not exist"
                    );
                } else {
                    assertTrue(
                        IBridge(bridge).kappaExists(kappas[t]),
                        "NUSD kappa should exist"
                    );
                }
            }

            uint256 post = NUSD.balanceOf(user);
            assertTrue(pre != post, "User hasn't received anything: NUSD");
            assertEq(
                post,
                pre + uint256(amount) * (txs - txsSyn),
                "User hasn't received full amount: NUSD"
            );

            hoax(admin);
            ISynapseERC20(address(SYN)).grantRole(minterRole, bridge);

            pre = SYN.balanceOf(user);
            hoax(limiter);
            // This should do nothing, as failed transactions are not in queue
            rateLimiter.retryCount(txs);

            for (uint256 t = 1; t < txs; t += 3) {
                assertTrue(
                    !IBridge(bridge).kappaExists(kappas[t]),
                    "SYN kappa should not exist"
                );
            }

            assertEq(
                pre,
                SYN.balanceOf(user),
                "SYN balance should not have changed"
            );

            for (uint256 t = 1; t < txs; t += 3) {
                // anyone should be able to push through a failed tx
                _checkCompleted(
                    SYN,
                    amount,
                    0,
                    kappas[t],
                    user,
                    address(rateLimiter),
                    rateLimiter.retryByKappa.selector,
                    abi.encode(kappas[t]),
                    true
                );
            }

            post = SYN.balanceOf(user);
            assertTrue(pre != post, "User hasn't received anything: SYN");
            assertEq(
                post,
                pre + uint256(amount) * txsSyn,
                "User hasn't received full amount: SYN"
            );
        }
    }
}
