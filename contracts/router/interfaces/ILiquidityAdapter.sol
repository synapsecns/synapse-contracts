// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";

interface ILiquidityAdapter {
    // -- VIEWS --
    function calculateAddLiquidity(
        IERC20[] calldata tokens,
        uint256[] calldata amountsMax
    ) external view returns (uint256 lpTokenAmount, uint256[] memory refund);

    function calculateRemoveLiquidity(IERC20 lpToken, uint256 lpTokenAmount)
        external
        view
        returns (uint256[] memory tokenAmounts);

    function calculateRemoveLiquidityOneToken(
        IERC20 lpToken,
        uint256 lpTokenAmount,
        IERC20 token
    ) external view returns (uint256 tokenAmount);

    function getTokens(IERC20 lpToken)
        external
        view
        returns (IERC20[] memory tokens);

    function getTokensDepositInfo(
        IERC20[] calldata tokens,
        uint256[] calldata amountsMax
    )
        external
        view
        returns (address liquidityDepositAddress, uint256[] memory amounts);

    function getLpTokenDepositAddress(IERC20 lpToken)
        external
        view
        returns (address liquidityDepositAddress);

    // -- INTERACTIONS --

    function addLiquidity(
        address to,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256 minLpTokensAmount
    ) external returns (uint256 lpTokenAmount);

    function removeLiquidity(
        address to,
        IERC20 lpToken,
        uint256 lpTokenAmount,
        uint256[] calldata minTokenAmounts,
        bool unwrapGas,
        IWETH9 wgas
    ) external returns (uint256[] memory tokenAmounts);

    function removeLiquidityOneToken(
        address to,
        IERC20 lpToken,
        uint256 lpTokenAmount,
        IERC20 token,
        uint256 minTokenAmount,
        bool unwrapGas,
        IWETH9 wgas
    ) external returns (uint256 tokenAmount);
}
