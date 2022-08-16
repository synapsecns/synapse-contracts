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

    /// @notice USDC index, important because all multi swaps are routed through USDC
    uint256 internal constant USDC_INDEX = 1;
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
        // We don't need DAI approval, as we don't use Curve pool for DAI swaps
        USDC.safeApprove(CURVE_USDT_POOL, MAX_UINT);
        USDT.safeApprove(CURVE_USDT_POOL, MAX_UINT);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          EXTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

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
        if (tokenIndexFrom == USDC_INDEX || tokenIndexTo == USDC_INDEX) {
            amountOut = _directSwap(tokenIndexFrom, tokenIndexTo, dx, minDy, msg.sender);
        } else {
            // First, perform tokenFrom -> USDC swap, recipient is this contract
            // Don't check minAmountOut
            amountOut = _directSwap(tokenIndexFrom, USDC_INDEX, dx, 0, address(this));
            // Then, perform USDC -> tokenTo swap, recipient is the user
            // Check minAmountOut
            amountOut = _directSwap(USDC_INDEX, tokenIndexTo, amountOut, minDy, msg.sender);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut) {
        if (tokenIndexFrom == tokenIndexTo) return 0;
        // Check if direct swap is possible
        if (tokenIndexFrom == USDC_INDEX || tokenIndexTo == USDC_INDEX) {
            amountOut = _getDirectAmountOut(tokenIndexFrom, tokenIndexTo, dx);
        } else {
            // First, get tokenFrom -> USDC quote
            amountOut = _getDirectAmountOut(tokenIndexFrom, USDC_INDEX, dx);
            // Then, get USDC -> tokenTo quote
            amountOut = _getDirectAmountOut(USDC_INDEX, tokenIndexTo, amountOut);
        }
    }

    function getToken(uint8 index) external pure returns (IERC20 token) {
        token = _getToken(index);
        require(address(token) != address(0), "Out of range");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          INTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _directSwap(
        uint256 _indexFrom,
        uint256 _indexTo,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _recipient
    ) internal returns (uint256 amountOut) {
        // Get swap pool for a direct trade
        address pool = _getPoolAddress(_indexFrom, _indexTo);
        require(pool != address(0), "Swap not supported");
        if (pool == SYNAPSE_NUSD_POOL) {
            // Indexes in Synapse pool match the indexes in SwapWrapper
            // solhint-disable-next-line not-rely-on-time
            amountOut = ISynapse(pool).swap(uint8(_indexFrom), uint8(_indexTo), _amountIn, 0, block.timestamp);
            // Transfer tokens to recipient, if needed
            if (_recipient != address(this)) {
                _getToken(_indexTo).safeTransfer(_recipient, amountOut);
            }
        } else if (pool == CURVE_USDT_POOL) {
            // Get corresponding Curve indexes and perform a swap
            amountOut = ICurve(pool).exchange(
                _getCurveIndex(_indexFrom),
                _getCurveIndex(_indexTo),
                _amountIn,
                0,
                _recipient
            );
        } else if (pool == VELODROME_DAI_POOL || pool == VELODROME_SUSD_POOL) {
            // Get starting token
            IERC20 tokenFrom = _getToken(_indexFrom);
            // Get a quote
            amountOut = IVelodrome(pool).getAmountOut(_amountIn, address(tokenFrom));
            // Transfer starting token to Pair contract
            tokenFrom.safeTransfer(address(pool), _amountIn);
            // USDC is token0 in both USDC/DAI and USDC/sUSD pool,
            // because USDC address is lexicographically smaller
            (uint256 amount0Out, uint256 amount1Out) = (_indexFrom == USDC_INDEX)
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            // Perform a swap
            IVelodrome(pool).swap(amount0Out, amount1Out, _recipient, bytes(""));
        } else {
            // Sanity check: should never reach this
            assert(false);
        }
        // Check output amount
        require(amountOut >= _minAmountOut, "Swap didn't result in min tokens");
    }

    function _getDirectAmountOut(
        uint256 _indexFrom,
        uint256 _indexTo,
        uint256 _amountIn
    ) internal view returns (uint256 amountOut) {
        // First, check input amount
        if (_amountIn == 0) return 0;
        // Then get swap pool for a direct trade
        address pool = _getPoolAddress(_indexFrom, _indexTo);
        if (pool == SYNAPSE_NUSD_POOL) {
            // Indexes in Synapse pool match the indexes in SwapWrapper
            amountOut = ISynapse(pool).calculateSwap(uint8(_indexFrom), uint8(_indexTo), _amountIn);
        } else if (pool == CURVE_USDT_POOL) {
            // Get corresponding Curve indexes and get a quote
            amountOut = ICurve(pool).get_dy(_getCurveIndex(_indexFrom), _getCurveIndex(_indexTo), _amountIn);
        } else if (pool == VELODROME_DAI_POOL || pool == VELODROME_SUSD_POOL) {
            // Get starting token
            IERC20 tokenFrom = _getToken(_indexFrom);
            // Get a quote
            amountOut = IVelodrome(pool).getAmountOut(_amountIn, address(tokenFrom));
        }
        /// @dev amountOut is 0 if direct swap is not supported
    }

    function _getCurveIndex(uint256 _tokenIndex) internal pure returns (int128 index) {
        if (_tokenIndex == 2) {
            // DAI
            index = 0;
        } else if (_tokenIndex == 1) {
            // USDC
            index = 1;
        } else if (_tokenIndex == 4) {
            // USDT
            index = 2;
        } else {
            // return -1 for unsupported token index
            index = -1;
        }
    }

    /// @dev Gets pool address for direct swap between two tokens.
    function _getPoolAddress(uint256 _indexFrom, uint256 _indexTo) internal pure returns (address pool) {
        if (_indexFrom == USDC_INDEX) {
            pool = _getTokenPoolAddress(_indexTo);
        } else if (_indexTo == USDC_INDEX) {
            pool = _getTokenPoolAddress(_indexFrom);
        }
        /// @dev pool is address(0) if neither of tokens is USDC.
    }

    function _getToken(uint256 _tokenIndex) internal pure returns (IERC20 token) {
        if (_tokenIndex == 0) {
            token = NUSD;
        } else if (_tokenIndex == 1) {
            token = USDC;
        } else if (_tokenIndex == 2) {
            token = DAI;
        } else if (_tokenIndex == 3) {
            token = SUSD;
        } else if (_tokenIndex == 4) {
            token = USDT;
        }
        /// @dev token is IERC20(address(0)) for unsupported indexes
    }

    /// @dev Gets pool address for direct swap between USDC and other token.
    function _getTokenPoolAddress(uint256 _tokenIndex) internal pure returns (address pool) {
        if (_tokenIndex == 0) {
            pool = SYNAPSE_NUSD_POOL;
        } else if (_tokenIndex == 2) {
            pool = VELODROME_DAI_POOL;
        } else if (_tokenIndex == 3) {
            pool = VELODROME_SUSD_POOL;
        } else if (_tokenIndex == 4) {
            pool = CURVE_USDT_POOL;
        }
        /// @dev pool is address(0) if _tokenIndex is USDC, or out of range
    }
}
