// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ITokenMinter} from "../../../contracts/cctp/interfaces/ITokenMinter.sol";
import {IMintBurnToken} from "../../../contracts/cctp/interfaces/IMintBurnToken.sol";

contract MockTokenMinter is ITokenMinter {
    mapping(uint32 => mapping(bytes32 => address)) internal localTokens;
    address public localTokenMessenger;
    mapping(address => uint256) public burnLimitsPerMessage;

    constructor(address localTokenMessenger_) {
        localTokenMessenger = localTokenMessenger_;
    }

    function setLocalToken(
        uint32 remoteDomain,
        bytes32 remoteToken,
        address localToken
    ) external {
        localTokens[remoteDomain][remoteToken] = localToken;
    }

    function setBurnLimitPerMessage(address token, uint256 limit) external {
        burnLimitsPerMessage[token] = limit;
    }

    function mint(
        uint32 sourceDomain,
        bytes32 burnToken,
        address to,
        uint256 amount
    ) external returns (address mintToken) {
        require(msg.sender == localTokenMessenger, "Caller not local TokenMessenger");
        mintToken = localTokens[sourceDomain][burnToken];
        require(mintToken != address(0), "Mint token not supported");
        IMintBurnToken(mintToken).mint(to, amount);
    }

    function burn(address burnToken, uint256 amount) external {
        require(msg.sender == localTokenMessenger, "Caller not local TokenMessenger");
        IMintBurnToken(burnToken).burn(amount);
    }

    function getLocalToken(uint32 remoteDomain, bytes32 remoteToken) external view returns (address) {
        return localTokens[remoteDomain][remoteToken];
    }
}
