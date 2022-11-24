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
 * - Synapse    nUSD/NOTE
 * - CantoDex   NOTE/USDC
 * - CantoDex   NOTE/USDT
 * Swaps between "disconnected" coins are routed through NOTE.
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
    address internal constant SYNAPSE_NUSD_POOL = 0x07379565cD8B0CaE7c60Dc78e7f601b34AF2A21c;
    /// @notice CantoDEX NOTE/USDC
    address internal constant CANTO_DEX_USDC_POOL = 0x9571997a66D63958e1B3De9647C22bD6b9e7228c;
    /// @notice CantoDEX NOTE/USDT
    address internal constant CANTO_DEX_USDT_POOL = 0x35DB1f3a6A6F07f82C76fCC415dB6cFB1a7df833;

    uint256 internal constant MAX_UINT = type(uint256).max;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             CONSTRUCTOR                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    constructor() {
        // Approve spending by Synapse Pool
        NUSD.safeApprove(SYNAPSE_NUSD_POOL, MAX_UINT);
        NOTE.safeApprove(SYNAPSE_NUSD_POOL, MAX_UINT);
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
        dx = tokenFrom.balanceOf(address(this)) - balanceBefore;
        // Check if direct swap is possible
        address pool = _getDirectSwap(tokenIndexFrom, tokenIndexTo);
        if (pool != address(0)) {
            amountOut = _directSwap(pool, tokenIndexFrom, tokenIndexTo, dx, minDy, msg.sender);
        } else {
            // First, perform tokenFrom -> NOTE swap, recipient is this contract
            pool = _getDirectSwap(tokenIndexFrom, NOTE_INDEX);
            // Don't check minAmountOut
            amountOut = _directSwap(pool, tokenIndexFrom, NOTE_INDEX, dx, 0, address(this));
            // Then, perform NOTE -> tokenTo swap, recipient is the user
            pool = _getDirectSwap(NOTE_INDEX, tokenIndexTo);
            // Check minAmountOut
            amountOut = _directSwap(pool, NOTE_INDEX, tokenIndexTo, amountOut, minDy, msg.sender);
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
        if (tokenIndexFrom == tokenIndexTo) return 0;
        // Check if direct swap is possible
        address pool = _getDirectSwap(tokenIndexFrom, tokenIndexTo);
        if (pool != address(0)) {
            amountOut = _getDirectAmountOut(pool, tokenIndexFrom, tokenIndexTo, dx);
        } else {
            // First, get tokenFrom -> NOTE quote
            pool = _getDirectSwap(tokenIndexFrom, NOTE_INDEX);
            amountOut = _getDirectAmountOut(pool, tokenIndexFrom, NOTE_INDEX, dx);
            // Then, get NOTE -> tokenTo quote
            pool = _getDirectSwap(NOTE_INDEX, tokenIndexTo);
            amountOut = _getDirectAmountOut(pool, NOTE_INDEX, tokenIndexTo, amountOut);
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
        if (pool == SYNAPSE_NUSD_POOL) {
            // Perform a swap through Synapse pool: check output amount, but don't check timestamp
            // Indexes in Synapse pool match the indexes in SwapWrapper
            amountOut = ISynapse(pool).swap({
                tokenIndexFrom: uint8(indexFrom),
                tokenIndexTo: uint8(indexTo),
                dx: amountIn,
                minDy: minAmountOut,
                deadline: MAX_UINT
            });
            // Transfer tokens to recipient, if needed
            if (recipient != address(this)) {
                _getToken(indexTo).safeTransfer(recipient, amountOut);
            }
        } else if (pool == CANTO_DEX_USDC_POOL || pool == CANTO_DEX_USDT_POOL) {
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
        if (pool == SYNAPSE_NUSD_POOL) {
            // Indexes in Synapse pool match the indexes in SwapWrapper
            amountOut = ISynapse(pool).calculateSwap(uint8(indexFrom), uint8(indexTo), amountIn);
        } else if (pool == CANTO_DEX_USDC_POOL || pool == CANTO_DEX_USDT_POOL) {
            // Get starting token
            IERC20 tokenFrom = _getToken(indexFrom);
            // Get a quote
            amountOut = ICantoDex(pool).getAmountOut(amountIn, address(tokenFrom));
        }
        /// @dev amountOut is 0 if direct swap is not supported
    }

    /**
     * @notice Gets pool address for direct swap between two tokens.
     * @dev Returns address(0) if swap is not possible.
     * @param indexFrom    Index of token to sell (see _getToken())
     * @param indexTo      Index of token to buy (see _getToken())
     * @return pool         Pool address that can do tokenFrom -> tokenTo swap
     */
    function _getDirectSwap(uint256 indexFrom, uint256 indexTo) internal pure returns (address pool) {
        if (indexFrom == NOTE_INDEX) {
            // Get pool for NOTE -> * swap
            pool = _getDirectSwapNOTE(indexTo);
        } else if (indexTo == NOTE_INDEX) {
            // Get pool for * -> NOTE swap
            pool = _getDirectSwapNOTE(indexFrom);
        }
        /// @dev pool is address(0) if direct swap is not supported.
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
     * @notice Gets pool address for direct swap between NOTE and a given token.
     * @dev Returns address(0) if swap is not possible.
     * @param tokenIndex   Index of token to swap (see _getToken())
     * @return pool         Pool address that can do `tokenIndex` <> NOTE swap
     */
    function _getDirectSwapNOTE(uint256 tokenIndex) internal pure returns (address pool) {
        if (tokenIndex == NUSD_INDEX) {
            // nUSD <> NOTE is routed through Synapse
            pool = SYNAPSE_NUSD_POOL;
        } else if (tokenIndex == USDC_INDEX) {
            // USDC <> NOTE is routed through CantoDEX
            pool = CANTO_DEX_USDC_POOL;
        } else if (tokenIndex == USDT_INDEX) {
            // USDT <> NOTE is routed through CantoDEX
            pool = CANTO_DEX_USDT_POOL;
        }
        /// @dev pool is address(0) if tokenIndex is NOTE_INDEX, or out of range
    }
}
