// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "../../contracts/concentrated/PrivatePool.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockAccessToken.sol";
import "../mocks/MockTokenWithFee.sol";
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
    event RemoveLiquidity(
        address indexed provider,
        uint256[] tokenAmounts,
        uint256[] fees,
        uint256 invariant,
        uint256 lpTokenSupply
    );

    function setUp() public {
        token = new MockToken("X", "X", 6);
        synToken = new MockAccessToken("synX", "synX", 6);

        synToken.grantRole(MINTER_ROLE, BRIDGE);

        token.mint(OWNER, 1e12);
        synToken.mint(OWNER, 1e12);

        pool = new MockPrivatePool(OWNER, address(synToken), address(token));

        vm.prank(OWNER);
        token.approve(address(pool), type(uint256).max);

        vm.prank(OWNER);
        synToken.approve(address(pool), type(uint256).max);
    }

    function testSetup() public {
        assertEq(token.symbol(), "X");
        assertEq(synToken.symbol(), "synX");
        assertEq(synToken.hasRole(MINTER_ROLE, BRIDGE), true);
        assertEq(token.balanceOf(OWNER), 1e12);
        assertEq(synToken.balanceOf(OWNER), 1e12);
        assertEq(token.allowance(OWNER, address(pool)), type(uint256).max);
        assertEq(synToken.allowance(OWNER, address(pool)), type(uint256).max);
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

    function testAddLiquidityTransfersFunds() public {
        // set up
        uint256 minToMint = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // add liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e6;
        amounts[1] = 100.05e6;

        vm.prank(OWNER);
        pool.addLiquidity(amounts, minToMint, deadline);

        assertEq(synToken.balanceOf(address(pool)), amounts[0]);
        assertEq(token.balanceOf(address(pool)), amounts[1]);
    }

    function testAddLiquidityChangesD() public {
        // set up
        uint256 minToMint = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amount = 100e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amount);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amount);

        uint256 d = 200.05e18;
        assertEq(pool.D(), d);

        // add liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e6;
        amounts[1] = 100.05e6;

        vm.prank(OWNER);
        pool.addLiquidity(amounts, minToMint, deadline);

        d += 200.1e18; // in wad
        assertEq(pool.D(), d);
    }

    function testAddLiquidityReturnsMinted() public {
        // set up
        uint256 minToMint = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amount = 100e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amount);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amount);

        uint256 d = 200.05e18;
        assertEq(pool.D(), d);

        // add liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e6;
        amounts[1] = 100.05e6;
        uint256 minted = 200.1e18; // in wad

        vm.prank(OWNER);
        assertEq(pool.addLiquidity(amounts, minToMint, deadline), minted);
    }

    function testAddLiquidityEmitsAddLiquidityEvent() public {
        // set up
        uint256 minToMint = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amount = 100e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amount);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amount);

        uint256 d = 200.05e18;
        assertEq(pool.D(), d);

        // add liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e6;
        amounts[1] = 100.05e6;
        d += 200.1e18; // in wad

        uint256[] memory fees = new uint256[](2);
        fees[0] = 0;
        fees[1] = 0;

        vm.expectEmit(true, false, false, true);
        emit AddLiquidity(OWNER, amounts, fees, d, d);

        vm.prank(OWNER);
        pool.addLiquidity(amounts, minToMint, deadline);
    }

    function testAddLiquidityWhenNotOwner() public {
        // set up
        uint256 minToMint = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // add liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e6;
        amounts[1] = 100.05e6;

        vm.expectRevert("!owner");
        pool.addLiquidity(amounts, minToMint, deadline);
    }

    function testAddLiquidityWhenAmountsLenNot2() public {
        // set up
        uint256 minToMint = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // add liquidity
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100e6;
        amounts[1] = 100.05e6;
        amounts[2] = 100.10e6;

        vm.expectRevert("invalid amounts");
        vm.prank(OWNER);
        pool.addLiquidity(amounts, minToMint, deadline);
    }

    function testAddLiquidityWhenPastDeadline() public {
        // set up
        uint256 minToMint = 0;
        uint256 deadline = block.timestamp - 1;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // add liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e6;
        amounts[1] = 100.05e6;

        vm.expectRevert("block.timestamp > deadline");
        vm.prank(OWNER);
        pool.addLiquidity(amounts, minToMint, deadline);
    }

    function testAddLiquidityWhenNotHasQuote() public {
        // set up
        uint256 minToMint = 0;
        uint256 deadline = block.timestamp + 3600;

        // add liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e6;
        amounts[1] = 100.05e6;

        vm.expectRevert("invalid quote");
        vm.prank(OWNER);
        pool.addLiquidity(amounts, minToMint, deadline);
    }

    function testAddLiquidityWhenMintedLtMin() public {
        // set up
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amount = 100e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amount);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amount);

        uint256 d = 200.05e18;
        assertEq(pool.D(), d);

        // add liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e6;
        amounts[1] = 100.05e6;
        uint256 minted = 200.1e18; // in wad

        uint256 minToMint = minted + 1;
        vm.expectRevert("minted < min");
        vm.prank(OWNER);
        pool.addLiquidity(amounts, minToMint, deadline);
    }

    function testRemoveLiquidityTransfersFunds() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(address(pool)), amountToken);
        assertEq(synToken.balanceOf(address(pool)), amountSynToken);
        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountSynToken / 4;
        amounts[1] = amountToken / 4;

        vm.prank(OWNER);
        pool.removeLiquidity(amounts, minToBurn, deadline);

        // check pool balances decreased by d / 4
        assertEq(token.balanceOf(address(pool)), amountToken - amountToken / 4);
        assertEq(synToken.balanceOf(address(pool)), amountSynToken - amountSynToken / 4);

        // check balances of owner increased by d/4
        assertEq(token.balanceOf(OWNER), 1e12 - (3 * amountToken) / 4);
        assertEq(synToken.balanceOf(OWNER), 1e12 - (3 * amountSynToken) / 4);
    }

    function testRemoveLiquidityChangesD() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountSynToken / 4;
        amounts[1] = amountToken / 4;

        vm.prank(OWNER);
        pool.removeLiquidity(amounts, minToBurn, deadline);

        // check D updated
        d -= d / 4; // in wad
        assertEq(pool.D(), d);
    }

    function testRemoveLiquidityReturnsBurned() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountSynToken / 4;
        amounts[1] = amountToken / 4;
        uint256 burned = d / 4;

        vm.prank(OWNER);
        assertEq(pool.removeLiquidity(amounts, minToBurn, deadline), burned);
    }

    function testRemoveLiquidityEmitsRemoveLiquidityEvent() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountSynToken / 4;
        amounts[1] = amountToken / 4;

        uint256[] memory fees = new uint256[](2);

        vm.expectEmit(true, false, false, true);
        emit RemoveLiquidity(OWNER, amounts, fees, d - d / 4, d - d / 4);

        vm.prank(OWNER);
        pool.removeLiquidity(amounts, minToBurn, deadline);
    }

    function testRemoveLiquidityWhenNotOwner() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountSynToken / 4;
        amounts[1] = amountToken / 4;

        vm.expectRevert("!owner");
        pool.removeLiquidity(amounts, minToBurn, deadline);
    }

    function testRemoveLiquidityWhenAmountsNotLen2() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = amountSynToken / 4;
        amounts[1] = amountToken / 4;

        vm.expectRevert("invalid amounts");
        vm.prank(OWNER);
        pool.removeLiquidity(amounts, minToBurn, deadline);
    }

    function testRemoveLiquidityWhenAmount0GtBalance() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountSynToken + 1;
        amounts[1] = amountToken / 4;

        vm.expectRevert("dx > max");
        vm.prank(OWNER);
        pool.removeLiquidity(amounts, minToBurn, deadline);
    }

    function testRemoveLiquidityWhenAmount1GtBalance() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountSynToken / 4;
        amounts[1] = amountToken + 1;

        vm.expectRevert("dy > max");
        vm.prank(OWNER);
        pool.removeLiquidity(amounts, minToBurn, deadline);
    }

    function testRemoveLiquidityWhenPastDeadline() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp - 1;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountSynToken / 4;
        amounts[1] = amountToken + 1;

        vm.expectRevert("block.timestamp > deadline");
        vm.prank(OWNER);
        pool.removeLiquidity(amounts, minToBurn, deadline);
    }

    function testRemoveLiquidityWhenBurnedLtMinToBurn() public {
        // set up
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountSynToken / 4;
        amounts[1] = amountToken / 4;

        uint256 minToBurn = d / 4 + 1;
        vm.expectRevert("burned < min");
        vm.prank(OWNER);
        pool.removeLiquidity(amounts, minToBurn, deadline);
    }

    function testRemoveLiquidityWhenOnlyAmount0() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountSynToken / 4;
        amounts[1] = 0;

        vm.prank(OWNER);
        pool.removeLiquidity(amounts, minToBurn, deadline);

        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken + amountSynToken / 4);
        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
    }

    function testRemoveLiquidityWhenOnlyAmount1() public {
        // set up
        uint256 minToBurn = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // remove 25% of the liquidity
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = amountToken / 4;

        vm.prank(OWNER);
        pool.removeLiquidity(amounts, minToBurn, deadline);

        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);
        assertEq(token.balanceOf(OWNER), 1e12 - amountToken + amountToken / 4);
    }

    function testCalculateSwapWhenFrom0To1() public {
        // set up
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        uint256 dx = 50e6;
        uint256 dy = 50022498; // int(P * X * (1 - fee))
        assertEq(pool.calculateSwap(0, 1, dx), dy);
    }

    function testCalculateSwapWhenFrom1To0() public {
        // set up
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        uint256 dx = 50e6;
        uint256 dy = 49972513; // int((Y / P) * (1 - fee))
        assertEq(pool.calculateSwap(1, 0, dx), dy);
    }

    function testCalculateSwapWhenFromNotTokenIndex() public {
        // set up
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        uint256 dx = 50e6;
        uint256 dy = 0;
        assertEq(pool.calculateSwap(2, 0, dx), dy);
    }

    function testCalculateSwapWhenToNotTokenIndex() public {
        // set up
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        uint256 dx = 50e6;
        uint256 dy = 0;
        assertEq(pool.calculateSwap(1, 2, dx), dy);
    }

    function testCalculateSwapWhenFromEqualsTo() public {
        // set up
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        uint256 dx = 50e6;
        uint256 dy = 0;
        assertEq(pool.calculateSwap(1, 1, dx), dy);
    }

    function testCalculateSwapWhenFrom0To1AndDyGtBalance() public {
        // set up
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        uint256 dx = 100e6 + 1;
        uint256 dy = 0;
        assertEq(pool.calculateSwap(0, 1, dx), dy);
    }

    function testCalculateSwapWhenFrom1To0AndDyGtBalance() public {
        // set up
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        uint256 dx = 100.05e6 + 1;
        uint256 dy = 0;
        assertEq(pool.calculateSwap(1, 0, dx), dy);
    }

    function testSwapTransfersFundsWhenFrom0To1() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        uint256 dy = 50022498; // int(P * X * (1 - fee))
        synToken.approve(address(pool), type(uint256).max);
        pool.swap(0, 1, dx, minDy, deadline);

        assertEq(synToken.balanceOf(sender), bal - dx);
        assertEq(synToken.balanceOf(address(pool)), amountSynToken + dx);

        assertEq(token.balanceOf(sender), bal + dy);
        assertEq(token.balanceOf(address(pool)), amountToken - dy);
    }

    function testSwapTransfersFundsWhenFrom1To0() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        uint256 dy = 49972513; // int((Y / P) * (1 - fee))
        token.approve(address(pool), type(uint256).max);
        pool.swap(1, 0, dx, minDy, deadline);

        assertEq(token.balanceOf(sender), bal - dx);
        assertEq(token.balanceOf(address(pool)), amountToken + dx);

        assertEq(synToken.balanceOf(sender), bal + dy);
        assertEq(synToken.balanceOf(address(pool)), amountSynToken - dy);
    }

    function testSwapEmitsTokenSwapEventWhenFrom0To1() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        uint256 dy = 50022498; // int(P * X * (1 - fee))
        synToken.approve(address(pool), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit TokenSwap(sender, dx, dy, 0, 1);
        pool.swap(0, 1, dx, minDy, deadline);
    }

    function testSwapEmitsTokenSwapEventWhenFrom1To0() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        uint256 dy = 49972513; // int((Y / P) * (1 - fee))
        token.approve(address(pool), type(uint256).max);

        vm.expectEmit(true, false, false, true);
        emit TokenSwap(sender, dx, dy, 1, 0);
        pool.swap(1, 0, dx, minDy, deadline);
    }

    function testSwapWhenTokenInHasFees() public {
        // set up
        MockTokenWithFee t = new MockTokenWithFee("USDT", "USDT", 6, 0.001e18);
        MockAccessToken synT = new MockAccessToken("synUSDT", "synUSDT", 6);
        MockPrivatePool p = new MockPrivatePool(OWNER, address(synT), address(t));

        t.mint(OWNER, 1e12);
        synT.mint(OWNER, 1e12);

        vm.prank(OWNER);
        t.approve(address(p), type(uint256).max);

        vm.prank(OWNER);
        synT.approve(address(p), type(uint256).max);

        // more set up
        vm.prank(OWNER);
        p.quote(1.0005e18);

        vm.prank(OWNER);
        p.setSwapFee(0.00005e18);

        // transfer in tokens prior
        uint256 amountSynT = 100e6;
        uint256 amountT = 100.15015e6;
        vm.prank(OWNER);
        t.transfer(address(p), amountT);
        vm.prank(OWNER);
        synT.transfer(address(p), amountSynT);

        assertEq(t.balanceOf(OWNER), 1e12 - amountT);
        assertEq(synT.balanceOf(OWNER), 1e12 - amountSynT);
        assertEq(t.balanceOf(address(this)), amountT - 100.05e6); // owner of t

        uint256 d = 200.10e18;
        assertEq(p.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synT.transfer(sender, bal);
        vm.prank(OWNER);
        t.transfer(sender, bal);

        uint256 dx = 50e6;
        uint256 dy = 49922541; // int((Y *(1-transferFee) / P) * (1 - fee))
        t.approve(address(p), type(uint256).max);
        assertEq(p.swap(1, 0, dx, 0, block.timestamp + 3600), dy);
    }

    function testSwapWhenPastDeadline() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp - 1;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        token.approve(address(pool), type(uint256).max);

        vm.expectRevert("block.timestamp > deadline");
        pool.swap(1, 0, dx, minDy, deadline);
    }

    function testSwapWhenNotHasQuote() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp + 3600;

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        token.approve(address(pool), type(uint256).max);

        vm.expectRevert("invalid quote");
        pool.swap(1, 0, dx, minDy, deadline);
    }

    function testSwapWhenFromInvalidIndex() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        token.approve(address(pool), type(uint256).max);

        vm.expectRevert("invalid token index");
        pool.swap(2, 0, dx, minDy, deadline);
    }

    function testSwapWhenToInvalidIndex() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        token.approve(address(pool), type(uint256).max);

        vm.expectRevert("invalid token index");
        pool.swap(1, 2, dx, minDy, deadline);
    }

    function testSwapWhenSameTokenIndex() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        token.approve(address(pool), type(uint256).max);

        vm.expectRevert("invalid token swap");
        pool.swap(1, 1, dx, minDy, deadline);
    }

    function testSwapWhenFrom0To1GtBalance() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 101e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 100e6 + 1;
        synToken.approve(address(pool), type(uint256).max);
        vm.expectRevert("dy > pool balance");
        pool.swap(0, 1, dx, minDy, deadline);
    }

    function testSwapWhenFrom1To0GtBalance() public {
        // set up
        uint256 minDy = 0;
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        uint256 amountSynToken = 100e6;
        uint256 amountToken = 100.05e6;
        vm.prank(OWNER);
        token.transfer(address(pool), amountToken);
        vm.prank(OWNER);
        synToken.transfer(address(pool), amountSynToken);

        assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
        assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 101e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 100.05e6 + 1;
        token.approve(address(pool), type(uint256).max);
        vm.expectRevert("dy > pool balance");
        pool.swap(1, 0, dx, minDy, deadline);
    }

    function testSwapWhenFrom0To1DyLtMin() public {
        // set up
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        {
            uint256 amountSynToken = 100e6;
            uint256 amountToken = 100.05e6;
            vm.prank(OWNER);
            token.transfer(address(pool), amountToken);
            vm.prank(OWNER);
            synToken.transfer(address(pool), amountSynToken);

            assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
            assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);
        }

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        uint256 dy = 50022498; // int(P * X * (1 - fee))
        uint256 minDy = dy + 1;
        synToken.approve(address(pool), type(uint256).max);
        vm.expectRevert("dy < minDy");
        pool.swap(0, 1, dx, minDy, deadline);
    }

    function testSwapWhenFrom1To0DyLtMin() public {
        // set up
        uint256 deadline = block.timestamp + 3600;
        uint256 price = 1.0005e18;
        vm.prank(OWNER);
        pool.quote(price);

        uint256 fee = 0.00005e18;
        vm.prank(OWNER);
        pool.setSwapFee(fee);

        // transfer in tokens prior
        {
            uint256 amountSynToken = 100e6;
            uint256 amountToken = 100.05e6;
            vm.prank(OWNER);
            token.transfer(address(pool), amountToken);
            vm.prank(OWNER);
            synToken.transfer(address(pool), amountSynToken);

            assertEq(token.balanceOf(OWNER), 1e12 - amountToken);
            assertEq(synToken.balanceOf(OWNER), 1e12 - amountSynToken);
        }

        uint256 d = 200.10e18;
        assertEq(pool.D(), d);

        // transfer funds from owner to this account
        uint256 bal = 100e6;
        address sender = address(this);
        vm.prank(OWNER);
        synToken.transfer(sender, bal);
        vm.prank(OWNER);
        token.transfer(sender, bal);

        assertEq(token.balanceOf(sender), bal);
        assertEq(synToken.balanceOf(sender), bal);

        uint256 dx = 50e6;
        uint256 dy = 49972513; // int((Y / P) * (1 - fee))
        uint256 minDy = dy + 1;
        token.approve(address(pool), type(uint256).max);
        vm.expectRevert("dy < minDy");
        pool.swap(1, 0, dx, minDy, deadline);
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
        vm.prank(OWNER);
        token.transfer(address(pool), amount);

        vm.prank(OWNER);
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
