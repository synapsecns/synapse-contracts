// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.8.0/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts-4.8.0/utils/math/Math.sol";

/// @title Private pool for concentrated liquidity
/// @notice Allows LP to offer fixed price quote in private pool to bridgers for tighter prices
/// @dev Obeys constant sum P * x + y = D curve, where P is fixed price and D is liquidity
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

    uint256 public P; // fixed price param: amount of token1 per amount of token0 in wad

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyToken(uint8 index) {
        require(index <= 1, "invalid token index");
        _;
    }

    event Quote(uint256 price);
    event TokenSwap(address indexed buyer, uint256 tokensSold, uint256 tokensBought, uint128 soldId, uint128 boughtId);
    event AddLiquidity(
        address indexed provider,
        uint256[] tokenAmounts,
        uint256[] fees,
        uint256 invariant,
        uint256 lpTokenSupply
    );
    event RemoveLiquidity(address indexed provider, uint256[] tokenAmounts, uint256 lpTokenSupply);

    constructor(
        address _owner,
        address _token0,
        address _token1
    ) {
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

    /// @notice Updates the quote price LP is willing to offer tokens at
    /// @param _P The new fixed price LP is willing to buy and sell at
    function quote(uint256 _P) external onlyOwner {
        require(_P >= PRICE_MIN && _P <= PRICE_MAX, "price out of range");
        require(_P != P, "same price");

        // set new P price param
        P = _P;
    }

    /// @notice Adds liquidity to pool
    /// @param amounts The token amounts to add in token decimals
    /// @param minToMint The minimum amount of liquidity to be minted
    /// @param deadline The deadline before which liquidity must be added
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external onlyOwner returns (uint256 minted_) {
        require(amounts.length == 2, "invalid amounts");

        // get current token balances in pool
        uint256 xWad = _amountWad(IERC20(token0).balanceOf(address(this)), true);
        uint256 yWad = _amountWad(IERC20(token1).balanceOf(address(this)), false);

        // get D balance before add liquidity
        uint256 _d = _D(xWad, yWad);

        // convert amounts to wad for calcs
        uint256 amount0Wad = _amountWad(amounts[0], true);
        uint256 amount1Wad = _amountWad(amounts[1], false);

        // balances after transfer
        xWad += amount0Wad;
        yWad += amount1Wad;

        // calc diff with new D value
        minted_ = _D(xWad, yWad) - _d;
        _d += minted_;

        // transfer amounts in decimals in
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amounts[0]);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amounts[1]);

        // TODO: fix
        uint256[] memory fees = new uint256[](2);
        fees[0] = 0;
        fees[1] = 0;

        emit AddLiquidity(msg.sender, amounts, fees, _d, _d);
    }

    /// @notice Removes liquidity from pool
    /// @param amount The amount of liquidity to remove
    /// @param minAmounts The minimum amounts of token to receive in token decimals
    /// @param deadline The deadline before which liquidity must be removed
    function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external onlyOwner returns (uint256[] memory amountsOut_) {
        require(minAmounts.length == 2, "invalid min amounts");

        // get current token balances in pool
        uint256 xWad = _amountWad(IERC20(token0).balanceOf(address(this)), true);
        uint256 yWad = _amountWad(IERC20(token1).balanceOf(address(this)), false);

        // get D balance before add liquidity
        uint256 _d = _D(xWad, yWad);

        // amount of liquidity to remove must be less than D
        require(amount <= _d, "amount > D");

        // token amounts to remove are x * amount / D and y * amount / D
        uint256 dx = _amountDecimals(Math.mulDiv(xWad, amount, _d), true);
        uint256 dy = _amountDecimals(Math.mulDiv(yWad, amount, _d), false);

        // check exceeds min amounts
        require(dx >= minAmounts[0], "dx < min");
        require(dy >= minAmounts[1], "dy < min");

        // transfer amounts out
        IERC20(token0).safeTransfer(msg.sender, dx);
        IERC20(token1).safeTransfer(msg.sender, dy);

        // return amounts transferred out
        amountsOut_[0] = dx;
        amountsOut_[1] = dy;

        emit RemoveLiquidity(msg.sender, amountsOut_, _d - amount);
    }

    /// @notice Swaps token from for an amount of token to
    /// @param tokenIndexFrom The index of the token in
    /// @param tokenIndexTo The index of the token out
    /// @param dx The amount of token in in token decimals
    /// @param minDy The minimum amount of token out in token decimals
    /// @param deadline The deadline before which swap must be executed
    // TODO: add fees and possibly spread
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline // TODO: deadline
    ) external returns (uint256 dy_) {
        require(tokenIndexFrom != tokenIndexTo, "invalid token swap");

        // calculate amount out from swap
        // @dev reverts for invalid token indices
        dy_ = calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
        require(dy_ >= minDy, "dy < minDy");

        // transfer dx in and send dy out
        address tokenIn = tokenIndexFrom == 0 ? token0 : token1;
        address tokenOut = tokenIndexTo == 0 ? token0 : token1;
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), dx);
        IERC20(tokenOut).safeTransfer(msg.sender, dy_);

        emit TokenSwap(msg.sender, dx, dy_, tokenIndexFrom, tokenIndexTo);
    }

    /// @notice Calculates amount of tokens received on swap
    /// @dev Reverts if either token index is invalid
    /// @param tokenIndexFrom The index of the token in
    /// @param tokenIndexTo The index of the token out
    /// @param dx The amount of token in in token decimals
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) public view onlyToken(tokenIndexFrom) onlyToken(tokenIndexTo) returns (uint256 dy_) {
        // get current token balances in pool
        uint256 xWad = _amountWad(IERC20(token0).balanceOf(address(this)), true);
        uint256 yWad = _amountWad(IERC20(token1).balanceOf(address(this)), false);

        // convert to an amount in wad
        uint256 amountInWad = _amountWad(dx, tokenIndexFrom == 0);

        // calculate swap amount out wad
        // @dev obeys P * x + y = D
        uint256 amountOutWad;
        if (tokenIndexFrom == 0) {
            // get D balance before swap
            uint256 _d = _D(xWad, yWad);

            // token0 in for token1 out
            xWad += amountInWad;

            // check amount out won't exceed pool balance
            uint256 prod = Math.mulDiv(P, xWad, wad);
            require(_d >= prod, "dy > pool balance");

            uint256 yWadAfter = _d - prod;
            amountOutWad = yWad - yWadAfter;
        } else {
            // get D balance before swap
            uint256 _d = _D(xWad, yWad);

            // token1 in for token0 out
            yWad += amountInWad;

            // check amount out won't exceed pool balance
            require(_d >= yWad, "dy > pool balance");

            uint256 xWadAfter = Math.mulDiv(_d - yWad, wad, P);
            amountOutWad = xWad - xWadAfter;
        }

        // convert amount out to decimals
        dy_ = _amountDecimals(amountOutWad, tokenIndexTo == 0);
    }

    /// @notice Address of the pooled token at given index
    /// @dev Reverts for invalid token index
    /// @param index The index of the token
    function getToken(uint8 index) external view onlyToken(index) returns (IERC20) {
        address token = index == 0 ? token0 : token1;
        return IERC20(token);
    }

    /// @notice D liquidity for current pool balance state
    function D() external view returns (uint256) {
        uint256 xWad = _amountWad(IERC20(token0).balanceOf(address(this)), true);
        uint256 yWad = _amountWad(IERC20(token1).balanceOf(address(this)), false);
        return _D(xWad, yWad);
    }

    /// @notice D liquidity param given pool token balances
    /// @param xWad Balance of x tokens in wad
    /// @param yWad Balance of y tokens in wad
    function _D(uint256 xWad, uint256 yWad) internal view returns (uint256) {
        return Math.mulDiv(xWad, P, wad) + yWad;
    }

    /// @notice Amount of token in wad
    /// @param dx Amount of token in token decimals
    /// @param isToken0 Whether token is token0
    function _amountWad(uint256 dx, bool isToken0) internal view returns (uint256) {
        uint256 factor = isToken0 ? 10**(token0Decimals) : 10**(token1Decimals);
        return Math.mulDiv(dx, wad, factor);
    }

    /// @notice Amount of token in token decimals
    /// @param amount Amount of token in wad
    /// @param isToken0 Whether token is token0
    function _amountDecimals(uint256 amount, bool isToken0) internal view returns (uint256) {
        uint256 factor = isToken0 ? 10**(token0Decimals) : 10**(token1Decimals);
        return Math.mulDiv(amount, factor, wad);
    }
}
