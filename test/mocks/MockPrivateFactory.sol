// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PrivateFactory} from "../../contracts/concentrated/PrivateFactory.sol";
import {MockPrivatePool} from "./MockPrivatePool.sol";

/// @dev deploys the mock private pool that exposes internal functions
contract MockPrivateFactory is PrivateFactory {
    constructor(address _bridge) PrivateFactory(_bridge) {}

    /// @notice Deploys private pool for tokenA, tokenB pair owned by msg sender
    /// @param lp The address of the lp
    /// @param tokenA The address of token A
    /// @param tokenB The address of token B
    /// @param P The initial price of the pool
    /// @param fee The initial fee of the pool
    /// @param adminFee The initial admin fee of the pool
    function deployMock(
        address lp,
        address tokenA,
        address tokenB,
        uint256 P,
        uint256 fee,
        uint256 adminFee
    ) external returns (address) {
        require(tokenA != tokenB, "same token for base and quote");
        require(pool[lp][tokenA][tokenB] == address(0), "pool already exists");

        (address token0, address token1) = orderTokens(tokenA, tokenB);

        bytes32 salt = keccak256(abi.encode(lp, token0, token1));
        address p = address(new MockPrivatePool{salt: salt}(lp, token0, token1, P, fee, adminFee));
        return p;
    }
}
