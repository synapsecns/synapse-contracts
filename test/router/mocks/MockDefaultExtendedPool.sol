// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../contracts/router/interfaces/IDefaultExtendedPool.sol";

import {MockERC20} from "./MockERC20.sol";
import {MockDefaultPool, IERC20, SafeERC20} from "./MockDefaultPool.sol";

import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";

contract MockDefaultExtendedPool is MockDefaultPool, IDefaultExtendedPool {
    using SafeERC20 for IERC20;

    MockERC20 public lpToken;

    constructor(address[] memory tokens, string memory lpTokenName) MockDefaultPool(tokens) {
        lpToken = new MockERC20(lpTokenName, 18);
    }

    // ═══════════════════════════════════════════════ EXTENDED POOL ═══════════════════════════════════════════════════

    /// @notice Very basic mock of the addLiquidity function: mints LP tokens at 1:1 basis.
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256 minted) {
        require(amounts.length == _tokens.length, "ExtendedPool: !length");
        // solhint-disable-next-line not-rely-on-time
        require(deadline >= block.timestamp, "ExtendedPool: !deadline");
        for (uint256 i = 0; i < amounts.length; ++i) {
            address token = _tokens[i];
            IERC20(token).safeTransferFrom(msg.sender, address(this), amounts[i]);
            minted += amounts[i] * 10**(18 - IERC20Metadata(token).decimals());
        }
        require(minted >= minToMint, "ExtendedPool: !minToMint");
        lpToken.mint(msg.sender, minted);
    }

    ///  @notice Very basic mock of the removeLiquidityOneToken function: burns LP tokens at 1:1 basis.
    function removeLiquidityOneToken(
        uint256 lpTokenAmount,
        uint8 tokenIndex,
        uint256 minAmount,
        uint256 deadline
    ) external returns (uint256 tokenAmount) {
        require(tokenIndex < _tokens.length, "ExtendedPool: !tokenIndex");
        address token = _tokens[tokenIndex];
        // solhint-disable-next-line not-rely-on-time
        require(deadline >= block.timestamp, "ExtendedPool: !deadline");
        IERC20(address(lpToken)).safeTransferFrom(msg.sender, address(this), lpTokenAmount);
        lpToken.burn(address(this), lpTokenAmount);
        tokenAmount = lpTokenAmount / 10**(18 - IERC20Metadata(token).decimals());
        require(tokenAmount >= minAmount, "ExtendedPool: !minAmount");
        require(IERC20(token).balanceOf(address(this)) >= tokenAmount, "ExtendedPool: !balance");
        IERC20(token).safeTransfer(msg.sender, tokenAmount);
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    function swapStorage()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            address
        )
    {
        return (0, 0, 0, 0, 0, 0, address(lpToken));
    }

    function calculateAddLiquidity(uint256[] calldata amounts) external view returns (uint256) {
        require(amounts.length == _tokens.length, "ExtendedPool: !length");
        uint256 minted;
        for (uint256 i = 0; i < amounts.length; ++i) {
            minted += amounts[i] * 10**(18 - IERC20Metadata(_tokens[i]).decimals());
        }
        return minted;
    }

    function calculateRemoveLiquidityOneToken(uint256 lpTokenAmount, uint8 tokenIndex) external view returns (uint256) {
        require(tokenIndex < _tokens.length, "ExtendedPool: !tokenIndex");
        return lpTokenAmount / 10**(18 - IERC20Metadata(_tokens[tokenIndex]).decimals());
    }
}
