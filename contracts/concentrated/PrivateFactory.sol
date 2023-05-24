// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IAccessControl} from "@openzeppelin/contracts-4.8.0/access/IAccessControl.sol";

import {IPrivateFactory} from "./interfaces/IPrivateFactory.sol";
import {IPrivatePool} from "./interfaces/IPrivatePool.sol";
import {PrivatePool} from "./PrivatePool.sol";

/// @title Private factory for concentrated liquidity
/// @notice Deploys individual private pools owned by LPs
contract PrivateFactory is IPrivateFactory {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public immutable bridge;

    address public owner;
    mapping(address => mapping(address => mapping(address => address))) public pool;

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    event Deploy(address indexed lp, address token0, address token1, address poolAddress);
    event NewOwner(address newOwner);

    constructor(address _bridge) {
        owner = msg.sender;
        bridge = _bridge;
    }

    /// @notice Orders token addresses such that synthetic bridge token set as token0 (base) and underlying as token1 (quote)
    /// @param tokenA The address of token A
    /// @param tokenB The address of token B
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

    /// @notice Deploys private pool for tokenA, tokenB pair owned by msg sender
    /// @param tokenA The address of token A
    /// @param tokenB The address of token B
    function deploy(address tokenA, address tokenB) external returns (address) {
        require(tokenA != tokenB, "same token for base and quote");
        require(pool[msg.sender][tokenA][tokenB] == address(0), "pool already exists");

        (address token0, address token1) = orderTokens(tokenA, tokenB);

        bytes32 salt = keccak256(abi.encode(msg.sender, token0, token1));
        address p = address(new PrivatePool{salt: salt}(msg.sender, token0, token1));
        pool[msg.sender][token0][token1] = p;
        pool[msg.sender][token1][token0] = p;

        emit Deploy(msg.sender, token0, token1, p);

        return p;
    }

    /// @notice Sets the admin fee charged on swaps for given (lp, tokenA, tokenB) pool
    /// @param lp The address of the pool owner
    /// @param tokenA The address of token A
    /// @param tokenB The address of token B
    /// @param fee The new admin fee
    // TODO: test
    function setAdminFeeOnPool(
        address lp,
        address tokenA,
        address tokenB,
        uint256 fee
    ) external onlyOwner {
        address p = pool[lp][tokenA][tokenB];
        require(p != address(0), "!pool");
        IPrivatePool(p).setAdminFee(fee);
    }

    /// @notice Skims fees from pool to factory owner
    /// @param lp The address of the pool owner
    /// @param tokenA The address of token A
    /// @param tokenB The address of token B
    // TODO: test
    function skimPool(
        address lp,
        address tokenA,
        address tokenB
    ) external onlyOwner {
        address p = pool[lp][tokenA][tokenB];
        require(p != address(0), "!pool");
        IPrivatePool(p).skim(owner);
    }

    /// @notice Updates the owner admin address for the factory
    /// @param _owner The new owner
    function setOwner(address _owner) external onlyOwner {
        require(_owner != owner, "same owner");
        owner = _owner;
        emit NewOwner(_owner);
    }
}
