// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IFrax {
    function exchangeOldForCanonical(
        address bridge_token_address,
        uint256 token_amount
    ) external returns (uint256);
}