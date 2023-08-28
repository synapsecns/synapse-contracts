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

}
