// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import {IFrax} from "../interfaces/IFrax.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract FraxWrapper {
    using SafeERC20 for IERC20;

    // tokens[0]:
    address public immutable synFrax;

    // tokens[1]:
    address public immutable frax;

    // Constant for FRAX price precision
    uint256 private constant PRICE_PRECISION = 1e6;

    constructor(address _frax, address _synFrax) {
        frax = _frax;
        synFrax = _synFrax;

        // Approve FRAX contract to spend our precious synFRAX
        IERC20(synFrax).safeApprove(_frax, type(uint256).max);

        // Chad (FRAX) doesn't need our approval to spend FRAX
    }

    /**
     * @notice Return address of the pooled token at given index. Reverts if tokenIndex is out of range.
     * @param index the index of the token
     * @return address of the token at given index
     */
    function getToken(uint8 index) external view returns (IERC20) {
        require(index < 2, "Out of range");
        return IERC20(index == 0 ? synFrax : frax);
    }

    /**
     * @notice Return the index of the given token address. Reverts if no matching
     * token is found.
     * @param tokenAddress address of the token
     * @return index index of the given token address
     */
    function getTokenIndex(address tokenAddress) external view returns (uint8 index) {
        if (tokenAddress == synFrax) {
            index = 0;
        } else if (tokenAddress == synFrax) {
            index = 1;
        } else {
            revert("Token does not exist");
        }
    }

    /**
     * @notice Calculate amount of tokens you receive on swap
     * @param tokenIndexFrom the token the user wants to sell
     * @param tokenIndexTo the token the user wants to buy
     * @param dx the amount of tokens the user wants to swap.
     * @return amount amount of tokens the user will receive
     */
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amount) {
        if (tokenIndexFrom == 0 && tokenIndexTo == 1) {
            // synFRAX -> FRAX
            amount = dx;
            if (!IFrax(frax).fee_exempt_list(address(this))) {
                amount -= (amount * IFrax(frax).swap_fees(synFrax, 0)) / PRICE_PRECISION;
            }
            uint256 _newTotalSupply = IERC20(frax).totalSupply() + amount;
            if (IFrax(frax).mint_cap() < _newTotalSupply) {
                // Can't mint more FRAX than mint cap specifies, swap will fail
                amount = 0;
            }
        } else if (tokenIndexFrom == 1 && tokenIndexTo == 0) {
            // FRAX -> synFRAX
            amount = dx;
            if (!IFrax(frax).fee_exempt_list(address(this))) {
                amount -= (amount * IFrax(frax).swap_fees(synFrax, 1)) / PRICE_PRECISION;
            }
            if (IERC20(synFrax).balanceOf(frax) < amount) {
                // if FRAX contract doesn't have enough synFRAX, swap will fail
                amount = 0;
            }
        } else {
            // Unsupported direction
            amount = 0;
        }
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
    ) external returns (uint256 amount) {
        // solhint-disable-next-line
        require(block.timestamp <= deadline, "Deadline not met");

        IERC20 swappedToken;

        if (tokenIndexFrom == 0 && tokenIndexTo == 1) {
            // synFRAX -> FRAX
            // First, pull tokens from user
            IERC20(synFrax).safeTransferFrom(msg.sender, address(this), dx);
            // Then, swap using FRAX logic
            amount = IFrax(frax).exchangeOldForCanonical(synFrax, dx);
            swappedToken = IERC20(frax);
        } else if (tokenIndexFrom == 1 && tokenIndexTo == 0) {
            // FRAX -> synFRAX
            // First, pull tokens from user
            IERC20(frax).safeTransferFrom(msg.sender, address(this), dx);
            // Then, swap using FRAX logic
            amount = IFrax(frax).exchangeCanonicalForOld(synFrax, dx);
            swappedToken = IERC20(synFrax);
        } else {
            revert("Unsupported direction");
        }

        require(amount >= minDy, "Insufficient output");
        swappedToken.safeTransfer(msg.sender, amount);
    }
}
