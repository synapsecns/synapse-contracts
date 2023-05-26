// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import "../../../contracts/bridge/wrappers/swap/MockSwap.sol";
import "../../../contracts/bridge/SynapseBridge.sol";
import "../../../contracts/bridge/SynapseERC20.sol";

//solhint-disable func-name-mixedcase
contract MockSwapTest is Test {
    MockSwap internal mockSwap;
    SynapseBridge internal bridge;
    SynapseERC20 internal token;

    address payable internal constant USER = address(123456);

    function setUp() public {
        mockSwap = new MockSwap();
        bridge = new SynapseBridge();
        bridge.initialize();
        bridge.grantRole(bridge.NODEGROUP_ROLE(), address(this));

        token = new SynapseERC20();
        token.initialize("TOKEN", "TOKEN", 18, address(this));
        token.grantRole(token.MINTER_ROLE(), address(bridge));
    }

    function test_calculateSwap(
        uint8 a,
        uint8 b,
        uint256 c
    ) public {
        assertEq(mockSwap.calculateSwap(a, b, c), 0);
    }

    function test_swap(
        uint8 a,
        uint8 b,
        uint256 c,
        uint256 d,
        uint256 e
    ) public {
        vm.expectRevert(bytes(""));
        mockSwap.swap(a, b, c, d, e);
    }

    function test_mintAndSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bytes32 kappa
    ) public {
        uint256 amount = 10**18;
        uint256 fee = 10**15;
        // Should work with any values for the fuzzed params
        bridge.mintAndSwap(
            USER,
            IERC20Mintable(address(token)),
            amount,
            fee,
            ISwap(address(mockSwap)),
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline,
            kappa
        );
        assertTrue(bridge.kappaExists(kappa), "!kappaExists");
        assertEq(bridge.getFeeBalance(address(token)), fee, "!fees");
        assertEq(token.balanceOf(USER), amount - fee, "!user balance");
    }
}
