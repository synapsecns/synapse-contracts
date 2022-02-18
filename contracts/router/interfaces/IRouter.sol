// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    event Recovered(address indexed _asset, uint256 amount);

    event UpdatedTrustedTokens(address[] _newTrustedTokens);

    event UpdatedAdapters(address[] _newAdapters);

    event Swap(
        address indexed _tokenIn,
        address indexed _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut
    );

    function setTrustedTokens(address[] memory _trustedTokens) external;

    function setAdapters(address[] memory _adapters) external;

    function trustedTokensCount() external view returns (uint256);

    function trustedAdaptersCount() external view returns (uint256);

    function recoverERC20(address _tokenAddress) external;

    function recoverGAS() external;

    receive() external payable;

    // Bridge related functions [initial chain]

    function swapAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external;

    function swapFromGasAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external payable;

    // Bridge related functions [destination chain]

    function refundToAddress(
        address _token,
        uint256 _amount,
        address _to
    ) external;

    function selfSwap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256);

    // Single chain swaps

    function swap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256);

    function swapFromGAS(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external payable returns (uint256);

    function swapToGAS(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256);
}
