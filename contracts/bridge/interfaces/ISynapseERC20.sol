// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ISynapseERC20 {
    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address owner
    ) external;

    function mint(address to, uint256 amount) external;
}
