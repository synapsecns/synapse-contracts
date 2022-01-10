// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IRouter { 

  struct Trade {
        uint256 amountIn;
        uint256 amountOut;
        address[] path;
        address[] adapters;
  }

  function selfSwap(
        Trade calldata _trade,
        address _to,
        uint256 _fee
    ) external;
}