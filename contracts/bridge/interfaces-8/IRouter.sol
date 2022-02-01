// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRouter {
    event Recovered(address indexed _asset, uint256 amount);

    event UpdatedTrustedTokens(address[] _newTrustedTokens);

    event UpdatedAdapters(address[] _newAdapters);

    event UpdatedMinFee(uint256 _oldMinFee, uint256 _newMinFee);

    event UpdatedFeeClaimer(address _oldFeeClaimer, address _newFeeClaimer);

    event Swap(
        address indexed _tokenIn,
        address indexed _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut
    );

    function trustedTokensCount() external view returns (uint256);
    function adaptersCount() external view returns (uint256);

    function queryAdapter(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _index
    ) external view returns (uint256);

    function swap(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address[] calldata adapters,
        address _to,
        uint256 _fee
    ) external;

    function swapFromGAS(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address[] calldata adapters,
        address _to,
        uint256 _fee
    ) external payable;

    function swapToGAS(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address[] calldata adapters,
        address _to,
        uint256 _fee
    ) external;

    function swapWithPermit(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address[] calldata adapters,
        address _to,
        uint256 _fee,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function swapToGASWithPermit(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address[] calldata adapters,
        address _to,
        uint256 _fee,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function selfSwap(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address[] calldata adapters,
        address _to,
        uint256 _fee
    ) external;

    function selfSwapFromGAS(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address[] calldata adapters,
        address _to,
        uint256 _fee
    ) external payable;

    function selfSwapToGAS(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address[] calldata adapters,
        address _to,
        uint256 _fee
    ) external;

    function swap(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address[] calldata adapters,
        address _to,
        uint256 _fee,
        bytes calldata bridgeaction
    ) external;

    function setTrustedTokens(address[] memory _trustedTokens) external;
    function setAdapters(address[] memory _adapters) external;
    function setMinFee(uint256 _fee) external;
    function setFeeClaimer(address _claimer) external;

    function recoverERC20(address _tokenAddress, uint256 _tokenAmount) external;
    function recoverGAS(uint256 _amount) external;
}
