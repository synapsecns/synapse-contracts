// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract JewelBridgeSwap {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Mintable;
    using SafeMath for uint256;

    // Maps token address to an index in the pool. Used to prevent duplicate tokens in the pool.
    // getTokenIndex function also relies on this mapping to retrieve token index.
    mapping(address => uint8) private tokenIndexes;
    IERC20[] pooledTokens;
    
    constructor(IERC20 tokenA, IERC20 mintableTokenB) public {
        pooledTokens[0] = tokenA;
        pooledTokens[1] = mintableTokenB;
        tokenIndexes[address(tokenA)] = 0;
        tokenIndexes[address(mintableTokenB)] = 1;
    }

    /**
     * @notice Return address of the pooled token at given index. Reverts if tokenIndex is out of range.
     * @param index the index of the token
     * @return address of the token at given index
     */
    function getToken(uint8 index) public view virtual returns (IERC20) {
        require(index < pooledTokens.length, "Out of range");
        return pooledTokens[index];
    }

    /**
     * @notice Return the index of the given token address. Reverts if no matching
     * token is found.
     * @param tokenAddress address of the token
     * @return the index of the given token address
     */
    function getTokenIndex(address tokenAddress)
        public
        view
        returns (uint8)
    {
        uint8 index = tokenIndexes[tokenAddress];
        require(
            address(getToken(index)) == tokenAddress,
            "Token does not exist"
        );
        return index;
    }

    /**
     * @notice Calculate amount of tokens you receive on swap
     * @param tokenIndexFrom the token the user wants to sell
     * @param tokenIndexTo the token the user wants to buy
     * @param dx the amount of tokens the user wants to swap. 
     * @return amount of tokens the user will receive
     */
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256) {
        return dx;
    }

    /**
     * @notice Swap two tokens using this pool
     * @param tokenIndexFrom the token the user wants to swap from
     * @param tokenIndexTo the token the user wants to swap to
     * @param dx the amount of tokens the user wants to swap from
     * @param minDy the min amount the user would like to receive, or revert.
     * @param deadline latest timestamp to accept this transaction
     */
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    )
        external
        returns (uint256)
    {
        {
            IERC20 tokenFrom = pooledTokens[tokenIndexFrom];
            require(
                dx <= tokenFrom.balanceOf(msg.sender),
                "Cannot swap more than you own"
            );
            // Transfer tokens first to see if a fee was charged on transfer
            uint256 beforeBalance = tokenFrom.balanceOf(address(this));
            tokenFrom.safeTransferFrom(msg.sender, address(this), dx);

            // Use the actual transferred amount for AMM math
            dx = tokenFrom.balanceOf(address(this)).sub(beforeBalance);
        }

        // mint synJEWEL to caller
        if (tokenIndexFrom == 0 && tokenIndexTo == 1) {
            IERC20Mintable(address(pooledTokens[tokenIndexTo])).mint(msg.sender, dx);
            return dx;
        // redeem synJEWEL for JEWEL
        } else if (tokenIndexFrom == 1 && tokenIndexTo == 0) {
            pooledTokens[tokenIndexTo].safeTransfer(msg.sender, dx);
            return dx;
        } else {
            revert("Unsupported indexes");
        }
    }
}