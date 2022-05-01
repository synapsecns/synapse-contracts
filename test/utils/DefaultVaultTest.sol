// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "./Utilities.sol";

import {Bridge} from "src-vault/Bridge.sol";
import {BridgeConfig} from "src-vault/BridgeConfigV4.sol";

import {BridgeRouter} from "src-router/BridgeRouter.sol";
import {BridgeQuoter} from "src-router/BridgeQuoter.sol";

import {IVault} from "src-vault/interfaces/IVault.sol";

import {IERC20 as _IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

interface IERC20 is _IERC20 {
    function decimals() external view returns (uint8);
}

contract DefaultVaultTest is Test {
    struct TestSetup {
        bool needsUpgrade;
        address[2] tokens;
        address oldBridgeAddress;
        uint8 bridgeMaxSwaps;
        uint8 maxSwaps;
        uint256 maxGasForSwap;
        address payable wgas;
    }

    struct BridgeState {
        bytes32 nodeGroupRole;
        bytes32 governanceRole;
        uint256 startBlockNumber;
        uint256 chainGasAmount;
        address payable wethAddress;
        address[2] tokens;
        uint256[] fees;
    }

    // -- BRIDGE EVENTS OUT:

    event BridgedOutEVM(
        address indexed to,
        uint256 chainId,
        IERC20 tokenBridgedFrom,
        uint256 amount,
        IERC20 tokenBridgedTo,
        Bridge.SwapParams swapParams,
        bool gasdropRequested
    );

    event BridgedOutNonEVM(
        bytes32 indexed to,
        uint256 chainId,
        IERC20 tokenBridgedFrom,
        uint256 amount,
        string tokenBridgedTo
    );

    // -- BRIDGE EVENTS IN --

    event TokenBridgedIn(
        address indexed to,
        IERC20 tokenBridged,
        uint256 amountBridged,
        uint256 bridgeFee,
        IERC20 tokenReceived,
        uint256 amountReceived,
        uint256 gasdropAmount,
        bytes32 indexed kappa
    );

    TestSetup public defaultConfig =
        TestSetup({
            needsUpgrade: false,
            tokens: [address(0), address(0)],
            oldBridgeAddress: address(0),
            bridgeMaxSwaps: 2,
            maxSwaps: 4,
            maxGasForSwap: 10**6,
            wgas: payable(0)
        });

    Utilities internal immutable utils;

    Bridge public bridge;
    BridgeConfig public bridgeConfig;
    IVault public vault;

    BridgeRouter public router;
    BridgeQuoter public quoter;

    TestSetup private _config;
    BridgeState private _state;

    address[] public allTokens;

    address payable public immutable attacker;
    address payable public immutable user;
    address payable public immutable governance;
    address payable public immutable node;
    address payable public immutable dude;

    uint256 public constant TEST_AMOUNT = 133742069;
    uint256 public constant MAX_UINT = type(uint256).max;

    constructor(TestSetup memory config) {
        utils = new Utilities();
        _config = config;

        address payable[] memory users = utils.createUsers(10);
        attacker = users[0];
        user = users[1];
        governance = users[2];
        node = users[3];
        dude = users[4];

        vm.label(attacker, "attacker");
        vm.label(user, "user");
        vm.label(governance, "gov");
        vm.label(node, "node");
        vm.label(dude, "dude");

        vm.label(address(utils), "Utils");
    }

    function setUp() public virtual {
        _setupVault();
        _setupBridge();
        _setupRouter();
    }

    function _setupVault() private {
        // Deploy Vault and change old Bridge implementation to Vault
        address _vault = deployCode("./artifacts/Vault.sol/Vault.json");
        if (_config.needsUpgrade) {
            _saveState();
            utils.upgradeTo(_config.oldBridgeAddress, _vault);
            vault = IVault(_config.oldBridgeAddress);
            vm.label(_vault, "Vault impl");
        } else {
            vault = IVault(_vault);
            vault.initialize();
        }
        vm.label(address(vault), "Vault");

        hoax(utils.getRoleMember(address(vault), 0x00));
        IAccessControl(address(vault)).grantRole(
            vault.GOVERNANCE_ROLE(),
            governance
        );
    }

    function _setupBridge() private {
        bridgeConfig = new BridgeConfig();
        bridge = new Bridge();
        vm.label(address(bridge), "Bridge");
        vm.label(address(bridgeConfig), "BridgeConfig");

        bridgeConfig.initialize();
        bridge.initialize(vault, bridgeConfig, _config.maxGasForSwap);

        bridgeConfig.grantRole(bridgeConfig.GOVERNANCE_ROLE(), governance);
        bridgeConfig.grantRole(bridgeConfig.NODEGROUP_ROLE(), node);

        bridge.grantRole(bridge.GOVERNANCE_ROLE(), governance);
        bridge.grantRole(bridge.NODEGROUP_ROLE(), node);

        hoax(utils.getRoleMember(address(vault), 0x00));
        IAccessControl(address(vault)).grantRole(
            vault.BRIDGE_ROLE(),
            address(bridge)
        );
    }

    function _setupRouter() private {
        router = new BridgeRouter(
            _config.wgas,
            address(bridge),
            _config.bridgeMaxSwaps
        );
        quoter = new BridgeQuoter(payable(router), _config.maxSwaps);
        vm.label(address(router), "Router");
        vm.label(address(quoter), "Quoter");

        router.grantRole(router.ADAPTERS_STORAGE_ROLE(), address(quoter));
        router.grantRole(router.GOVERNANCE_ROLE(), governance);

        quoter.transferOwnership(governance);

        hoax(governance);
        bridge.setRouter(router);
    }

    function _deployERC20(string memory name) internal returns (IERC20 token) {
        token = IERC20(
            deployCode(
                "./artifacts/ERC20Mock.sol/ERC20Mock.json",
                abi.encode(name, name, 0)
            )
        );
        vm.label(address(token), name);
        allTokens.push(address(token));
    }

    function _deployERC20Decimals(string memory name, uint8 decimals)
        internal
        returns (IERC20 token)
    {
        token = IERC20(
            deployCode(
                "./artifacts/ERC20MockDecimals.sol/ERC20MockDecimals.json",
                abi.encode(name, name, 0, decimals)
            )
        );
        vm.label(address(token), name);
        allTokens.push(address(token));
    }

    function _deployWETH(string memory name) internal returns (IERC20 token) {
        token = IERC20(deployCode("./artifacts/WETH9.sol/WETH9.json"));
        vm.label(address(token), name);
        allTokens.push(address(token));
    }

    function _saveState() internal {
        uint256[] memory fees = new uint256[](_config.tokens.length);
        for (uint256 i = 0; i < fees.length; i++) {
            fees[i] = vault.getFeeBalance(IERC20(_config.tokens[i]));
        }

        _state = BridgeState({
            nodeGroupRole: vault.NODEGROUP_ROLE(),
            governanceRole: vault.GOVERNANCE_ROLE(),
            startBlockNumber: vault.startBlockNumber(),
            chainGasAmount: vault.chainGasAmount(),
            wethAddress: vault.WETH_ADDRESS(),
            tokens: _config.tokens,
            fees: fees
        });
    }

    function _testUpgrade(bytes32[] memory kappas) internal {
        for (uint256 i = 0; i < kappas.length; ++i) {
            assertTrue(
                vault.kappaExists(kappas[i]),
                "Kappa is missing post-upgrade"
            );
        }

        assertEq(
            _state.nodeGroupRole,
            vault.NODEGROUP_ROLE(),
            "NODEGROUP_ROLE rekt post-upgrade"
        );
        assertEq(
            _state.governanceRole,
            vault.GOVERNANCE_ROLE(),
            "GOVERNANCE_ROLE rekt post-upgrade"
        );
        assertEq(
            _state.startBlockNumber,
            vault.startBlockNumber(),
            "startBlockNumber rekt post-upgrade"
        );
        assertEq(
            _state.chainGasAmount,
            vault.chainGasAmount(),
            "chainGasAmount rekt post-upgrade"
        );
        assertEq(
            _state.wethAddress,
            vault.WETH_ADDRESS(),
            "WETH_ADDRESS rekt post-upgrade"
        );

        uint256 length = _state.tokens.length;
        for (uint256 i = 0; i < length; ++i) {
            assertEq(
                _state.fees[i],
                vault.getFeeBalance(IERC20(_state.tokens[i])),
                "fees rekt post-upgrade"
            );
        }

        assertEq(vault.bridgeVersion(), 7, "Bridge not upgraded");
    }
}
