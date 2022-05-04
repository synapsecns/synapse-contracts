// SPDX-License-Identifier: MIT 
pragma solidity 0.8.13;
contract ChainConfig {
    uint256 public MAINNET = 1; 
    uint256 public GOERLI = 5;
    uint256 public FUJI = 43113;

    address public FUJI_AUTHVERIFIER = 0xA67b7147DcE20D6F25Fd9ABfBCB1c3cA74E11f0B;
    address public GOERLI_AUTHVERIFIER = 0xA67b7147DcE20D6F25Fd9ABfBCB1c3cA74E11f0B;
    constructor() {}
}