// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "@openzeppelin/contracts-4.5.0/token/ERC20/ERC20.sol";

// solhint-disable func-name-mixedcase
interface IWKlayUnwrapper {
    function bridge() external view returns (address);

    function WKLAY() external view returns (address payable);

    function owner() external view returns (address);

    function rescueToken(address token) external;

    function withdraw(uint256 amount) external;
}

interface IWETH9 {
    function deposit() external payable;
}

contract WKlayUnwrapperTest is Test {
    uint256 public constant TEST_AMOUNT = 10**18;
    uint256 public constant MINT_AMOUNT = 10**20;
    address public constant GOV = address(1234);

    address public constant BRIDGE = 0xAf41a65F786339e7911F4acDAD6BD49426F2Dc6b;
    address payable public constant WKLAY = payable(0x5819b6af194A78511c79C85Ea68D2377a7e9335f);

    IWKlayUnwrapper internal unwrapper;
    ERC20 internal mockToken;

    function setUp() public {
        // Deploy ^0.4.18 contract, needs to be done via deployCode from 0.8.17 test
        address wklay = deployCode("WETH9.sol");
        // Deploy WETH to WKLAY address, so we don't need to fork anything
        vm.etch(WKLAY, wklay.code);
        // Deploy 0.6.12 contract, needs to be done via deployCode from 0.8.17 test
        // Constructor params are (bridge, governance)
        unwrapper = IWKlayUnwrapper(deployCode("WKlayUnwrapper.sol", abi.encode(BRIDGE, GOV)));
        // Mint some test WKLAY
        deal(address(this), MINT_AMOUNT);
        IWETH9(WKLAY).deposit{value: MINT_AMOUNT}();
        // Deploy a mock token
        mockToken = new ERC20("MOCK", "MOCK");
    }

    function test_setup() public {
        assertEq(unwrapper.bridge(), BRIDGE, "!bridge");
        assertEq(address(unwrapper.WKLAY()), WKLAY, "!WKLAY");
        assertEq(unwrapper.owner(), GOV, "!owner");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            TESTS: RESCUE                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_rescue_KLAY() public {
        uint256 balanceBefore = GOV.balance;
        // Deal excess KLAY to Unwrapper
        deal(address(unwrapper), TEST_AMOUNT);
        vm.prank(GOV);
        unwrapper.rescueToken(address(0));
        assertEq(GOV.balance, balanceBefore + TEST_AMOUNT);
    }

    function test_rescue_KLAY_revert_notGov(address caller) public {
        vm.assume(caller != GOV);
        // Deal excess KLAY to Unwrapper
        deal(address(unwrapper), TEST_AMOUNT);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        unwrapper.rescueToken(address(0));
    }

    function test_rescue_token() public {
        uint256 balanceBefore = mockToken.balanceOf(GOV);
        // Deal mock token to Unwrapper
        deal(address(mockToken), address(unwrapper), TEST_AMOUNT);
        vm.prank(GOV);
        unwrapper.rescueToken(address(mockToken));
        assertEq(mockToken.balanceOf(GOV), balanceBefore + TEST_AMOUNT);
    }

    function test_rescue_token_revert_notGov(address caller) public {
        vm.assume(caller != GOV);
        // Deal mock token to Unwrapper
        deal(address(mockToken), address(unwrapper), TEST_AMOUNT);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        unwrapper.rescueToken(address(mockToken));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           TESTS: WITHDRAW                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_withdraw() public {
        uint256 balanceBefore = BRIDGE.balance;
        ERC20(WKLAY).transfer(address(unwrapper), TEST_AMOUNT);
        vm.prank(BRIDGE);
        unwrapper.withdraw(TEST_AMOUNT);
        // Check that exact amount was transferred
        assertEq(BRIDGE.balance, balanceBefore + TEST_AMOUNT, "Failed to withdraw");
    }

    function test_withdraw_withExcessKLAY() public {
        // Deal excess KLAY to Unwrapper
        deal(address(unwrapper), TEST_AMOUNT);
        // withdrawing should work
        test_withdraw();
    }

    function test_withdraw_withExcessWKLAY() public {
        // Transfer excess WKLAY to Unwrapper
        ERC20(WKLAY).transfer(address(unwrapper), TEST_AMOUNT);
        // withdrawing should work
        test_withdraw();
    }

    function test_withdraw_revert_notBridge(address caller) public {
        vm.assume(caller != BRIDGE);
        ERC20(WKLAY).transfer(address(unwrapper), TEST_AMOUNT);
        vm.expectRevert("!bridge");
        vm.prank(caller);
        unwrapper.withdraw(TEST_AMOUNT);
    }
}
