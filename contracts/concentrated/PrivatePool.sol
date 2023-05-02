// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.8.0/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts-4.8.0/utils/math/Math.sol";

/// @title Private pool for concentrated liquidity
/// @notice Allows LP to offer fixed price quote in private pool to bridgers for tighter prices
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

    uint256 public price; // amount of token1 per amount of token0 in wad

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

    /// @notice Updates the quote price LP is willing to offer tokens at
    /// @param _price The new price LP is willing to buy and sell at
    // TODO: time lock for changing?
    // TODO: consider add or remove liquidity requirement so pool balanced st if take all of one token, take all of the other
    function quote(uint256 _price) external onlyOwner {
        require(_price >= PRICE_MIN && price <= PRICE_MAX, "price out of range");
        price = _price;
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

        // convert to an amount in wad and calculate swap amount out wad
        uint256 amountInWad = amountWad(dx, tokenIndexFrom == 0);
        uint256 amountOutWad = tokenIndexTo == 1
            ? Math.mulDiv(amountInWad, price, wad)
            : Math.mulDiv(amountInWad, wad, price); // in wad

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

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external onlyOwner returns (uint256) {}

    function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external onlyOwner returns (uint256[] memory) {}
}
