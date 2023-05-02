// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.8.0/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts-4.8.0/utils/math/Math.sol";

/// @title Private pool for concentrated liquidity
/// @notice Allows LP to offer fixed price quote in private pool to bridgers for tighter prices
/// @dev Obeys constant sum a * x + y = D curve, where a is fixed price and D is liquidity
/// @dev Functions use same signatures as Swap.sol for easier integration
contract PrivatePool {
    using SafeERC20 for IERC20;

    uint256 internal constant wad = 1e18;
    uint256 internal constant PRICE_BOUND = 0.001e18; // 10 bps in wad

    uint256 public constant PRICE_MIN = wad - PRICE_BOUND; // 1 - 10bps in wad
    uint256 public constant PRICE_MAX = wad + PRICE_BOUND; // 1 + 10bps in wad

    address public immutable factory;
    address public immutable owner;

    address public immutable token0; // base token
    address public immutable token1; // quote token

    uint256 internal immutable token0Decimals;
    uint256 internal immutable token1Decimals;

    uint256 public A; // fixed price param: amount of token1 per amount of token0 in wad
    uint256 public D; // liquidity param

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyToken(uint8 index) {
        require(index <= 1, "invalid token index");
        _;
    }

    constructor(
        address _owner,
        address _token0,
        address _token1
    ) {
        // TODO: check valid tokens at factory level
        factory = msg.sender;
        owner = _owner;
        token0 = _token0;
        token1 = _token1;

        // limit to tokens with decimals <= 18
        uint256 _token0Decimals = uint256(IERC20Metadata(_token0).decimals());
        require(_token0Decimals <= 18, "token0 decimals > 18");
        token0Decimals = _token0Decimals;

        uint256 _token1Decimals = uint256(IERC20Metadata(_token1).decimals());
        require(_token1Decimals <= 18, "token1 decimals > 18");
        token1Decimals = _token1Decimals;
    }

    /// @notice Amount of token in wad
    /// @param dx Amount of token in token decimals
    /// @param isToken0 Whether token is token0
    function amountWad(uint256 dx, bool isToken0) public view returns (uint256) {
        uint256 factor = isToken0 ? 10**(token0Decimals) : 10**(token1Decimals);
        return Math.mulDiv(dx, wad, factor);
    }

    /// @notice Amount of token in token decimals
    /// @param amount Amount of token in wad
    /// @param isToken0 Whether token is token0
    function amountDecimals(uint256 amount, bool isToken0) public view returns (uint256) {
        uint256 factor = isToken0 ? 10**(token0Decimals) : 10**(token1Decimals);
        return Math.mulDiv(amount, factor, wad);
    }

    // TODO: internal update D based on balances in the pool
    // TODO: will prevent manipulation of swap calcs via transfer of tokens in

    /// @notice Updates the quote price LP is willing to offer tokens at
    /// @param _A The new fixed price LP is willing to buy and sell at
    // TODO: time lock for changing?
    function quote(uint256 _A) external onlyOwner {
        require(_A >= PRICE_MIN && A <= PRICE_MAX, "A out of range");
        require(_A != A, "same A");

        // adjust D based on new price
        // @dev D' = D + (a' - a) * x
        uint256 xWad = amountWad(IERC20(token0).balanceOf(address(this)), true);
        uint256 prodAfter = Math.mulDiv(_A, xWad, wad);
        uint256 prodBefore = Math.mulDiv(A, xWad, wad);

        uint256 _D = D + prodAfter;
        require(_D >= prodBefore, "invalid D for A");

        D = _D - prodBefore;
        A = _A;
    }

    /// @notice Swaps token from for an amount of token to
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline // TODO: deadline
    ) external onlyToken(tokenIndexFrom) onlyToken(tokenIndexTo) returns (uint256) {
        require(tokenIndexFrom != tokenIndexTo, "invalid token swap");

        // get current token balances in pool
        uint256 xWad = amountWad(IERC20(token0).balanceOf(address(this)), true);
        uint256 yWad = amountWad(IERC20(token1).balanceOf(address(this)), false);

        // convert to an amount in wad
        uint256 amountInWad = amountWad(dx, tokenIndexFrom == 0);

        // calculate swap amount out wad
        // @dev obeys a * x + y = D
        uint256 amountOutWad;
        if (tokenIndexFrom == 0) {
            // token0 in for token1 out
            xWad += amountInWad;

            // check amount out won't exceed pool balance
            uint256 prod = Math.mulDiv(A, xWad, wad);
            require(D >= prod, "dy > pool balance");

            uint256 yWadAfter = D - prod;
            amountOutWad = yWad - yWadAfter;
        } else {
            // token1 in for token0 out
            yWad += amountInWad;

            // check amount out won't exceed pool balance
            require(D >= yWad, "dy > pool balance");

            uint256 xWadAfter = Math.mulDiv(D - yWad, wad, A);
            amountOutWad = xWad - xWadAfter;
        }

        // convert amount out to decimals
        uint256 dy = amountDecimals(amountOutWad, tokenIndexTo == 0);
        require(dy >= minDy, "dy < minDy");

        // transfer dx in and send dy out
        address tokenIn = tokenIndexFrom == 0 ? token0 : token1;
        address tokenOut = tokenIndexTo == 0 ? token0 : token1;
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), dx);
        IERC20(tokenOut).safeTransfer(msg.sender, dy);

        return dy;
    }

    /// @notice Adds liquidity to pool
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external onlyOwner returns (uint256) {
        require(amounts.length == 2, "invalid amounts");

        // get current token balances in pool
        uint256 xWad = amountWad(IERC20(token0).balanceOf(address(this)), true);
        uint256 yWad = amountWad(IERC20(token1).balanceOf(address(this)), false);

        // convert amounts to wad for calcs
        uint256 amount0Wad = amountWad(amounts[0], true);
        uint256 amount1Wad = amountWad(amounts[1], false);

        // balances after transfer
        xWad += amount0Wad;
        yWad += amount1Wad;

        // calc new D value
        uint256 _D = Math.mulDiv(xWad, A, wad) + yWad;
        uint256 d = _D - D;
        D = _D;

        // transfer amounts in decimals in
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amounts[0]);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amounts[1]);

        // return amount of added liquidity
        return d;
    }

    /// @notice Removes liquidity from pool
    function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external onlyOwner returns (uint256[] memory) {}
}
