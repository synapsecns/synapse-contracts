// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "../../contracts/concentrated/PrivatePool.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockAccessToken.sol";
import "../mocks/MockPrivatePool.sol";

contract PrivatePoolTest is Test {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public constant BRIDGE = address(0xB);
    address public constant OWNER = address(0xABCD);

    MockPrivatePool public pool;
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
        token.mint(address(this), 1e12);
        synToken.mint(address(this), 1e12);

        pool = new MockPrivatePool(OWNER, address(synToken), address(token));
    }

    function testSetup() public {
        assertEq(token.symbol(), "X");
        assertEq(synToken.symbol(), "synX");
        assertEq(synToken.hasRole(MINTER_ROLE, BRIDGE), true);
        assertEq(token.balanceOf(address(this)), 1e12);
        assertEq(synToken.balanceOf(address(this)), 1e12);
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

    function testGetTokenWhenIndex0() public {
        address token0 = address(pool.getToken(0));
        assertEq(pool.token0(), token0);
    }

    function testGetTokenWhenIndex1() public {
        address token1 = address(pool.getToken(1));
        assertEq(pool.token1(), token1);
    }

    function testGetTokenWhenNotIndex() public {
        vm.expectRevert("invalid token index");
        pool.getToken(2);
    }

    function testD() public {
        uint256 price = 1.0005e18; // 1 wad
        vm.prank(OWNER);
        pool.quote(price);

        uint256 amount = 100e6;
        token.transfer(address(pool), amount);
        synToken.transfer(address(pool), amount);

        uint256 d = 200.05e18;
        assertEq(pool.D(), d);
    }

    function testAmountWadWhenToken0() public {
        MockToken t = new MockToken("Y", "Y", 8);
        MockPrivatePool p = new MockPrivatePool(OWNER, address(t), address(token));

        uint256 dx = 100e8;
        uint256 amountWad = 100e18;
        assertEq(p.amountWad(dx, true), amountWad);
    }

    function testAmountWadWhenToken1() public {
        MockToken t = new MockToken("Y", "Y", 8);
        MockPrivatePool p = new MockPrivatePool(OWNER, address(t), address(token));

        uint256 dx = 100e6;
        uint256 amountWad = 100e18;
        assertEq(p.amountWad(dx, false), amountWad);
    }

    function testAmountDecimalsWhenToken0() public {
        MockToken t = new MockToken("Y", "Y", 8);
        MockPrivatePool p = new MockPrivatePool(OWNER, address(t), address(token));

        uint256 dx = 100e8;
        uint256 amount = 100e18;
        assertEq(p.amountDecimals(amount, true), dx);
    }

    function testAmountDecimalsWhenToken1() public {
        MockToken t = new MockToken("Y", "Y", 8);
        MockPrivatePool p = new MockPrivatePool(OWNER, address(t), address(token));

        uint256 dx = 100e6;
        uint256 amount = 100e18;
        assertEq(p.amountDecimals(amount, false), dx);
    }
}
