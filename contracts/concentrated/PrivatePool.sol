// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.8.0/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts-4.8.0/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts-4.8.0/security/ReentrancyGuard.sol";

import {IPrivateFactory} from "./interfaces/IPrivateFactory.sol";
import {IPrivatePool} from "./interfaces/IPrivatePool.sol";

/// @title Private pool for concentrated liquidity
/// @notice Allows LP to offer fixed price quote in private pool to bridgers for tighter prices
/// @dev Obeys constant sum P * x + y = D curve, where P is fixed price and D is liquidity
/// @dev Functions use same signatures as Swap.sol for easier integration
contract PrivatePool is IPrivatePool, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 internal constant wad = 1e18;
    uint256 internal constant PRICE_BOUND = 0.001e18; // 10 bps in wad

    uint256 public constant PRICE_MIN = wad - PRICE_BOUND; // 1 - 10bps in wad
    uint256 public constant PRICE_MAX = wad + PRICE_BOUND; // 1 + 10bps in wad
    uint256 public constant FEE_MAX = 0.01e18; // 100 bps in wad
    uint256 public constant ADMIN_FEE_MAX = 1e18; // 100% of swap fees in wad

    address public immutable factory;
    address public immutable owner;

    address public immutable token0; // base token
    address public immutable token1; // quote token

    uint256 internal immutable token0Decimals;
    uint256 internal immutable token1Decimals;

    uint256 public P; // fixed price param: amount of token1 per amount of token0 in wad
    uint256 public fee; // fee charged on swap; acts as LP's bid/ask spread
    uint256 public adminFee; // % of swap fee to protocol

    uint256 public protocolFees0;
    uint256 public protocolFees1;

    modifier onlyFactory() {
        require(msg.sender == factory, "!factory");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyToken(uint8 index) {
        require(index <= 1, "invalid token index");
        _;
    }

    modifier deadlineCheck(uint256 deadline) {
        require(block.timestamp <= deadline, "block.timestamp > deadline");
        _;
    }

    modifier hasQuote() {
        require(P > 0, "invalid quote");
        _;
    }

    event Quote(uint256 price);
    event NewSwapFee(uint256 newSwapFee);
    event NewAdminFee(uint256 newAdminFee);
    event TokenSwap(address indexed buyer, uint256 tokensSold, uint256 tokensBought, uint128 soldId, uint128 boughtId);
    event AddLiquidity(
        address indexed provider,
        uint256[] tokenAmounts,
        uint256[] fees,
        uint256 invariant,
        uint256 lpTokenSupply
    );
    event RemoveLiquidity(address indexed provider, uint256[] tokenAmounts, uint256 lpTokenSupply);
    event Skim(address indexed recipient, uint256[] tokenAmounts);

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
        uint256 _token0Decimals = IERC20Metadata(_token0).decimals();
        require(_token0Decimals <= 18, "token0 decimals > 18");
        token0Decimals = _token0Decimals;

        uint256 _token1Decimals = IERC20Metadata(_token1).decimals();
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

        emit Quote(_P);
    }

    /// @notice Updates the fee applied on swaps
    /// @dev Effectively acts as bid/ask spread for LP
    /// @param _fee The new swap fee
    function setSwapFee(uint256 _fee) external onlyOwner {
        require(_fee <= FEE_MAX, "fee > max");
        fee = _fee;
        emit NewSwapFee(_fee);
    }

    /// @notice Updates the admin fee applied on private pool swaps
    /// @dev Admin fees sent to factory owner
    /// @param _fee The new admin fee
    function setAdminFee(uint256 _fee) external onlyFactory {
        require(_fee <= ADMIN_FEE_MAX, "fee > max");
        adminFee = _fee;
        emit NewAdminFee(_fee);
    }

    /// @notice Adds liquidity to pool
    /// @param amounts The token amounts to add in token decimals
    /// @param deadline The deadline before which liquidity must be added
    function addLiquidity(uint256[] memory amounts, uint256 deadline)
        external
        onlyOwner
        deadlineCheck(deadline)
        hasQuote
        returns (uint256 minted_)
    {
        require(amounts.length == 2, "invalid amounts");

        // get current token balances in pool
        uint256 xBal = IERC20(token0).balanceOf(address(this));
        uint256 yBal = IERC20(token1).balanceOf(address(this));

        // convert balances to wad for liquidity calcs adjusted for protocol fees
        uint256 xWad = _amountWad(xBal - protocolFees0, true);
        uint256 yWad = _amountWad(yBal - protocolFees1, false);

        // get D balance before add liquidity
        uint256 _d = _D(xWad, yWad);

        // transfer amounts in decimals in
        if (amounts[0] > 0) IERC20(token0).safeTransferFrom(msg.sender, address(this), amounts[0]);
        if (amounts[1] > 0) IERC20(token1).safeTransferFrom(msg.sender, address(this), amounts[1]);

        // update amounts for actual transfer amount in case of fees on transfer
        amounts[0] = IERC20(token0).balanceOf(address(this)) - xBal;
        amounts[1] = IERC20(token1).balanceOf(address(this)) - yBal;

        // convert amounts to wad for calcs
        uint256 amount0Wad = _amountWad(amounts[0], true);
        uint256 amount1Wad = _amountWad(amounts[1], false);

        // balances after transfer
        xWad += amount0Wad;
        yWad += amount1Wad;

        // calc diff with new D value
        minted_ = _D(xWad, yWad) - _d;
        _d += minted_;

        uint256[] memory fees = new uint256[](2);
        emit AddLiquidity(msg.sender, amounts, fees, _d, _d);
    }

    /// @notice Removes liquidity from pool
    /// @param amounts The token amounts to remove in token decimals
    /// @param deadline The deadline before which liquidity must be removed
    function removeLiquidity(uint256[] memory amounts, uint256 deadline)
        external
        onlyOwner
        deadlineCheck(deadline)
        returns (uint256 burned_)
    {
        require(amounts.length == 2, "invalid amounts");

        // get current token balances in pool
        uint256 xBal = IERC20(token0).balanceOf(address(this));
        uint256 yBal = IERC20(token1).balanceOf(address(this));
        require(amounts[0] + protocolFees0 <= xBal, "dx > max");
        require(amounts[1] + protocolFees1 <= yBal, "dy > max");

        // convert balances to wad for liquidity calcs adjusted for protocol fees
        uint256 xWad = _amountWad(xBal - protocolFees0, true);
        uint256 yWad = _amountWad(yBal - protocolFees1, false);

        // get D balance before remove liquidity
        uint256 _d = _D(xWad, yWad);

        // transfer amounts out
        if (amounts[0] > 0) IERC20(token0).safeTransfer(msg.sender, amounts[0]);
        if (amounts[1] > 0) IERC20(token1).safeTransfer(msg.sender, amounts[1]);

        // update amounts for actual transfer amount in case of fees on transfer
        amounts[0] = xBal - IERC20(token0).balanceOf(address(this));
        amounts[1] = yBal - IERC20(token1).balanceOf(address(this));

        // convert amounts to wad for calcs
        uint256 amount0Wad = _amountWad(amounts[0], true);
        uint256 amount1Wad = _amountWad(amounts[1], false);

        // balances after transfer
        xWad -= amount0Wad;
        yWad -= amount1Wad;

        // calc diff with new D value
        burned_ = _d - _D(xWad, yWad);
        _d -= burned_;

        uint256[] memory fees = new uint256[](2);
        emit RemoveLiquidity(msg.sender, amounts, _d);
    }

    /// @notice Swaps token from for an amount of token to
    /// @param tokenIndexFrom The index of the token in
    /// @param tokenIndexTo The index of the token out
    /// @param dx The amount of token in in token decimals
    /// @param minDy The minimum amount of token out in token decimals
    /// @param deadline The deadline before which swap must be executed
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    )
        external
        nonReentrant
        onlyToken(tokenIndexFrom)
        onlyToken(tokenIndexTo)
        deadlineCheck(deadline)
        hasQuote
        returns (uint256 dy_)
    {
        require(tokenIndexFrom != tokenIndexTo, "invalid token swap");

        // get current token in balance in pool
        address tokenIn = tokenIndexFrom == 0 ? token0 : token1;
        uint256 bal = IERC20(tokenIn).balanceOf(address(this));

        // transfer in tokens and update dx (in case of transfer fees)
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), dx);
        dx = IERC20(tokenIn).balanceOf(address(this)) - bal;

        // calculate amount out from swap
        // @dev returns zero if amount out exceeds pool balance
        uint256 dyAdminFee;
        (dy_, , dyAdminFee) = _calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
        require(dy_ > 0, "dy > pool balance");
        require(dy_ >= minDy, "dy < minDy");

        if (tokenIndexTo == 0) {
            // update admin fee reserves
            protocolFees0 += dyAdminFee;

            // transfer dy out to swapper
            address tokenOut = token0;
            IERC20(tokenOut).safeTransfer(msg.sender, dy_);
        } else {
            // update admin fee reserves
            protocolFees1 += dyAdminFee;

            // transfer dy out to swapper
            address tokenOut = token1;
            IERC20(tokenOut).safeTransfer(msg.sender, dy_);
        }

        emit TokenSwap(msg.sender, dx, dy_, tokenIndexFrom, tokenIndexTo);
    }

    /// @notice Transfers protocol fees out
    /// @param recipient The recipient address of the aggregated admin fees
    function skim(address recipient) external onlyFactory {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = protocolFees0;
        amounts[1] = protocolFees1;

        // clear protocol fees
        protocolFees0 = 0;
        protocolFees1 = 0;

        // send out to factory owner
        if (amounts[0] > 0) IERC20(token0).safeTransfer(recipient, amounts[0]);
        if (amounts[1] > 0) IERC20(token1).safeTransfer(recipient, amounts[1]);

        emit Skim(recipient, amounts);
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
        uint256 xBalAdjusted = IERC20(token0).balanceOf(address(this)) - protocolFees0;
        uint256 yBalAdjusted = IERC20(token1).balanceOf(address(this)) - protocolFees1;

        uint256 xAdjustedWad = _amountWad(xBalAdjusted, true);
        uint256 yAdjustedWad = _amountWad(yBalAdjusted, false);

        return _D(xAdjustedWad, yAdjustedWad);
    }

    /// @notice Calculates amount of tokens received on swap
    /// @dev Returns zero if pool balances exceeded on swap or invalid inputs
    /// @param tokenIndexFrom The index of the token in
    /// @param tokenIndexTo The index of the token out
    /// @param dx The amount of token in in token decimals
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 dy_) {
        (dy_, , ) = _calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
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

    /// @notice Calculates amount of tokens received on swap
    /// @dev Returns zero if pool balances exceeded on swap or invalid inputs
    /// @param tokenIndexFrom The index of the token in
    /// @param tokenIndexTo The index of the token out
    /// @param dx The amount of token in in token decimals
    function _calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    )
        internal
        view
        returns (
            uint256 dy_,
            uint256 dyFee_,
            uint256 dyAdminFee_
        )
    {
        if (tokenIndexFrom > 1 || tokenIndexTo > 1 || tokenIndexFrom == tokenIndexTo) return (0, 0, 0);

        // convert to an amount in wad
        uint256 amountInWad = _amountWad(dx, tokenIndexFrom == 0);

        // calculate swap amount out wad
        // @dev obeys P * x + y = D
        uint256 amountOutWad;
        if (tokenIndexFrom == 0) {
            amountOutWad = Math.mulDiv(amountInWad, P, wad);

            // check amount out won't exceed pool balance
            uint256 yWad = _amountWad(IERC20(token1).balanceOf(address(this)) - protocolFees1, false);
            if (amountOutWad > yWad) return (0, 0, 0);
        } else {
            amountOutWad = Math.mulDiv(amountInWad, wad, P);

            // check amount out won't exceed pool balance
            uint256 xWad = _amountWad(IERC20(token0).balanceOf(address(this)) - protocolFees0, true);
            if (amountOutWad > xWad) return (0, 0, 0);
        }

        // apply swap fee on amount out
        uint256 amountSwapFeeWad = Math.mulDiv(amountOutWad, fee, wad);
        amountOutWad -= amountSwapFeeWad;

        // calculate admin fee on the total swap fee
        uint256 amountAdminFeeWad = Math.mulDiv(amountSwapFeeWad, adminFee, wad);

        // convert amount out to decimals
        dy_ = _amountDecimals(amountOutWad, tokenIndexTo == 0);
        dyFee_ = _amountDecimals(amountSwapFeeWad, tokenIndexTo == 0);
        dyAdminFee_ = _amountDecimals(amountAdminFeeWad, tokenIndexTo == 0);
    }
}
