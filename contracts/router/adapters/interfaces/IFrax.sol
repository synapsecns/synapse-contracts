// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFrax {
    // -- VIEWS --

    function canSwap(address bridgeTokenAddress) external view returns (bool);

    function exchangesPaused() external view returns (bool);

    // solhint-disable-next-line
    function fee_exempt_list(address swapper) external view returns (bool);

    // solhint-disable-next-line
    function swap_fees(address bridgeTokenAddress, uint256 direction)
        external
        view
        returns (uint256);

    // solhint-disable-next-line
    function mint_cap() external view returns (uint256);

    // -- SWAP --
    function exchangeCanonicalForOld(
        address bridgeTokenAddress,
        uint256 tokenAmount
    ) external returns (uint256 amountOut);

    function exchangeOldForCanonical(
        address bridgeTokenAddress,
        uint256 tokenAmount
    ) external returns (uint256 amountOut);
}
