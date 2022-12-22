// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "../../utils/Utilities.sol";

import "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

// solhint-disable func-name-mixedcase
interface IBridge {
    function setWethAddress(address payable wethAddress) external;

    function withdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function startBlockNumber() external view returns (uint256);

    function bridgeVersion() external view returns (uint256);

    function chainGasAmount() external view returns (uint256);

    function WETH_ADDRESS() external view returns (address payable);

    function getFeeBalance(address tokenAddress) external view returns (uint256);

    function kappaExists(bytes32 kappa) external view returns (bool);
}

interface IWKlayUnwrapper {
    function BRIDGE() external view returns (address);

    function WKLAY() external view returns (address payable);

    function owner() external view returns (address);

    function rescueToken(address token) external;

    function withdraw(uint256 amount) external;
}

contract KlaytnSynapseBridgeTestFork is Test {
    // 2022-11-25
    uint256 public constant TEST_BLOCK_NUMBER = 107_500_000;
    uint256 public constant AMOUNT = 10**18;
    uint256 public constant FEE = 10**15;

    address public constant NODE = 0x230A1AC45690B9Ae1176389434610B9526d2f21b;
    address public constant GOV = address(0x8f17B483982d1CC09296Aed8F1b09Ad830358A8D);
    IBridge public constant BRIDGE = IBridge(0xAf41a65F786339e7911F4acDAD6BD49426F2Dc6b);
    address payable public constant WKLAY = payable(0x5819b6af194A78511c79C85Ea68D2377a7e9335f);

    bytes32[4] public existingKappas = [
        bytes32(0x2fb36af5ec5698655e98815a16c35385e42e1eb7dbc43df7004f49987ed87a3d),
        0x7de91ea5a31867c1f6cfb949185d1dce9b8b963a3121b490ce791b94abcdd8c4,
        0x9666337d7f34fe5c73ff411a08f9f1f80c10bed99ce90696c895f13317f4d5c0,
        0x905286e4807a3300b754f50dcf960e47671afeb0c07f95514e406d930aec91ae
    ];

    Utilities internal utils;
    IWKlayUnwrapper internal unwrapper;
    address internal bridgeImpl;

    event TokenWithdraw(address indexed to, IERC20 token, uint256 amount, uint256 fee, bytes32 indexed kappa);

    function setUp() public {
        string memory cantoRPC = vm.envString("KLAY_API");
        // Fork Klaytn for Bridge tests
        vm.createSelectFork(cantoRPC, TEST_BLOCK_NUMBER);
        utils = new Utilities();
        // Deploy 0.6.12 contracts, needs to be done via deployCode from 0.8.17 test
        unwrapper = IWKlayUnwrapper(deployCode("WKlayUnwrapper.sol", abi.encode(GOV)));
        bridgeImpl = deployCode("KlaytnSynapseBridge.sol", abi.encode(unwrapper));
    }

    function test_upgradedCorrectly() public {
        uint256 startBlockNumber = BRIDGE.startBlockNumber();
        uint256 bridgeVersion = BRIDGE.bridgeVersion();
        uint256 chainGasAmount = BRIDGE.chainGasAmount();
        address payable wethAddress = BRIDGE.WETH_ADDRESS();
        uint256 wklayFees = BRIDGE.getFeeBalance(WKLAY);
        for (uint256 i = 0; i < existingKappas.length; ++i) {
            assertTrue(BRIDGE.kappaExists(existingKappas[i]), "!kappa: before upgrade");
        }
        upgradeBridge();
        assertEq(BRIDGE.startBlockNumber(), startBlockNumber, "!startBlockNumber");
        assertEq(BRIDGE.bridgeVersion(), bridgeVersion + 1, "!bridgeVersion");
        assertEq(BRIDGE.chainGasAmount(), chainGasAmount, "!chainGasAmount");
        assertEq(BRIDGE.WETH_ADDRESS(), wethAddress, "!wethAddress");
        assertEq(BRIDGE.getFeeBalance(WKLAY), wklayFees, "!wklayFees");
        for (uint256 i = 0; i < existingKappas.length; ++i) {
            assertTrue(BRIDGE.kappaExists(existingKappas[i]), "!kappa: after upgrade");
        }
    }

    function test_withdraw() public {
        upgradeBridge();
        // Set WKLAY address on Bridge
        vm.prank(GOV);
        BRIDGE.setWethAddress(WKLAY);
        bytes32 kappa = "test kappa";
        address user = address(1337);
        uint256 wklayBalance = IERC20(WKLAY).balanceOf(address(BRIDGE));
        uint256 wklayFees = BRIDGE.getFeeBalance(WKLAY);
        uint256 receivedAmount = AMOUNT - FEE;
        // Event should be emitted
        vm.expectEmit(true, true, true, true, address(BRIDGE));
        emit TokenWithdraw(user, IERC20(WKLAY), AMOUNT, FEE, kappa);
        // Initiate bridge transaction
        vm.prank(NODE);
        BRIDGE.withdraw(user, IERC20(WKLAY), AMOUNT, FEE, kappa);
        // Checks
        assertEq(user.balance, receivedAmount, "User hasn't received KLAY");
        assertEq(
            IERC20(WKLAY).balanceOf(address(BRIDGE)),
            wklayBalance - receivedAmount,
            "Bridge hasn't unwrapped WKLAY"
        );
        assertEq(BRIDGE.getFeeBalance(WKLAY), wklayFees + FEE, "Bridge fee not collected");
        assertTrue(BRIDGE.kappaExists(kappa), "Kappa not saved");
    }

    function upgradeBridge() public {
        utils.upgradeTo(address(BRIDGE), bridgeImpl);
    }
}
