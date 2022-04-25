// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {FraxWrapper} from "contracts/bridge/wrappers/FraxWrapper.sol";
import {IFrax} from "contracts/bridge/interfaces/IFrax.sol";
import {IERC20} from "@openzeppelin/contracts-4.3.1/token/ERC20/IERC20.sol";

/**
 * Usage: forge test --match-path "test/bridge/wrappers/*" --fork-url https://moonriver.api.onfinality.io/public --fork-block-number 1730000
 */

interface IL2BridgeZap {
    function swapAndRedeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external;

    function swapAndRedeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 swapTokenIndexFrom,
        uint8 swapTokenIndexTo,
        uint256 swapMinDy,
        uint256 swapDeadline
    ) external;
}

interface IBridge {
    function mintAndSwap(
        address to,
        address token,
        uint256 amount,
        uint256 fee,
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bytes32 kappa
    ) external;
}

contract FraxWrapperTestMovr is Test {
    uint256 private constant SWAP_FEE = 4; // in bps
    uint256 private constant SWAP_DENOMINATOR = 10000;

    address private constant FRAX = 0x1A93B23281CC1CDE4C4741353F3064709A16197d;
    address private constant SYN_FRAX =
        0xE96AC70907ffF3Efee79f502C985A7A21Bce407d;

    address private constant WMOVR = 0x98878B06940aE243284CA214f92Bb71a2b032B8A;
    address private constant BRIDGE =
        0xaeD5b25BE1c3163c907a471082640450F928DDFE;

    address private constant NODE = 0x230A1AC45690B9Ae1176389434610B9526d2f21b;

    uint256 private constant TEST_AMOUNT = 10**20;
    uint256 private constant UINT_MAX = type(uint256).max;

    FraxWrapper public immutable pool;
    IL2BridgeZap public immutable zap;

    event TokenRedeem(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    );

    constructor() {
        pool = new FraxWrapper(FRAX, SYN_FRAX);
        zap = IL2BridgeZap(_deployZap());

        IERC20(FRAX).approve(address(pool), UINT_MAX);
        IERC20(SYN_FRAX).approve(address(pool), UINT_MAX);
    }

    function _deployZap() internal returns (address _zap) {
        address[] memory swaps = new address[](1);
        address[] memory tokens = new address[](1);
        swaps[0] = address(pool);
        tokens[0] = SYN_FRAX;

        _zap = deployCode(
            "L2BridgeZap.sol",
            abi.encode(WMOVR, swaps, tokens, BRIDGE)
        );
    }

    function setUp() public {
        deal(FRAX, address(this), TEST_AMOUNT);
        deal(SYN_FRAX, address(this), TEST_AMOUNT);
    }

    function testEdgeCases() public {
        uint256 balance = IERC20(SYN_FRAX).balanceOf(FRAX);
        uint256 tooMuch = _getAmountIn(balance);

        assertTrue(
            pool.calculateSwap(1, 0, tooMuch) > 0,
            "FRAX -> synFRAX (max amount) failed"
        );
        assertEq(
            pool.calculateSwap(1, 0, tooMuch + 1),
            0,
            "FRAX -> synFRAX (max amount + 1) not failed"
        );

        uint256 remainingCap = IFrax(FRAX).mint_cap() -
            IERC20(FRAX).totalSupply();
        tooMuch = _getAmountIn(remainingCap);

        assertTrue(
            pool.calculateSwap(0, 1, tooMuch) > 0,
            "synFRAX -> FRAX (max amount) failed"
        );
        assertEq(
            pool.calculateSwap(0, 1, tooMuch + 1),
            0,
            "synFRAX -> FRAX (max amount + 1) not failed"
        );
    }

    function testSwapFromFrax(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= TEST_AMOUNT);

        uint256 expected = amount - (amount * SWAP_FEE) / SWAP_DENOMINATOR;
        uint256 quote = pool.calculateSwap(1, 0, amount);
        assertEq(quote, expected, "Wrong quote");

        uint256 pre = IERC20(SYN_FRAX).balanceOf(address(this));
        uint256 received = pool.swap(1, 0, amount, 0, UINT_MAX);
        assertEq(
            IERC20(SYN_FRAX).balanceOf(address(this)),
            pre + received,
            "Returned wrong amount"
        );
        assertEq(received, quote, "Failed to give correct quote");
    }

    function testSwapFromSynFrax(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= TEST_AMOUNT);

        uint256 expected = amount - (amount * SWAP_FEE) / SWAP_DENOMINATOR;
        uint256 quote = pool.calculateSwap(0, 1, amount);
        assertEq(quote, expected, "Wrong quote");

        uint256 pre = IERC20(FRAX).balanceOf(address(this));
        uint256 received = pool.swap(0, 1, amount, 0, UINT_MAX);
        assertEq(
            IERC20(FRAX).balanceOf(address(this)),
            pre + received,
            "Returned wrong amount"
        );
        assertEq(received, quote, "Failed to give correct quote");
    }

    function testSwapAndRedeem(uint256 amountOut) public {
        vm.assume(amountOut <= TEST_AMOUNT);
        uint256 amount = _getAmountIn(amountOut);
        vm.assume(amount > 0);
        vm.assume(amount <= TEST_AMOUNT);

        IERC20(FRAX).approve(address(zap), amount);

        vm.expectEmit(true, false, false, true);
        emit TokenRedeem(address(this), 1, IERC20(SYN_FRAX), amountOut);

        zap.swapAndRedeem(
            address(this),
            1,
            IERC20(SYN_FRAX),
            1,
            0,
            amount,
            amountOut,
            UINT_MAX
        );
    }

    function testMintAndSwap(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= TEST_AMOUNT);
        uint256 amountOut = pool.calculateSwap(0, 1, amount);
        vm.assume(amountOut > 0);

        vm.startPrank(NODE);

        uint256 pre = IERC20(FRAX).balanceOf(address(this));

        bytes32 kappa = keccak256(bytes("much kappa very wow"));
        IBridge(BRIDGE).mintAndSwap(
            address(this),
            SYN_FRAX,
            amount,
            0,
            address(pool),
            0,
            1,
            amountOut,
            UINT_MAX,
            kappa
        );
        vm.stopPrank();

        assertTrue(
            IERC20(FRAX).balanceOf(address(this)) > pre,
            "No FRAX received"
        );
        assertEq(
            IERC20(FRAX).balanceOf(address(this)),
            pre + amountOut,
            "Wrong amount of FRAX received"
        );
    }

    function _getAmountIn(uint256 amountOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        amountIn =
            (amountOut * SWAP_DENOMINATOR) /
            (SWAP_DENOMINATOR - SWAP_FEE);
    }
}
