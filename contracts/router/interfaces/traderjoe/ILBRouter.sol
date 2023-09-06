// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/IERC20.sol";
import {ILBPair} from "./ILBPair.sol";

interface ILBRouter {
    /**
     * @dev This enum represents the version of the pair requested
     * - V1: Joe V1 pair
     * - V2: LB pair V2. Also called legacyPair
     * - V2_1: LB pair V2.1 (current version)
     */
    enum Version {
        V1,
        V2,
        V2_1
    }

    /**
     * @dev The path parameters, such as:
     * - pairBinSteps: The list of bin steps of the pairs to go through
     * - versions: The list of versions of the pairs to go through
     * - tokenPath: The list of tokens in the path to go through
     */
    struct Path {
        uint256[] pairBinSteps;
        Version[] versions;
        IERC20[] tokenPath;
    }

    /**
     * @notice Swaps exact tokens for tokens while performing safety checks
     * @param amountIn The amount of token to send
     * @param amountOutMin The min amount of token to receive
     * @param path The path of the swap
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountOut Output amount of the swap
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Path memory path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function getSwapOut(
        ILBPair LBPair,
        uint128 amountIn,
        bool swapForY
    )
        external
        view
        returns (
            uint128 amountInLeft,
            uint128 amountOut,
            uint128 fee
        );
}
