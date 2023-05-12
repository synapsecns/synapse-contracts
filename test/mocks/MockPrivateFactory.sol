// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PrivateFactory} from "../../contracts/concentrated/PrivateFactory.sol";
import {MockPrivatePool} from "./MockPrivatePool.sol";

/// @dev deploys the mock private pool that exposes internal functions
contract MockPrivateFactory is PrivateFactory {
    constructor(address _bridge) PrivateFactory(_bridge) {}

    /// @notice Deploys private pool for tokenA, tokenB pair owned by msg sender
    /// @param tokenA The address of token A
    /// @param tokenB The address of token B
    function deployMock(address tokenA, address tokenB) external returns (address) {
        require(tokenA != tokenB, "same token for base and quote");
        require(pool[msg.sender][tokenA][tokenB] == address(0), "pool already exists");

        (address token0, address token1) = orderTokens(tokenA, tokenB);

        bytes32 salt = keccak256(abi.encode(msg.sender, token0, token1));
        address p = address(new MockPrivatePool{salt: salt}(msg.sender, token0, token1));
        return p;
    }
}
