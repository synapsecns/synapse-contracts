// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IMintBurnWrapper {
    // -- VIEWS --

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function nativeToken() external view returns (address);

    // -- STATE CHANGING --

    function approve(address spender, uint256 amount) external returns (bool);

    function burnFrom(address account, uint256 amount) external;

    function mint(address to, uint256 amount) external;

    function transfer(address to, uint256 amount) external;
}
