// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/ISwap.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BaseSwapDeposit is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    ISwap public baseSwap;
    IERC20[] public baseTokens;

    uint256 constant MAX_UINT256 = 2**256 - 1;

    constructor(ISwap _baseSwap) public {
        baseSwap = _baseSwap;
           // Check and approve base level tokens to be deposited to the base Swap contract
        {
            uint8 i;
            for (; i < 32; i++) {
                try _baseSwap.getToken(i) returns (IERC20 token) {
                    baseTokens.push(token);
                    token.safeApprove(address(_baseSwap), MAX_UINT256);
                } catch {
                    break;
                }
            }
            require(i > 1, "baseSwap must have at least 2 tokens");
        }
    }

    // Mutative functions

    /**
     * @notice Swap two underlying tokens using the meta pool and the base pool
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
    ) external nonReentrant returns (uint256) {
        baseTokens[tokenIndexFrom].safeTransferFrom(msg.sender, address(this), dx);
        uint256 tokenToAmount =
            baseSwap.swap(
                tokenIndexFrom,
                tokenIndexTo,
                dx,
                minDy,
                deadline
            );
        baseTokens[tokenIndexTo].safeTransfer(msg.sender, tokenToAmount);
        return tokenToAmount;
    }

     /**
     * @notice Calculate amount of tokens you receive on swap
     * @param tokenIndexFrom the token the user wants to sell
     * @param tokenIndexTo the token the user wants to buy
     * @param dx the amount of tokens the user wants to sell. If the token charges
     * a fee on transfers, use the amount that gets transferred after the fee.
     * @return amount of tokens the user will receive
     */
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256) {
        return
            baseSwap.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    }

        /**
     * @notice Returns the address of the pooled token at given index. Reverts if tokenIndex is out of range.
     * @param index the index of the token
     * @return address of the token at given index
     */
    function getToken(uint256 index) external view returns (IERC20) {
        require(index < baseTokens.length, "index out of range");
        return baseTokens[index];
    }

}