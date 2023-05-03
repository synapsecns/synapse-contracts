// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IAccessControl} from "@openzeppelin/contracts-4.8.0/access/IAccessControl.sol";
import {Ownable} from "@openzeppelin/contracts-4.8.0/access/Ownable.sol";

import {IPrivateFactory} from "./interfaces/IPrivateFactory.sol";
import {PrivatePool} from "./PrivatePool.sol";

/// @title Private factory for concentrated liquidity
/// @notice Deploys individual private pools owned by LPs
contract PrivateFactory is IPrivateFactory, Ownable {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public immutable bridge;
    mapping(address => mapping(address => mapping(address => address))) public pool;

    event Deploy(address indexed lp, address token0, address token1);

    constructor(address _bridge) {
        bridge = _bridge;
    }

    function orderTokens(address tokenA, address tokenB) public view returns (address token0_, address token1_) {
        // token0 (base) should be set as synX and token1 should be set as X
        // check synapse bridge has minter role on token to determine which is synX
        try IAccessControl(tokenA).hasRole(MINTER_ROLE, bridge) returns (bool has_) {
            token0_ = has_ ? tokenA : tokenB;
            token1_ = has_ ? tokenB : tokenA;
        } catch {
            token0_ = tokenB;
            token1_ = tokenA;
        }
    }

    function deploy(address tokenA, address tokenB) external {
        require(tokenA != tokenB, "same token for base and quote");
        require(pool[msg.sender][tokenA][tokenB] == address(0), "pool already exists");

        (address token0, address token1) = orderTokens(tokenA, tokenB);

        bytes32 salt = keccak256(abi.encode(msg.sender, token0, token1));
        address p = address(new PrivatePool{salt: salt}(msg.sender, token0, token1));
        pool[msg.sender][token0][token1] = p;
        pool[msg.sender][token1][token0] = p;

        emit Deploy(msg.sender, token0, token1);
    }
}
