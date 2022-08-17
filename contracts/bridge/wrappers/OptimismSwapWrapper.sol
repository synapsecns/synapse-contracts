// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

// solhint-disable func-name-mixedcase
interface ICurve {
    // Imagine using signed integers for indexes
    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy,
        address receiver
    ) external returns (uint256);
}

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

interface IVelodrome {
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
 * - Synapse nUSD/USDC
 * - Velodrome USDC/DAI
 * - Velodrome USDC/sUSD
 * - Curve DAI/USDC/USDT
 * Swaps between "disconnected" coins are routed through USDC.
 */
contract OptimismSwapWrapper {
    using SafeERC20 for IERC20;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              CONSTANTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Token ordering is nUSD, USDC (for backwards compatibility),
     * then all remaining tokens sorted alphabetically.
     * (index: token)
     * 0: nUSD
     * 1: USDC
     * 2: DAI
     * 3: sUSD
     * 4: USDT
     */

    IERC20 internal constant NUSD = IERC20(0x67C10C397dD0Ba417329543c1a40eb48AAa7cd00);
    IERC20 internal constant USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20 internal constant DAI = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
    IERC20 internal constant SUSD = IERC20(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);
    IERC20 internal constant USDT = IERC20(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);

    uint256 internal constant NUSD_INDEX = 0;
    uint256 internal constant USDC_INDEX = 1;
    uint256 internal constant DAI_INDEX = 2;
    uint256 internal constant SUSD_INDEX = 3;
    uint256 internal constant USDT_INDEX = 4;
    uint256 internal constant COINS = 5;

    /// @notice Synapse nUSD/USDC
    address internal constant SYNAPSE_NUSD_POOL = 0xF44938b0125A6662f9536281aD2CD6c499F22004;
    /// @notice Velodrome USDC/DAI
    address internal constant VELODROME_DAI_POOL = 0x4F7ebc19844259386DBdDB7b2eB759eeFc6F8353;
    /// @notice Velodrome USDC/SUSD
    address internal constant VELODROME_SUSD_POOL = 0xd16232ad60188B68076a235c65d692090caba155;
    /// @notice Curve DAI/USDC/USDT
    address internal constant CURVE_USDT_POOL = 0x1337BedC9D22ecbe766dF105c9623922A27963EC;

    uint256 internal constant MAX_UINT = type(uint256).max;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             CONSTRUCTOR                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    constructor() {
        // Approve spending by Synapse Pool
        NUSD.safeApprove(SYNAPSE_NUSD_POOL, MAX_UINT);
        USDC.safeApprove(SYNAPSE_NUSD_POOL, MAX_UINT);
        // Velodrome pools don't need approvals
        // Approve Curve DAI/USDC/USDT Pool
        DAI.safeApprove(CURVE_USDT_POOL, MAX_UINT);
        USDC.safeApprove(CURVE_USDT_POOL, MAX_UINT);
        USDT.safeApprove(CURVE_USDT_POOL, MAX_UINT);
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
            // First, perform tokenFrom -> USDC swap, recipient is this contract
            pool = _getDirectSwap(tokenIndexFrom, USDC_INDEX);
            // Don't check minAmountOut
            amountOut = _directSwap(pool, tokenIndexFrom, USDC_INDEX, dx, 0, address(this));
            // Then, perform USDC -> tokenTo swap, recipient is the user
            pool = _getDirectSwap(USDC_INDEX, tokenIndexTo);
            // Check minAmountOut
            amountOut = _directSwap(pool, USDC_INDEX, tokenIndexTo, amountOut, minDy, msg.sender);
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
            // First, get tokenFrom -> USDC quote
            pool = _getDirectSwap(tokenIndexFrom, USDC_INDEX);
            amountOut = _getDirectAmountOut(pool, tokenIndexFrom, USDC_INDEX, dx);
            // Then, get USDC -> tokenTo quote
            pool = _getDirectSwap(USDC_INDEX, tokenIndexTo);
            amountOut = _getDirectAmountOut(pool, USDC_INDEX, tokenIndexTo, amountOut);
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
     * @param _pool         Pool to execute the swap through
     * @param _indexFrom    Index of token to sell (see _getToken())
     * @param _indexTo      Index of token to buy (see _getToken())
     * @param _amountIn     Amount of tokens to sell
     * @param _minAmountOut Minimum amount of tokens to buy, or tx will revert
     * @param _recipient    Address to transfer bought tokens to
     * @return amountOut    Amount of token bought
     */
    function _directSwap(
        address _pool,
        uint256 _indexFrom,
        uint256 _indexTo,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _recipient
    ) internal returns (uint256 amountOut) {
        if (_pool == SYNAPSE_NUSD_POOL) {
            // Indexes in Synapse pool match the indexes in SwapWrapper
            // solhint-disable-next-line not-rely-on-time
            amountOut = ISynapse(_pool).swap(uint8(_indexFrom), uint8(_indexTo), _amountIn, 0, block.timestamp);
            // Transfer tokens to recipient, if needed
            if (_recipient != address(this)) {
                _getToken(_indexTo).safeTransfer(_recipient, amountOut);
            }
        } else if (_pool == CURVE_USDT_POOL) {
            // Get corresponding Curve indexes and perform a swap
            amountOut = ICurve(_pool).exchange(
                _getCurveIndex(_indexFrom),
                _getCurveIndex(_indexTo),
                _amountIn,
                0,
                _recipient
            );
        } else if (_pool == VELODROME_DAI_POOL || _pool == VELODROME_SUSD_POOL) {
            // Get starting token
            IERC20 tokenFrom = _getToken(_indexFrom);
            // Get a quote
            amountOut = IVelodrome(_pool).getAmountOut(_amountIn, address(tokenFrom));
            // Transfer starting token to Pair contract
            tokenFrom.safeTransfer(address(_pool), _amountIn);
            // USDC is token0 in both USDC/DAI and USDC/sUSD pool,
            // because USDC address is lexicographically smaller
            (uint256 amount0Out, uint256 amount1Out) = (_indexFrom == USDC_INDEX)
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            // Perform a swap
            IVelodrome(_pool).swap(amount0Out, amount1Out, _recipient, bytes(""));
        } else {
            // Sanity check: should never reach this
            assert(false);
        }
        // Check output amount
        require(amountOut >= _minAmountOut, "Swap didn't result in min tokens");
    }

    /**
     * @notice Get a quote for a swap between two tokens via a given pool.
     * @param _pool         Pool to execute the swap through
     * @param _indexFrom    Index of token to sell (see _getToken())
     * @param _indexTo      Index of token to buy (see _getToken())
     * @param _amountIn     Amount of tokens to sell
     * @return amountOut    Quote for amount of tokens to buy
     */
    function _getDirectAmountOut(
        address _pool,
        uint256 _indexFrom,
        uint256 _indexTo,
        uint256 _amountIn
    ) internal view returns (uint256 amountOut) {
        // First, check input amount
        if (_amountIn == 0) return 0;
        if (_pool == SYNAPSE_NUSD_POOL) {
            // Indexes in Synapse pool match the indexes in SwapWrapper
            amountOut = ISynapse(_pool).calculateSwap(uint8(_indexFrom), uint8(_indexTo), _amountIn);
        } else if (_pool == CURVE_USDT_POOL) {
            // Get corresponding Curve indexes and get a quote
            amountOut = ICurve(_pool).get_dy(_getCurveIndex(_indexFrom), _getCurveIndex(_indexTo), _amountIn);
        } else if (_pool == VELODROME_DAI_POOL || _pool == VELODROME_SUSD_POOL) {
            // Get starting token
            IERC20 tokenFrom = _getToken(_indexFrom);
            // Get a quote
            amountOut = IVelodrome(_pool).getAmountOut(_amountIn, address(tokenFrom));
        }
        /// @dev amountOut is 0 if direct swap is not supported
    }

    /**
     * @notice Gets a token's index in the Curve DAI/USDC/USDT pool.
     * @param _tokenIndex   This contract's index of token (see _getToken())
     * @return index        Index of token in the Curve pool
     */
    function _getCurveIndex(uint256 _tokenIndex) internal pure returns (int128 index) {
        // Order of tokens in the Curve pool is DAI, USDC, USDT
        if (_tokenIndex == DAI_INDEX) {
            index = 0;
        } else if (_tokenIndex == USDC_INDEX) {
            index = 1;
        } else if (_tokenIndex == USDT_INDEX) {
            index = 2;
        } else {
            // Sanity check: should never reach this
            assert(false);
        }
    }

    /**
     * @notice Gets pool address for direct swap between two tokens.
     * @dev Returns address(0) if swap is not possible.
     * @param _indexFrom    Index of token to sell (see _getToken())
     * @param _indexTo      Index of token to buy (see _getToken())
     * @return pool         Pool address that can do tokenFrom -> tokenTo swap
     */
    function _getDirectSwap(uint256 _indexFrom, uint256 _indexTo) internal pure returns (address pool) {
        if (_indexFrom == USDC_INDEX) {
            // Get pool for USDC -> * swap
            pool = _getDirectSwapUSDC(_indexTo);
        } else if (_indexTo == USDC_INDEX) {
            // Get pool for * -> USDC swap
            pool = _getDirectSwapUSDC(_indexFrom);
        } else if (
            (_indexFrom == DAI_INDEX && _indexTo == USDT_INDEX) || (_indexFrom == USDT_INDEX && _indexTo == DAI_INDEX)
        ) {
            // DAI <-> USDT can be done via Curve pool
            pool = CURVE_USDT_POOL;
        }
        /// @dev pool is address(0) if direct swap is not supported.
    }

    /**
     * @notice Gets token represented by a given index in this contract.
     * @dev Returns address(0) if token index is out of bounds.
     * @param _tokenIndex   This contract's index of token
     * @return token        Token represented by `_tokenIndex`
     */
    function _getToken(uint256 _tokenIndex) internal pure returns (IERC20 token) {
        if (_tokenIndex == NUSD_INDEX) {
            token = NUSD;
        } else if (_tokenIndex == USDC_INDEX) {
            token = USDC;
        } else if (_tokenIndex == DAI_INDEX) {
            token = DAI;
        } else if (_tokenIndex == SUSD_INDEX) {
            token = SUSD;
        } else if (_tokenIndex == USDT_INDEX) {
            token = USDT;
        }
        /// @dev token is IERC20(address(0)) for unsupported indexes
    }

    /**
     * @notice Gets pool address for direct swap between USDC and a given token.
     * @dev Returns address(0) if swap is not possible.
     * @param _tokenIndex   Index of token to swap (see _getToken())
     * @return pool         Pool address that can do `_tokenIndex` <> USDC swap
     */
    function _getDirectSwapUSDC(uint256 _tokenIndex) internal pure returns (address pool) {
        if (_tokenIndex == NUSD_INDEX) {
            pool = SYNAPSE_NUSD_POOL;
        } else if (_tokenIndex == DAI_INDEX) {
            pool = VELODROME_DAI_POOL;
        } else if (_tokenIndex == SUSD_INDEX) {
            pool = VELODROME_SUSD_POOL;
        } else if (_tokenIndex == USDT_INDEX) {
            pool = CURVE_USDT_POOL;
        }
        /// @dev pool is address(0) if _tokenIndex is USDC, or out of range
    }
}
