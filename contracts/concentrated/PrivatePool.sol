// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title Private pool for concentrated liquidity
/// @notice Allows LP to offer fixed price quote in private pool to bridgers for tighter prices
/// @dev Functions use same signatures as Swap.sol for easier integration
contract PrivatePool {
    uint256 internal constant wad = 1e18;
    uint256 public constant PRICE_MIN = wad - 0.001e18; // 1 - 10bps in wad
    uint256 public constant PRICE_MAX = wad + 0.001e18; // 1 + 10bps in wad
    
    address public immutable owner;
    address public immutable token0; // base token
    address public immutable token1; // quote token
    
    uint256 public price; // in wad
    
    modifier onlyOwner {
        require(msg.sender == owner, "!owner");
        _;
    }
    
    constructor(address _token0, address _token1) {
        owner = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }
    
    /// @notice Updates the quote price LP is willing to offer tokens at
    /// @param _price The new price LP is willing to buy and sell at
    function quote(uint256 _price) external onlyOwner {
        require(_price >= PRICE_MIN && price <= PRICE_MAX, "price out of range");
        price = _price;
    }
    
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256) {}
    
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
