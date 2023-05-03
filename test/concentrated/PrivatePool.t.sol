// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "../../contracts/concentrated/PrivatePool.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockAccessToken.sol";

contract PrivatePoolTest is Test {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public constant BRIDGE = address(0xB);
    address public constant OWNER = address(0xABCD);

    PrivatePool public pool;
    MockToken public token;
    MockAccessToken public synToken;

    event Quote(uint256 price);
    event NewSwapFee(uint256 newSwapFee);
    event TokenSwap(address indexed buyer, uint256 tokensSold, uint256 tokensBought, uint128 soldId, uint128 boughtId);
    event AddLiquidity(
        address indexed provider,
        uint256[] tokenAmounts,
        uint256[] fees,
        uint256 invariant,
        uint256 lpTokenSupply
    );
    event RemoveLiquidity(address indexed provider, uint256[] tokenAmounts, uint256 lpTokenSupply);

    function setUp() public {
        token = new MockToken("X", "X", 6);
        synToken = new MockAccessToken("synX", "synX", 6);
        synToken.grantRole(MINTER_ROLE, BRIDGE);

        pool = new PrivatePool(OWNER, address(synToken), address(token));
    }

    function testSetup() public {
        assertEq(token.symbol(), "X");
        assertEq(synToken.symbol(), "synX");
        assertEq(synToken.hasRole(MINTER_ROLE, BRIDGE), true);
    }

    function testConstructor() public {
        assertEq(pool.owner(), OWNER);
        assertEq(pool.factory(), address(this));
        assertEq(pool.token0(), address(synToken));
        assertEq(pool.token1(), address(token));
    }

    function testConstructorWhenToken0DecimalsGt18() public {
        address t = address(new MockToken("Y", "Y", 19));
        vm.expectRevert("token0 decimals > 18");
        new PrivatePool(OWNER, t, address(token));
    }

    function testConstructorWhenToken1DecimalsGt18() public {
        address t = address(new MockToken("Y", "Y", 19));
        vm.expectRevert("token1 decimals > 18");
        new PrivatePool(OWNER, address(token), t);
    }

    function testQuoteUpdatesPrice() public {
        uint256 price = 1e18; // 1 wad
        vm.prank(OWNER);
        pool.quote(price);
        assertEq(pool.P(), price);
    }

    function testQuoteEmitsQuoteEvent() public {
        uint256 price = 1e18; // 1 wad
        vm.expectEmit(false, false, false, true);
        emit Quote(price);

        vm.prank(OWNER);
        pool.quote(price);
    }

    function testQuoteWhenNotOwner() public {
        uint256 price = 1e18; // 1 wad
        vm.expectRevert("!owner");
        pool.quote(price);
    }

    function testQuoteWhenPriceSame() public {
        uint256 price = 1e18; // 1 wad
        vm.prank(OWNER);
        pool.quote(price);

        // try again
        vm.expectRevert("same price");
        vm.prank(OWNER);
        pool.quote(price);
    }

    function testQuoteWhenPriceGtMax() public {
        uint256 price = pool.PRICE_MAX() + 1;
        vm.expectRevert("price out of range");
        vm.prank(OWNER);
        pool.quote(price);
    }

    function testQuoteWhenPriceLtMax() public {
        uint256 price = pool.PRICE_MIN() - 1;
        vm.expectRevert("price out of range");
        vm.prank(OWNER);
        pool.quote(price);
    }

    function testSetSwapFeeUpdatesFee() public {
        uint256 fee = 0.0001e18; // 1bps in wad
        vm.prank(OWNER);
        pool.setSwapFee(fee);
        assertEq(pool.fee(), fee);
    }

    function testSetSwapFeeEmitsNewSwapFeeEvent() public {
        uint256 fee = 0.0001e18; // 1bps in wad
        vm.expectEmit(false, false, false, true);
        emit NewSwapFee(fee);

        vm.prank(OWNER);
        pool.setSwapFee(fee);
    }

    function testSetSwapFeeWhenNotOwner() public {
        uint256 fee = 0.0001e18; // 1bps in wad
        vm.expectRevert("!owner");
        pool.setSwapFee(fee);
    }

    function testSetSwapFeeWhenFeeGtMax() public {
        uint256 fee = pool.FEE_MAX() + 1;
        vm.expectRevert("fee > max");
        vm.prank(OWNER);
        pool.setSwapFee(fee);
    }
}
