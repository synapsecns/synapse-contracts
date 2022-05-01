// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../utils/DefaultVaultTest.t.sol";

contract VaultUnitTest is DefaultVaultTest {
    IERC20 public syn;

    constructor() DefaultVaultTest(defaultConfig) {
        this;
    }

    function setUp() public override {
        super.setUp();
        syn = _deployERC20("SYN");
    }

    /**
     * @notice Check all access restricted functions
     */
    function testAccessControl() public {
        address _v = address(vault);
        utils.checkAccess(
            _v,
            abi.encodeWithSelector(IVault.initialize.selector),
            "Initializable: contract is already initialized"
        );

        utils.checkAccess(_v, abi.encodeWithSelector(IVault.setChainGasAmount.selector, 0), "Not governance");

        utils.checkAccess(_v, abi.encodeWithSelector(IVault.setWethAddress.selector, address(0)), "Not admin");

        utils.checkAccess(_v, abi.encodeWithSelector(IVault.addKappas.selector, new bytes32[](1)), "Not governance");

        utils.checkAccess(_v, abi.encodeWithSelector(IVault.recoverGAS.selector, attacker), "Not governance");

        utils.checkAccess(
            _v,
            abi.encodeWithSelector(IVault.withdrawFees.selector, address(0), attacker),
            "Not governance"
        );

        utils.checkAccess(_v, abi.encodeWithSelector(IVault.pause.selector), "Not governance");

        utils.checkAccess(_v, abi.encodeWithSelector(IVault.unpause.selector), "Not governance");

        utils.checkAccess(
            _v,
            abi.encodeWithSelector(
                IVault.mintToken.selector,
                address(0),
                address(0),
                0,
                0,
                address(0),
                false,
                bytes32(0)
            ),
            "Not bridge"
        );

        utils.checkAccess(
            _v,
            abi.encodeWithSelector(
                IVault.withdrawToken.selector,
                address(0),
                address(0),
                0,
                0,
                address(0),
                false,
                bytes32(0)
            ),
            "Not bridge"
        );
    }

    /**
     * @notice Check that setChainGasAmount updates gas airdrop amount
     */
    function testSetChainGasAmount(uint256 amount) public {
        hoax(governance);
        vault.setChainGasAmount(amount);
        assertEq(amount, vault.chainGasAmount(), "Failed to set gas airdrop amount");
    }

    /**
     * @notice Check that setWethAddress updates WETH_ADDRESS
     */
    function testSetWethAddress(address payable _address) public {
        hoax(utils.getRoleMember(address(vault), 0x00));
        vault.setWethAddress(_address);
        assertEq(_address, vault.WETH_ADDRESS(), "Failed to set WETH_ADDRESS");
    }

    /**
     * @notice Check that addKappas does in fact add kappas
     */
    function testAddKappas(uint8 amount) public {
        vm.assume(amount <= 10);

        bytes32[] memory kappas = new bytes32[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            kappas[i] = utils.getNextKappa();
        }

        hoax(governance);
        vault.addKappas(kappas);
        for (uint256 i = 0; i < amount; ++i) {
            assertTrue(vault.kappaExists(kappas[i]), "Failed to set kappa");
        }
    }

    /**
     * @notice Check that GAS is recoverable from contract
     */
    function testRecoverGAS() public {
        uint256 amount = TEST_AMOUNT;
        uint256 pre = user.balance;
        deal(address(vault), amount);

        hoax(governance);
        vault.recoverGAS(user);
        assertEq(user.balance, pre + amount, "Failed to recover gas");
    }

    /**
     * @notice Check that governance can claim bridge fees
     */
    function testWithdrawFees() public {
        uint256 amount = TEST_AMOUNT;
        uint256 fee = TEST_AMOUNT / 7;
        deal(address(syn), address(vault), 2 * amount + fee);
        assertEq(vault.getFeeBalance(syn), 0, "Wrong initial fee");

        bytes32 kappa = utils.getNextKappa();
        hoax(address(bridge));
        vault.withdrawToken(user, syn, amount, fee, user, false, kappa);

        uint256 pre = syn.balanceOf(governance);
        hoax(governance);
        vault.withdrawFees(syn, governance);

        assertEq(syn.balanceOf(governance), pre + fee, "Failed to withdraw fees");
        assertEq(vault.getFeeBalance(syn), 0, "Failed to reset fees");
        assertEq(vault.getTokenBalance(syn), amount, "Wrong vault balance");
    }

    /**
     * @notice Check that pause() pauses all vault functions
     */
    function testPause() public {
        utils.checkRevert(
            governance,
            address(vault),
            abi.encodeWithSelector(vault.unpause.selector),
            "Should have failed due to not being paused",
            "Pausable: not paused"
        );

        hoax(governance);
        vault.pause();

        uint256 amount = TEST_AMOUNT;
        bytes32 kappa = utils.getNextKappa();
        deal(address(syn), address(vault), amount);

        utils.checkRevert(
            address(bridge),
            address(vault),
            abi.encodeWithSelector(vault.mintToken.selector, user, syn, amount, 0, user, false, kappa),
            "Should have failed due to being paused",
            "Pausable: paused"
        );
        utils.checkRevert(
            address(bridge),
            address(vault),
            abi.encodeWithSelector(vault.withdrawToken.selector, user, syn, amount, 0, user, false, kappa),
            "Should have failed due to being paused",
            "Pausable: paused"
        );

        hoax(governance);
        vault.unpause();

        startHoax(address(bridge));
        vault.mintToken(user, syn, amount, 0, user, false, kappa);

        kappa = utils.getNextKappa();
        vault.withdrawToken(user, syn, amount, 0, user, false, kappa);
        vm.stopPrank();
    }

    /**
     * @notice Check that mintToken mints token to user and collects bridge fee
     */
    function testMintToken() public {
        startHoax(address(bridge));
        uint256 totalFee = 0;
        for (uint256 i = 0; i < 5; ++i) {
            uint256 amount = TEST_AMOUNT * (i + 1);
            uint256 fee = TEST_AMOUNT / (i + 1);
            bytes32 kappa = utils.getNextKappa();
            uint256 pre = syn.balanceOf(user);
            totalFee += fee;

            vault.mintToken(user, syn, amount, fee, user, false, kappa);

            assertEq(syn.balanceOf(user), pre + amount, "Mint is not complete");
            assertEq(vault.getFeeBalance(syn), totalFee, "Bridge fee is not collected");
            assertEq(vault.getTokenBalance(syn), 0, "Wrong vault balance post-mint");
        }
        vm.stopPrank();
    }

    /**
     * @notice Check that mintToken withdraws token to user and collects bridge fee
     */
    function testWithdrawToken() public {
        uint256 totalFee = 0;
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < 5; ++i) {
            totalAmount += TEST_AMOUNT * (i + 1);
            totalFee += TEST_AMOUNT / (i + 1);
        }

        totalAmount += totalFee;
        totalFee = 0;
        deal(address(syn), address(vault), totalAmount);
        startHoax(address(bridge));

        for (uint256 i = 0; i < 5; ++i) {
            uint256 amount = TEST_AMOUNT * (i + 1);
            uint256 fee = TEST_AMOUNT / (i + 1);
            bytes32 kappa = utils.getNextKappa();
            uint256 pre = syn.balanceOf(user);
            totalFee += fee;
            totalAmount -= (amount + fee);

            vault.withdrawToken(user, syn, amount, fee, user, false, kappa);

            assertEq(syn.balanceOf(user), pre + amount, "Withdraw is not complete");
            assertEq(vault.getFeeBalance(syn), totalFee, "Bridge fee is not collected");
            assertEq(vault.getTokenBalance(syn), totalAmount, "Wrong vault balance post-withdraw");
        }
        vm.stopPrank();
    }

    /**
     * @notice Check that fees are accumulated over time,
     * and that it's not possible to withdraw fees by bridging "too much"
     */
    function testFeesAccumulating() public {
        uint256 amount = TEST_AMOUNT;
        uint256 fee = TEST_AMOUNT / 10;
        bytes32 kappa = utils.getNextKappa();
        deal(address(syn), address(vault), amount + fee);

        assertEq(vault.getTokenBalance(syn), amount + fee, "Failed to top up bridge");
        assertEq(vault.getFeeBalance(syn), 0, "Wrong initial fee balance");

        hoax(address(bridge));
        vault.mintToken(user, syn, amount, fee, user, false, kappa);

        assertEq(vault.getFeeBalance(syn), fee, "Wrong fee balance after 1st tx");
        assertEq(vault.getTokenBalance(syn), amount + fee, "Wrong vault balance after 1st tx");

        kappa = utils.getNextKappa();
        utils.checkRevert(
            address(bridge),
            address(vault),
            abi.encodeWithSelector(vault.withdrawToken.selector, user, syn, amount + 1, fee, user, false, kappa),
            "Should not be able to withdraw fees by bridging",
            "Withdraw amount is too big"
        );

        hoax(address(bridge));
        vault.withdrawToken(user, syn, amount, fee, user, false, kappa);

        assertEq(vault.getFeeBalance(syn), 2 * fee, "Wrong fee balance after 2nd tx");
        assertEq(vault.getTokenBalance(syn), 0, "Wrong vault balance after 2nd tx");

        hoax(governance);
        vault.withdrawFees(syn, governance);

        assertEq(vault.getFeeBalance(syn), 0, "Failed to update accumulated fees");
        assertEq(syn.balanceOf(governance), 2 * fee, "Failed to withdraw accumulated fees");
    }

    /**
     * @notice Check that gas airdrop can be turned on and off.
     * Also check that vault can airdrop exactly as much as it has GAS left.
     */
    function testGasAirdrop() public {
        uint256 gasDrop = 4815162342;
        deal(address(vault), 10**18);
        deal(address(syn), address(vault), 10**18);

        hoax(governance);
        vault.setChainGasAmount(gasDrop);
        // enable & check airdrop
        _checkDrop(user, user, gasDrop);
        _checkDrop(dude, user, gasDrop);

        hoax(governance);
        vault.setChainGasAmount(0);
        // no more airdrop
        _checkDrop(user, user, 0);
        _checkDrop(dude, user, 0);

        gasDrop = TEST_AMOUNT;
        hoax(governance);
        // change airdrop amount
        vault.setChainGasAmount(gasDrop);
        // load exactly as much gas for two airdrops
        deal(address(vault), 2 * gasDrop);
        _checkDrop(user, user, gasDrop);
        deal(address(vault), 2 * gasDrop);
        _checkDrop(dude, user, gasDrop);

        // load 1 wei less than airdrop amount, should receive nothing
        deal(address(vault), gasDrop - 1);
        _checkDrop(user, user, 0);
        _checkDrop(dude, user, 0);
    }

    function _checkDrop(
        address tokensTo,
        address gasDropTo,
        uint256 gasDrop
    ) public {
        uint256 amount = TEST_AMOUNT;
        uint256 fee = TEST_AMOUNT / 42;
        uint256 pre = gasDropTo.balance;
        bytes32 kappa = utils.getNextKappa();

        startHoax(address(bridge));
        vault.mintToken(tokensTo, syn, amount, fee, gasDropTo, false, kappa);
        assertEq(gasDropTo.balance, pre, "Wrong user gas balance: mint w/o gasDrop");

        kappa = utils.getNextKappa();
        vault.withdrawToken(tokensTo, syn, amount, fee, gasDropTo, false, kappa);
        assertEq(gasDropTo.balance, pre, "Wrong user gas balance: withdraw w/o gasDrop");

        kappa = utils.getNextKappa();
        vault.mintToken(tokensTo, syn, amount, fee, gasDropTo, true, kappa);
        assertEq(gasDropTo.balance, pre + gasDrop, "Wrong user gas balance: mint with gasDrop");

        kappa = utils.getNextKappa();
        vault.withdrawToken(tokensTo, syn, amount, fee, gasDropTo, true, kappa);
        assertEq(gasDropTo.balance, pre + 2 * gasDrop, "Wrong user gas balance: withdraw with gasDrop");
        vm.stopPrank();
    }
}
