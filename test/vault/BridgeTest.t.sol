// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../utils/DefaultVaultTest.t.sol";

import {IBridgeRouter} from "src-router/interfaces/IBridgeRouter.sol";
import {IBridge} from "src-vault/interfaces/IBridge.sol";

contract BridgeUnitTest is DefaultVaultTest {
    IERC20 public syn;

    address public constant SYN_EVM = address(1337420);
    uint256 public constant CHAIN_ID_EVM = 1;

    string public constant SYN_NON_EVM = "syn from non-EVM";
    uint256 public constant CHAIN_ID_NON_EVM = 420;

    uint256 public constant FEE = 10**7;
    uint256 public constant FEE_DENOMINATOR = 10**10;
    uint256 public constant MIN_FEE = 10**18;

    uint256 public constant GAS_DROP = 10**16;

    constructor() DefaultVaultTest(defaultConfig) {
        this;
    }

    function setUp() public override {
        super.setUp();
        syn = _deployERC20("SYN");
    }

    /**
     * @notice Check that initializing was done correctly
     */
    function testCorrectInit() public {
        assertEq(address(bridge.bridgeConfig()), address(bridgeConfig), "Failed to setup bridgeConfig");
        assertEq(address(bridge.vault()), address(vault), "Failed to setup vault");
        assertEq(address(bridge.router()), address(router), "Failed to setup router");
        assertEq(bridge.maxGasForSwap(), defaultConfig.maxGasForSwap, "Failed to setup maxGasForSwap");
    }

    /**
     * @notice Check all access restricted functions
     */
    function testAccessControl() public {
        address _b = address(bridge);
        utils.checkAccess(
            _b,
            abi.encodeWithSelector(bridge.initialize.selector, address(0), address(0), 0),
            "Initializable: contract is already initialized"
        );

        utils.checkAccessControl(_b, abi.encodeWithSelector(bridge.recoverGAS.selector), bridge.GOVERNANCE_ROLE());
        utils.checkAccessControl(
            _b,
            abi.encodeWithSelector(bridge.recoverERC20.selector, address(0)),
            bridge.GOVERNANCE_ROLE()
        );
        utils.checkAccessControl(
            _b,
            abi.encodeWithSelector(bridge.setMaxGasForSwap.selector, 0),
            bridge.GOVERNANCE_ROLE()
        );
        utils.checkAccessControl(
            _b,
            abi.encodeWithSelector(bridge.setRouter.selector, address(0)),
            bridge.GOVERNANCE_ROLE()
        );

        Bridge.SwapParams memory params;

        utils.checkAccessControl(
            _b,
            abi.encodeWithSelector(bridge.bridgeInEVM.selector, address(0), address(0), 0, params, false, bytes32(0)),
            bridge.NODEGROUP_ROLE()
        );
        utils.checkAccessControl(
            _b,
            abi.encodeWithSelector(bridge.bridgeInNonEVM.selector, 0, "", 0, bytes32(0)),
            bridge.NODEGROUP_ROLE()
        );
    }

    /**
     * @notice Check that governance can rescue GAS from contract
     */
    function testRecoverGAS() public {
        uint256 amount = TEST_AMOUNT;
        uint256 pre = governance.balance;
        deal(address(bridge), amount);

        hoax(governance);
        bridge.recoverGAS();
        assertEq(governance.balance, pre + amount, "Failed to recover gas");
    }

    /**
     * @notice Check that governance can rescue ERC20 from contract
     */
    function testRecoverERC20() public {
        uint256 amount = TEST_AMOUNT;
        uint256 pre = syn.balanceOf(governance);
        deal(address(syn), address(bridge), amount, true);

        hoax(governance);
        bridge.recoverERC20(syn);
        assertEq(syn.balanceOf(governance), pre + amount, "Failed to recover ERC20");
    }

    /**
     * @notice Check that maxGasForSwap can be updated be governance
     */
    function testSetMaxGasForSwap() public {
        uint256 amount = 1337420;
        hoax(governance);
        bridge.setMaxGasForSwap(amount);
        assertEq(bridge.maxGasForSwap(), amount, "Failed to set maxGasForSwap");
    }

    /**
     * @notice Check that maxGasForSwap can be updated be governance
     */
    function testSetRouter() public {
        address payable _a = utils.getNextUserAddress();
        hoax(governance);
        bridge.setRouter(IBridgeRouter(_a));
        assertEq(address(bridge.router()), _a, "Failed to set router");
    }

    /**
     * @notice Check that "burn" bridging to EVM chain works
     */
    function testBurnBridgeToEVM() public {
        _setupBridging(true);
        uint256 pre = syn.totalSupply();
        // test tokens will be minted in _check function
        _checkBridgeToEVM(TEST_AMOUNT);
        // totalSupply should be the same (minted TEST_AMOUNT, burnt TEST_AMOUNT)
        assertEq(syn.totalSupply(), pre, "No burn happened");
    }

    /**
     * @notice Check that "deposit" bridging to EVM chain works
     */
    function testDepositBridgeToEVM() public {
        _setupBridging(false);
        uint256 pre = syn.balanceOf(address(vault));
        _checkBridgeToEVM(TEST_AMOUNT);
        assertEq(vault.getTokenBalance(syn), pre + TEST_AMOUNT, "No deposit happened");
    }

    /**
     * @notice Check that "burn" bridging to non-EVM chain works
     */
    function testBurnBridgeToNonEVM() public {
        _setupBridging(true);
        uint256 pre = syn.totalSupply();
        // test tokens will be minted in _check function
        _checkBridgeToNonEVM(TEST_AMOUNT);
        // totalSupply should be the same (minted TEST_AMOUNT, burnt TEST_AMOUNT)
        assertEq(syn.totalSupply(), pre, "No burn happened");
    }

    /**
     * @notice Check that "deposit" bridging to non-EVM chain works
     */
    function testDepositBridgeToNonEVM() public {
        _setupBridging(false);
        uint256 pre = syn.balanceOf(address(vault));
        _checkBridgeToNonEVM(TEST_AMOUNT);
        assertEq(vault.getTokenBalance(syn), pre + TEST_AMOUNT, "No deposit happened");
    }

    /**
     * @notice Check that "mint" bridging from EVM chain works,
     * both with gasDrop or without.
     * Also checks that any of the kappas can not be reused.
     */
    function testMintBridgeInFromEVM() public {
        _setupBridgingIn(true);

        _checkBridgeInEVM(true, false);
        _checkBridgeInEVM(true, true);
    }

    /**
     * @notice Check that "withdraw" bridging from EVM chain works,
     * both with gasDrop or without.
     * Also checks that any of the kappas can not be reused.
     */
    function testWithdrawBridgeInFromEVM() public {
        _setupBridgingIn(false);
        // prepare lots of "deposited tokens", update totalSupply
        deal(address(syn), address(vault), 10**30, true);

        _checkBridgeInEVM(false, false);
        _checkBridgeInEVM(false, true);
    }

    /**
     * @notice Check that "mint" bridging from non-EVM chain works,
     * with gasDrop (gasDrop is always enabled from non-EVM atm).
     * Also checks that kappa can not be reused.
     */
    function testMintBridgeInFromNonEVM() public {
        _setupBridgingIn(true);

        _checkBridgeInNonEVM(true);
    }

    /**
     * @notice Check that "withdraw" bridging from non-EVM chain works,
     * with gasDrop (gasDrop is always enabled from non-EVM atm).
     * Also checks that kappa can not be reused.
     */
    function testWithdrawBridgeInFromNonEVM() public {
        _setupBridgingIn(false);
        // prepare lots of "deposited tokens", update totalSupply
        deal(address(syn), address(vault), 10**30, true);

        _checkBridgeInNonEVM(false);
    }

    /**
     * @notice Check that bridge in transactions from both EVM and non-EVM
     * fail, if amount <= fee. Also check that amount = fee + 1 leads to successful tx.
     */
    function testBridgeInTooSmall() public {
        _setupBridgingIn(true);

        _checkBridgeInTooSmall(false);
        _checkBridgeInTooSmall(true);
    }

    /**
     * @notice Check that bridging to/from chain is not possible when token.isEnabled is set
     * to false via BridgeConfig. Also check that everything is working, once token is enabled again.
     */
    function testBridgeInOutDisabled() public {
        _setupBridgingIn(true);

        hoax(governance);
        bridgeConfig.changeTokenStatus(address(syn), false);

        _checkAllBridgingDisabled("!enabled", "!enabled", "!enabled", "!enabled");

        hoax(governance);
        bridgeConfig.changeTokenStatus(address(syn), true);

        _checkBridgeInEVM(true, false);
        _checkBridgeInNonEVM(true);
        _checkBridgeToEVM(TEST_AMOUNT);
        _checkBridgeToNonEVM(TEST_AMOUNT);
    }

    /**
     * @notice Check that bridging unrecognised token is not possible,
     * both IN and OUT.
     */
    function testBridgeInOutUnknownToken() public {
        // No setup is being done => SYN is not registered => should fail
        _checkAllBridgingDisabled("!enabled", "!token", "!token", "!token");
    }

    /**
     * @notice Checks that bridging in all directions is not possible, both
     * to EVM and non-EVM chain.
     * Also checks that revert message on bridging is the same as provided.
     */
    function _checkAllBridgingDisabled(
        string memory revertMsgInEVM,
        string memory revertMsgInNonEVM,
        string memory revertMsgOutEVM,
        string memory revertMsgOutNonEVM
    ) internal {
        bytes32 kappa = utils.getNextKappa();
        Bridge.SwapParams memory swapParams;
        swapParams.path = new address[](1);
        swapParams.path[0] = address(syn);

        Bridge.SwapParams memory destSwapParams;
        destSwapParams.path = new address[](1);
        destSwapParams.path[0] = SYN_EVM;

        uint256 amount = MIN_FEE * 123456;

        utils.checkRevert(
            node,
            address(bridge),
            abi.encodeWithSelector(bridge.bridgeInEVM.selector, user, syn, amount, swapParams, false, kappa),
            "Should have failed due to being disabled",
            revertMsgInEVM
        );
        utils.checkRevert(
            node,
            address(bridge),
            abi.encodeWithSelector(bridge.bridgeInNonEVM.selector, user, CHAIN_ID_NON_EVM, SYN_NON_EVM, amount, kappa),
            "Should have failed due to being disabled",
            revertMsgInNonEVM
        );

        utils.checkRevert(
            user,
            address(bridge),
            abi.encodeWithSelector(bridge.bridgeToEVM.selector, user, CHAIN_ID_EVM, syn, destSwapParams, false),
            "Should have failed due to being disabled",
            revertMsgOutEVM
        );
        utils.checkRevert(
            user,
            address(bridge),
            abi.encodeWithSelector(bridge.bridgeToNonEVM.selector, keccak256("user"), CHAIN_ID_NON_EVM, syn),
            "Should have failed due to being disabled",
            revertMsgOutNonEVM
        );
    }

    // -- INTERNAL: BRIDGE OUT --

    /**
     * @notice Loads tokens into Bridge and invokes bridging to EVM chain.
     * Checks that there are no revert, and that there are no leftover tokens in Bridge.
     */
    function _checkBridgeToEVM(uint256 amount) internal {
        // deal tokens directly to bridge, and update totalSupply
        deal(address(syn), address(bridge), amount, true);

        Bridge.SwapParams memory swapParams;
        swapParams.path = new address[](1);
        swapParams.path[0] = SYN_EVM;

        vm.expectEmit(true, false, false, true);
        emit BridgedOutEVM(user, CHAIN_ID_EVM, syn, amount, IERC20(SYN_EVM), swapParams, false);

        hoax(user);
        bridge.bridgeToEVM(user, CHAIN_ID_EVM, syn, swapParams, false);
        assertEq(syn.balanceOf(address(bridge)), 0, "Tokens left in Bridge");
    }

    /**
     * @notice Loads tokens into Bridge and invokes bridging to non-EVM chain.
     * Checks that there are no revert, and that there are no leftover tokens in Bridge.
     */
    function _checkBridgeToNonEVM(uint256 amount) internal {
        bytes32 to = keccak256("user");
        // deal tokens directly to bridge, and update totalSupply
        deal(address(syn), address(bridge), amount, true);

        Bridge.SwapParams memory swapParams;
        swapParams.path = new address[](1);
        swapParams.path[0] = SYN_EVM;

        vm.expectEmit(true, false, false, true);
        emit BridgedOutNonEVM(to, CHAIN_ID_NON_EVM, syn, amount, SYN_NON_EVM);

        hoax(user);
        bridge.bridgeToNonEVM(to, CHAIN_ID_NON_EVM, syn);
        assertEq(syn.balanceOf(address(bridge)), 0, "Tokens left in Bridge");
    }

    // -- INTERNAL: BRIDGE IN --

    /**
     * @notice Tries bridging in amounts <= minFee: 0, minFee/2 and minFee.
     * Checks that these transaction revert and checks the revert message.
     * Also checks that amount=minFee+1 is a successful bridge in transaction.
     */
    function _checkBridgeInTooSmall(bool gasdropRequested) internal {
        uint256 amount = gasdropRequested ? 2 * MIN_FEE : MIN_FEE;
        bytes32 kappa = utils.getNextKappa();

        Bridge.SwapParams memory swapParams;
        swapParams.path = new address[](1);
        swapParams.path[0] = address(syn);

        uint256[3] memory amounts = [0, amount / 2, amount];

        for (uint256 i = 0; i < amounts.length; ++i) {
            utils.checkRevert(
                node,
                address(bridge),
                abi.encodeWithSelector(
                    bridge.bridgeInEVM.selector,
                    user,
                    syn,
                    amounts[i],
                    swapParams,
                    gasdropRequested,
                    kappa
                ),
                "Should have failed due to amount too low",
                "!fee"
            );

            utils.checkRevert(
                node,
                address(bridge),
                abi.encodeWithSelector(
                    bridge.bridgeInNonEVM.selector,
                    user,
                    CHAIN_ID_NON_EVM,
                    SYN_NON_EVM,
                    amounts[i],
                    kappa
                ),
                "Should have failed due to amount too low",
                "!fee"
            );
        }

        uint256 userPre = syn.balanceOf(user);

        startHoax(node);
        bridge.bridgeInEVM(user, syn, amount + 1, swapParams, gasdropRequested, kappa);
        assertEq(syn.balanceOf(user), userPre + 1, "Bridge incomplete");

        if (gasdropRequested) {
            kappa = utils.getNextKappa();
            bridge.bridgeInNonEVM(user, CHAIN_ID_NON_EVM, SYN_NON_EVM, amount + 1, kappa);
            assertEq(syn.balanceOf(user), userPre + 2, "Bridge incomplete");
        }
        vm.stopPrank();
    }

    struct _BridgeInTestData {
        bytes32 kappa;
        Bridge.SwapParams swapParams;
        uint256 amount;
        uint256 fee;
        uint256 gasdropAmount;
        uint256 vaultPre;
        uint256 supplyPre;
        uint256 userPre;
        uint256 gasPre;
    }

    /**
     * @notice Does a valid bridge in transaction from EVM either via mint or withdraw.
     * Checks emitted event, user balance and token supply post-bridge tx.
     */
    function _checkBridgeInEVM(bool isMint, bool gasdropRequested) internal {
        _BridgeInTestData memory data;
        data.kappa = utils.getNextKappa();
        data.swapParams.path = new address[](1);
        data.swapParams.path[0] = address(syn);
        data.amount = (MIN_FEE * FEE_DENOMINATOR) / FEE;
        data.fee = gasdropRequested ? 2 * MIN_FEE : MIN_FEE;
        data.gasdropAmount = gasdropRequested ? GAS_DROP : 0;

        vm.expectEmit(true, true, false, true);
        emit TokenBridgedIn(
            user,
            syn,
            data.amount,
            data.fee,
            syn,
            data.amount - data.fee,
            data.gasdropAmount,
            data.kappa
        );

        data.vaultPre = syn.balanceOf(address(vault));
        data.supplyPre = syn.totalSupply();

        data.userPre = syn.balanceOf(user);
        data.gasPre = user.balance;

        hoax(node);
        bridge.bridgeInEVM(user, syn, data.amount, data.swapParams, gasdropRequested, data.kappa);

        _checkPostBridgeIn(isMint, data);

        utils.checkRevert(
            node,
            address(bridge),
            abi.encodeWithSelector(
                bridge.bridgeInEVM.selector,
                user,
                syn,
                data.amount,
                data.swapParams,
                gasdropRequested,
                data.kappa
            ),
            "Kappa already exists"
        );
    }

    /**
     * @notice Does a valid bridge in transaction from non-EVM either via mint or withdraw.
     * Checks emitted event, user balance and token supply post-bridge tx.
     */
    function _checkBridgeInNonEVM(bool isMint) internal {
        _BridgeInTestData memory data;
        data.kappa = utils.getNextKappa();
        data.amount = (MIN_FEE * FEE_DENOMINATOR) / FEE;
        data.fee = 2 * MIN_FEE;
        data.gasdropAmount = GAS_DROP;

        vm.expectEmit(true, true, false, true);
        emit TokenBridgedIn(
            user,
            syn,
            data.amount,
            data.fee,
            syn,
            data.amount - data.fee,
            data.gasdropAmount,
            data.kappa
        );

        data.vaultPre = syn.balanceOf(address(vault));
        data.supplyPre = syn.totalSupply();

        data.userPre = syn.balanceOf(user);
        data.gasPre = user.balance;

        hoax(node);
        bridge.bridgeInNonEVM(user, CHAIN_ID_NON_EVM, SYN_NON_EVM, data.amount, data.kappa);

        _checkPostBridgeIn(isMint, data);

        utils.checkRevert(
            node,
            address(bridge),
            abi.encodeWithSelector(
                bridge.bridgeInNonEVM.selector,
                user,
                CHAIN_ID_NON_EVM,
                SYN_NON_EVM,
                data.amount,
                data.kappa
            ),
            "Kappa already exists"
        );
    }

    /**
     * @notice Checks invariants after bridging in:
     * 1. User should receive exact amount of tokens
     * 2. User should receive gas airdrop only when requested.
     * 3. Vault should accrue fees from bridging.
     * 4. (for minted token): token total supply should be increased by exactly amount+fee.
     * 5. (for withdrawn token): token total supply should stay the same.
     */
    function _checkPostBridgeIn(bool isMint, _BridgeInTestData memory data) internal {
        assertEq(syn.balanceOf(user), data.userPre + data.amount - data.fee, "Failed to credit tokens to user");
        assertEq(user.balance, data.gasPre + data.gasdropAmount, "Failed to credit gas drop to user");

        if (isMint) {
            assertEq(syn.balanceOf(address(vault)), data.vaultPre + data.fee, "Failed to accrue fee");
            assertEq(syn.totalSupply(), data.supplyPre + data.amount, "Failed to mint tokens");
        } else {
            assertEq(syn.balanceOf(address(vault)), data.vaultPre + data.fee - data.amount, "Failed to accrue fee");
            assertEq(syn.totalSupply(), data.supplyPre, "Unauthorized minting");
        }
    }

    /**
     * @notice Sets up SYN tokens for bridging.
     * Also enables gas airdrop and loads Vault with GAS.
     */
    function _setupBridgingIn(bool isMintBurn) internal {
        _setupBridging(isMintBurn);

        deal(address(vault), 1000 * GAS_DROP);
        hoax(governance);
        vault.setChainGasAmount(GAS_DROP);
    }

    /**
     * @notice Sets up SYN token for bridging.
     * Default fee scheme is used.
     */
    function _setupBridging(bool isMintBurn) internal {
        startHoax(governance);
        // 0.1% fee with 1 SYN min fee for bridge/airdrop/swap
        bridgeConfig.addNewToken(address(syn), address(syn), isMintBurn, FEE, MAX_UINT, MIN_FEE, MIN_FEE, MIN_FEE);

        uint256[] memory chainIdsEVM = new uint256[](2);
        chainIdsEVM[0] = block.chainid;
        chainIdsEVM[1] = CHAIN_ID_EVM;

        address[] memory bridgeTokensEVM = new address[](2);
        bridgeTokensEVM[0] = address(syn);
        bridgeTokensEVM[1] = SYN_EVM;

        bridgeConfig.addNewMap(chainIdsEVM, bridgeTokensEVM, CHAIN_ID_NON_EVM, SYN_NON_EVM);

        bridgeConfig.changeTokenStatus(address(syn), true);
        vm.stopPrank();
    }
}
