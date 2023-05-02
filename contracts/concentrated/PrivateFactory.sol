// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts-4.8.0/access/Ownable.sol";
import {PrivatePool} from "./PrivatePool.sol";

/// @title Private factory for concentrated liquidity
/// @notice Deploys individual private pools owned by LPs
contract PrivateFactory is Ownable {
    address public immutable registry;

    mapping(address => mapping(address => mapping(address => address))) public pool;

    modifier onlySupportedToken(address token) {
        // TODO: query synX registry
        // TOD: require();
        _;
    }

    event Deploy(address indexed lp, address token0, address token1);

    constructor(address _registry) {
        registry = _registry;
    }

    function orderTokens(address tokenA, address tokenB) public returns (address token0_, address token1_) {
        // TODO: token0 (base) should be set as synX and token1 should be set as X
        token0_ = tokenA;
        token1_ = tokenB;
    }

    function deploy(address tokenA, address tokenB) external onlySupportedToken(tokenA) onlySupportedToken(tokenB) {
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
