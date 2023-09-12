// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/IERC20.sol";

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";
import {ILBRouter} from "../../../interfaces/traderjoe/ILBRouter.sol";
import {UniversalTokenLib} from "../../../libs/UniversalToken.sol";

import {OnlyDelegateCall} from "../OnlyDelegateCall.sol";

/// @notice PoolModule for Trader Joe LBPairs
/// @dev Implements IPoolModule interface to be used with pools added to LinkedPool router
abstract contract TraderJoeModule is OnlyDelegateCall, IPoolModule {
    using UniversalTokenLib for address;

    ILBRouter public immutable lbRouter;

    constructor(address _lbRouter) {
        lbRouter = ILBRouter(_lbRouter);
    }

    /// @notice Trader Joe LBPair version this module accommodates
    function version() public pure virtual returns (ILBRouter.Version);

    /// @notice Bin step for the given pool and version this module accommodates
    function _binStep(address pool) internal view virtual returns (uint256);

    /// @inheritdoc IPoolModule
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        assertDelegateCall();
        address tokenIn = tokenFrom.token;
        tokenIn.universalApproveInfinity(address(lbRouter), amountIn);

        /// @dev https://docs.traderjoexyz.com/guides/swap-tokens#code-examples
        IERC20[] memory tokenPath = new IERC20[](2);
        tokenPath[0] = IERC20(tokenIn);
        tokenPath[1] = IERC20(tokenTo.token);

        uint256[] memory pairBinSteps = new uint256[](1);
        pairBinSteps[0] = _binStep(pool);

        ILBRouter.Version[] memory versions = new ILBRouter.Version[](1);
        versions[0] = version();

        ILBRouter.Path memory path = ILBRouter.Path({
            pairBinSteps: pairBinSteps,
            versions: versions,
            tokenPath: tokenPath
        });

        amountOut = lbRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            path: path,
            to: address(this),
            deadline: block.timestamp
        });
    }

    /// @inheritdoc IPoolModule
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) public view virtual returns (uint256 amountOut);

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) public view virtual returns (address[] memory tokens);
}
