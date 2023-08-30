// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// Library for deploying contracts to the deterministic address irrespective
/// of the contract code or the constructor arguments.
/// Slightly modified version of 0xSequence Create3.sol:
/// https://github.com/0xsequence/create3/blob/master/contracts/Create3.sol
/// # Proxy Deployer Bytecode
/// No modifications from the original, just the visualization is changed.
/// - Proxy Deployer is a minimal contract that uses the passed calldata to deploy
/// the final contract using `CREATE` opcode.
/// - The resulting contract address depends on the Proxy Deployer address and its nonce,
/// and doesn't depend on the final contract code or the constructor arguments.
/// - Proxy Deployer itself is deployed using `CREATE2` opcode, therefore its address
/// can be calculated deterministically.
/// - This allows to deploy contracts to the deterministic address irrespective
/// of the contract code or the constructor arguments.
/// ## Bytecode Table
/// | Pos  | OP   | OP + Args | Description    | S2  | S1  | S0   |
/// | ---- | ---- | --------- | -------------- | --- | --- | ---- |
/// | 0x00 | 0x36 | 0x36      | calldatasize   |     |     | cds  |
/// | 0x01 | 0x3d | 0x3d      | returndatasize |     | 0   | cds  |
/// | 0x02 | 0x3d | 0x3d      | returndatasize | 0   | 0   | cds  |
/// | 0x03 | 0x37 | 0x37      | calldatacopy   |     |     |      |
/// | 0x04 | 0x36 | 0x36      | calldatasize   |     |     | cds  |
/// | 0x05 | 0x3d | 0x3d      | returndatasize |     | 0   | cds  |
/// | 0x06 | 0x34 | 0x34      | callvalue      | val | 0   | cds  |
/// | 0x07 | 0xf0 | 0xf0      | create         |     |     | addr |
/// > - Opcode + Args refers to the bytecode of the opcode and its arguments (if there are any).
/// > - Stack View (S2..S0) is shown after the execution of the opcode.
/// > - The stack elements are shown from top to bottom.
/// > Opcodes are typically dealing with the top stack elements, so they are shown first.
/// > - `cds` refers to the calldata size.
/// > - `rds` refers to the returndata size (which is zero before the first external call).
/// > - `val` refers to the provided `msg.value`.
/// > - `addr` refers to the address of the deployed contract.
/// ## Bytecode Explanation
/// - `0x00..0x02` - Prepare the stack for the `calldatacopy` operation.
/// - `0x03` - Copy the calldata (the creation code of the final contract) to memory.
/// - `0x04..0x06` - Prepare the stack for the `create` operation.
/// - `0x07` - Deploy the final contract using `CREATE` opcode.
/// ## Init Code Table
/// | Pos  | OP   | OP + Args | Description    | S1  | S0       |
/// | ---- | ---- | --------- | -------------- | --- | -------- |
/// | 0x00 | 0x67 | 0x67XXXX  | push8 bytecode |     | bytecode |
/// | 0x09 | 0x3d | 0x3d      | returndatasize | 0   | bytecode |
/// | 0x0a | 0x52 | 0x52      | mstore         |     |          |
/// | 0x0b | 0x60 | 0x6008    | push1 0x08     |     | 8        |
/// | 0x0d | 0x60 | 0x6018    | push1 0x18     | 24  | 8        |
/// | 0x0f | 0xf3 | 0xf3      | return         |     |          |
/// > Init Code is executed when a contract is deployed. The returned value is saved as the contract code.
/// > Therefore, the init code is constructed in such a way that it returns the Proxy Deployer bytecode.
/// ## Init Code Explanation
/// - `0x00..0x08` - Push the Proxy Deployer bytecode onto the stack.
/// - `0x09` - Push zero onto the stack.
/// - `0x0a` - Store the Proxy Deployer bytecode at memory position 0.
/// > Pushed value has only lower 8 bytes set, because the Proxy Deployer bytecode is 8 bytes long.
/// > Therefore, the memory offset is actually 32-8=24 bytes.
/// - `0x0b..0x0c` - Push the length of the Proxy Deployer bytecode onto the stack.
/// - `0x0d..0x0c` - Push the memory position of the Proxy Deployer bytecode onto the stack.
/// - `0x0f` - Return the Proxy Deployer bytecode.
library Create3Lib {
    error Create3__DeploymentAlreadyExists(address addr);
    error Create3__DeploymentFailed();
    error Create3__ProxyDeployerDeploymentFailed();

    /// @notice Init code to deploy a proxy deployer contract (see Init Code Table above).
    bytes internal constant DEPLOYER_INIT_CODE = hex"67_36_3d_3d_37_36_3d_34_f0_3d_52_60_08_60_18_f3";

    /// @notice Hash of the proxy deployer init code. Used to predict the address of the proxy deployer,
    /// and the address of the contract deployed by the proxy deployer.
    bytes32 internal constant DEPLOYER_INIT_CODE_HASH =
        0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;

    /// @notice Deploys a contract EIP-3171 style. The resulting contract address depends
    /// solely on the provided salt and the address of the factory that invokes this function.
    /// @dev The resulting contract address does NOT depend on the creation code of the contract,
    /// or the deployer EOA address. Make sure to both use a unique salt for each contract,
    /// as well as provide a mechanism to prevent unauthorized deploys.
    /// @param salt          Salt of the contract deployment.
    /// @param creationCode  Creation code of the contract to deploy. This is usually the
    ///                      bytecode of the contract, followed by the ABI-encoded constructor arguments.
    /// @param value         Value to send with the contract creation transaction.
    /// @return addr         Address of the deployed contract.
    function create3(
        bytes32 salt,
        bytes memory creationCode,
        uint256 value
    ) internal returns (address addr) {
        // First, check that the salt has not been used yet
        addr = predictAddress(salt);
        if (addr.code.length != 0) revert Create3__DeploymentAlreadyExists(addr);
        // `bytes initCode` is stored in memory in the following way
        // 1. First, uint256 initCode.length is stored. That requires 32 bytes (0x20).
        // 2. Then, the initCode data is stored.
        bytes memory initCode = DEPLOYER_INIT_CODE;
        // Deploy the proxy deployer contract using `CREATE2` opcode
        address proxy;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Deploy the proxy deployer with our pre-made bytecode via CREATE2.
            // We add 0x20 to get the location where the init code starts.
            proxy := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }
        // Check that the proxy deployer was deployed successfully.
        // create2 opcode does not return any error code on failure, but returns zero address instead.
        if (proxy == address(0)) revert Create3__ProxyDeployerDeploymentFailed();
        // Call the proxy deployer with the creation code of the final contract
        (bool success, ) = proxy.call{value: value}(creationCode);
        // Check that the final contract was deployed successfully.
        // Proxy Deployer is using create opcode, which does not return any error code on failure,
        // so we check the code size of the predicted address to see if the contract was deployed.
        if (!success || addr.code.length == 0) revert Create3__DeploymentFailed();
    }

    /// @notice Predicts the address of the final contract deployed using `create3`.
    /// @param salt     Salt of the contract deployment.
    /// @return Address of the contract deployed using `create3`.
    function predictAddress(bytes32 salt) internal view returns (address) {
        // Predict address of the proxy deployer contract
        // https://eips.ethereum.org/EIPS/eip-1014#specification
        address proxy = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, DEPLOYER_INIT_CODE_HASH))))
        );
        // Predict address of the contract deployed by the proxy deployer.
        // Fresh contracts have nonce = 1 (https://eips.ethereum.org/EIPS/eip-161#specification)
        // https://github.com/transmissions11/solmate/blob/main/src/utils/CREATE3.sol
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"d6_94", proxy, hex"01")))));
    }
}
