// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

interface ISynapse {
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256);

    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);
}

interface ICantoDex {
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);

    // this low-level function should be called from a contract which performs important safety checks
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

/**
 * @notice Contract mimicking Saddle swap interface to connect following pools:
 * - Synapse    nUSD/USDC
 * - CantoDex   NOTE/USDC
 * - CantoDex   NOTE/USDT
 * Swaps between "disconnected" coins are routed through USDC (and NOTE for USDT).
 * nUSD <> USDC <> NOTE <> USDT
 */
contract CantoSwapWrapper {
    using SafeERC20 for IERC20;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              CONSTANTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Token ordering is nUSD, NOTE (for backwards compatibility),
     * then all remaining tokens sorted alphabetically.
     * (index: token)
     * 0: nUSD
     * 1: NOTE
     * 2: USDC
     * 3: USDT
     */

    // Synapse-bridged token: nUSD
    IERC20 internal constant NUSD = IERC20(0xD8836aF2e565D3Befce7D906Af63ee45a57E8f80);
    // Canto native token: NOTE
    IERC20 internal constant NOTE = IERC20(0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503);
    // Gravity-bridged token: USDC
    IERC20 internal constant USDC = IERC20(0x80b5a32E4F032B2a058b4F29EC95EEfEEB87aDcd);
    // Gravity-bridged token: USDT
    IERC20 internal constant USDT = IERC20(0xd567B3d7B8FE3C79a1AD8dA978812cfC4Fa05e75);

    uint256 internal constant NUSD_INDEX = 0;
    uint256 internal constant NOTE_INDEX = 1;
    uint256 internal constant USDC_INDEX = 2;
    uint256 internal constant USDT_INDEX = 3;
    uint256 internal constant COINS = 4;

    /// @notice Synapse nUSD/NOTE
    address internal constant SYNAPSE_NUSD_USDC = 0xb1Da21B0531257a7E5aEfa0cd3CbF23AfC674cE1;
    /// @notice CantoDEX NOTE/USDC
    address internal constant CANTO_DEX_NOTE_USDC = 0x9571997a66D63958e1B3De9647C22bD6b9e7228c;
    /// @notice CantoDEX NOTE/USDT
    address internal constant CANTO_DEX_NOTE_USDT = 0x35DB1f3a6A6F07f82C76fCC415dB6cFB1a7df833;

    uint256 internal constant MAX_UINT = type(uint256).max;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             CONSTRUCTOR                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    constructor() {
        // Approve spending by Synapse Pool
        NUSD.safeApprove(SYNAPSE_NUSD_USDC, MAX_UINT);
        USDC.safeApprove(SYNAPSE_NUSD_USDC, MAX_UINT);
        // CantoDEX pools don't need approvals
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          EXTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Wrapper for ISaddle.swap()
     * @param tokenIndexFrom    the token the user wants to swap from
     * @param tokenIndexTo      the token the user wants to swap to
     * @param dx                the amount of tokens the user wants to swap from
     * @param minDy             the min amount the user would like to receive, or revert.
     * @param deadline          latest timestamp to accept this transaction
     * @return amountOut        amount of tokens bought
     */
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= deadline, "Deadline not met");
        require(tokenIndexFrom < COINS && tokenIndexTo < COINS && tokenIndexFrom != tokenIndexTo, "Swap not supported");
        IERC20 tokenFrom = _getToken(tokenIndexFrom);
        // Record balance before transfer
        uint256 balanceBefore = tokenFrom.balanceOf(address(this));
        // First, pull tokens from the user
        tokenFrom.safeTransferFrom(msg.sender, address(this), dx);
        // Use actual transferred amount for the swap
        amountOut = tokenFrom.balanceOf(address(this)) - balanceBefore;
        // Do a series of swaps until the requested token is reached
        while (tokenIndexFrom != tokenIndexTo) {
            // Get the swap. It will be either the needed direct swap,
            // or a swap in the right direction (for the multi-hop swap)
            (uint256 indexTo, address pool) = _getSwap(tokenIndexFrom, tokenIndexTo);
            // Perform a swap using the derived values
            // Don't check minAmountOut until the very last swap
            // Transfer tokens to msg.sender in the very last swap
            amountOut = _directSwap({
                pool: pool,
                indexFrom: tokenIndexFrom,
                indexTo: indexTo,
                amountIn: amountOut,
                minAmountOut: indexTo == tokenIndexTo ? minDy : 0,
                recipient: indexTo == tokenIndexTo ? msg.sender : address(this)
            });
            // Update current token
            tokenIndexFrom = uint8(indexTo);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Wrapper for ISaddle.calculateSwap()
     * @param tokenIndexFrom    the token the user wants to sell
     * @param tokenIndexTo      the token the user wants to buy
     * @param dx                the amount of tokens the user wants to sell. If the token charges
     *                          a fee on transfers, use the amount that gets transferred after the fee.
     * @return amountOut        amount of tokens the user will receive
     */
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut) {
        if (tokenIndexFrom == tokenIndexTo || tokenIndexFrom >= COINS || tokenIndexTo >= COINS) return 0;
        amountOut = dx;
        // Get the quotes for swaps until the requested token is reached
        while (tokenIndexFrom != tokenIndexTo) {
            // Get the swap. It will be either the needed direct swap,
            // or a swap in the right direction (for the multi-hop swap)
            (uint256 indexTo, address pool) = _getSwap(tokenIndexFrom, tokenIndexTo);
            // Get a quote for the  swap using the derived values
            amountOut = _getDirectAmountOut({
                pool: pool,
                indexFrom: tokenIndexFrom,
                indexTo: indexTo,
                amountIn: amountOut
            });
            // Update current token
            tokenIndexFrom = uint8(indexTo);
        }
    }

    /**
     * @notice Wrapper for ISaddle.getToken()
     * @param index     the index of the token
     * @return token    address of the token at given index
     */
    function getToken(uint8 index) external pure returns (IERC20 token) {
        token = _getToken(index);
        require(address(token) != address(0), "Out of range");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          INTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Performs a swap between tokens through given pool,
     * assuming tokens to sell are already in this contract.
     * @param pool          Pool to execute the swap through
     * @param indexFrom     Index of token to sell (see _getToken())
     * @param indexTo       Index of token to buy (see _getToken())
     * @param amountIn      Amount of tokens to sell
     * @param minAmountOut  Minimum amount of tokens to buy, or tx will revert
     * @param recipient     Address to transfer bought tokens to
     * @return amountOut    Amount of token bought
     */
    function _directSwap(
        address pool,
        uint256 indexFrom,
        uint256 indexTo,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256 amountOut) {
        if (pool == SYNAPSE_NUSD_USDC) {
            // Perform a swap through Synapse pool: check output amount, but don't check timestamp
            // Calculate Synapse indexes
            amountOut = ISynapse(pool).swap({
                tokenIndexFrom: _getSynapseIndex(indexFrom),
                tokenIndexTo: _getSynapseIndex(indexTo),
                dx: amountIn,
                minDy: minAmountOut,
                deadline: MAX_UINT
            });
            // Transfer tokens to recipient, if needed
            if (recipient != address(this)) {
                _getToken(indexTo).safeTransfer(recipient, amountOut);
            }
        } else if (pool == CANTO_DEX_NOTE_USDC || pool == CANTO_DEX_NOTE_USDT) {
            // Get starting token
            IERC20 tokenFrom = _getToken(indexFrom);
            // Get a quote, and check it against minimum amount out
            amountOut = ICantoDex(pool).getAmountOut(amountIn, address(tokenFrom));
            require(amountOut >= minAmountOut, "Swap didn't result in min tokens");
            // Transfer starting token to Pair contract
            tokenFrom.safeTransfer(address(pool), amountIn);
            // NOTE is token0 in both NOTE/USDC and NOTE/USDT pool,
            // because NOTE address is lexicographically smaller
            (uint256 amount0Out, uint256 amount1Out) = (indexFrom == NOTE_INDEX)
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            // Perform a swap, transfer the bought token to the recipient directly
            ICantoDex(pool).swap(amount0Out, amount1Out, recipient, bytes(""));
        } else {
            // Sanity check: should never reach this
            assert(false);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Get a quote for a swap between two tokens via a given pool.
     * @param pool          Pool to execute the swap through
     * @param indexFrom     Index of token to sell (see _getToken())
     * @param indexTo       Index of token to buy (see _getToken())
     * @param amountIn      Amount of tokens to sell
     * @return amountOut    Quote for amount of tokens to buy
     */
    function _getDirectAmountOut(
        address pool,
        uint256 indexFrom,
        uint256 indexTo,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        // First, check input amount
        if (amountIn == 0) return 0;
        if (pool == SYNAPSE_NUSD_USDC) {
            // Calculate Synapse indexes and get the quote
            amountOut = ISynapse(pool).calculateSwap({
                tokenIndexFrom: _getSynapseIndex(indexFrom),
                tokenIndexTo: _getSynapseIndex(indexTo),
                dx: amountIn
            });
        } else if (pool == CANTO_DEX_NOTE_USDC || pool == CANTO_DEX_NOTE_USDT) {
            // Get starting token
            IERC20 tokenFrom = _getToken(indexFrom);
            // Get a quote
            amountOut = ICantoDex(pool).getAmountOut(amountIn, address(tokenFrom));
        }
        /// @dev amountOut is 0 if direct swap is not supported
    }

    /**
     * @notice Gets token represented by a given index in this contract.
     * @dev Returns address(0) if token index is out of bounds.
     * @param tokenIndex    This contract's index of token
     * @return token        Token represented by `tokenIndex`
     */
    function _getToken(uint256 tokenIndex) internal pure returns (IERC20 token) {
        if (tokenIndex == NUSD_INDEX) {
            token = NUSD;
        } else if (tokenIndex == NOTE_INDEX) {
            token = NOTE;
        } else if (tokenIndex == USDC_INDEX) {
            token = USDC;
        } else if (tokenIndex == USDT_INDEX) {
            token = USDT;
        }
        /// @dev token is IERC20(address(0)) for unsupported indexes
    }

    /**
     * @notice Gets needed swap in order to get from `indexFrom` to `indexRequested`
     * Returns either the direct swap, if possible. Or a swap in a needed direction,
     * if multi-hop swap is required.
     */
    function _getSwap(uint256 indexFrom, uint256 indexRequested)
        internal
        pure
        returns (uint256 tokenIndexTo, address pool)
    {
        // nUSD <> USDC <> NOTE <> USDT
        if (indexFrom == NUSD_INDEX) {
            // nUSD can be only swapped to USDC
            tokenIndexTo = USDC_INDEX;
            pool = SYNAPSE_NUSD_USDC;
        } else if (indexFrom == USDC_INDEX) {
            // USDC can be swapped to nUSD or NOTE
            if (indexRequested == NUSD_INDEX) {
                tokenIndexTo = NUSD_INDEX;
                pool = SYNAPSE_NUSD_USDC;
            } else {
                // NOTE is the path we want to take for the multi-hop swap
                tokenIndexTo = NOTE_INDEX;
                pool = CANTO_DEX_NOTE_USDC;
            }
        } else if (indexFrom == NOTE_INDEX) {
            // NOTE can be swapped to USDC or USDT
            if (indexRequested == USDT_INDEX) {
                tokenIndexTo = USDT_INDEX;
                pool = CANTO_DEX_NOTE_USDT;
            } else {
                // USDC is the path we want to take for the multi-hop swap
                tokenIndexTo = USDC_INDEX;
                pool = CANTO_DEX_NOTE_USDC;
            }
        } else if (indexFrom == USDT_INDEX) {
            // USDT can only be swapped to NOTE
            tokenIndexTo = NOTE_INDEX;
            pool = CANTO_DEX_NOTE_USDT;
        }
    }

    /**
     * @notice Returns the index for the given token in the Synapse nUSD/USDC pool
     */
    function _getSynapseIndex(uint256 tokenIndex) internal pure returns (uint8 synapseIndex) {
        if (tokenIndex == NUSD_INDEX) {
            synapseIndex = 0;
        } else if (tokenIndex == USDC_INDEX) {
            synapseIndex = 1;
        } else {
            // Sanity check: should never reach this
            assert(false);
        }
    }
}
