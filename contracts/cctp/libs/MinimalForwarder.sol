// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ForwarderDeploymentFailed} from "./Errors.sol";
import {TypeCasts} from "./TypeCasts.sol";

import {Address} from "@openzeppelin/contracts-4.5.0/utils/Address.sol";

/// Minimal Forwarder is a EIP-1167 (Minimal Proxy Contract) spin-off that
/// forwards all calls to a any target address with any payload.
/// Unlike EIP-1167, delegates calls are not used, so the forwarder contract
/// is `msg.sender` as far as the target contract is concerned.
/// # Minimal Forwarder Bytecode
/// Inspired by [EIP-1167](https://eips.ethereum.org/EIPS/eip-1167).
/// Following changes were made:
/// - Target address is not saved in the deployed contract code, but is passed as a part of the payload.
/// - To forward a call, the sender needs to provide the target address as the first 32 bytes of the payload.
/// - The payload to pass to the target contract occupies the rest of the payload, having an offset of 32 bytes.
/// - The target address is derived using CALLDATALOAD.
/// - CALLVALUE is used to pass the msg.value to the target contract.
/// - `call()` is used instead of `delegatecall()`.
/// ## Bytecode Table
/// | Pos  | Opcode | Opcode + Args | Description    | Stack View                    |
/// | ---- | ------ | ------------- | -------------- | ----------------------------- |
/// | 0x00 | 0x60   | 0x6020        | push1 0x20     | 32                            |
/// | 0x02 | 0x36   | 0x36          | calldatasize   | cds 32                        |
/// | 0x03 | 0x03   | 0x03          | sub            | (cds-32)                      |
/// | 0x04 | 0x80   | 0x80          | dup1           | (cds-32) (cds-32)             |
/// | 0x05 | 0x60   | 0x6020        | push1 0x20     | 32 (cds-32) (cds-32)          |
/// | 0x07 | 0x3d   | 0x3d          | returndatasize | 0 0 (cds-32) (cds-32)         |
/// | 0x08 | 0x37   | 0x37          | calldatacopy   | (cds-32)                      |
/// | 0x09 | 0x3d   | 0x3d          | returndatasize | 0 (cds-32)                    |
/// | 0x0a | 0x3d   | 0x3d          | returndatasize | 0 0 (cds-32)                  |
/// | 0x0b | 0x3d   | 0x3d          | returndatasize | 0 0 0 (cds-32)                |
/// | 0x0c | 0x92   | 0x92          | swap3          | (cds-32) 0 0 0                |
/// | 0x0d | 0x3d   | 0x3d          | returndatasize | 0 (cds-32) 0 0 0              |
/// | 0x0e | 0x34   | 0x34          | callvalue      | val 0 (cds-32) 0 0 0          |
/// | 0x0f | 0x3d   | 0x3d          | returndatasize | 0 val 0 (cds-32) 0 0 0        |
/// | 0x10 | 0x35   | 0x35          | calldataload   | addr val 0 (cds-32) 0 0 0     |
/// | 0x11 | 0x5a   | 0x5a          | gas            | gas addr val 0 (cds-32) 0 0 0 |
/// | 0x12 | 0xf1   | 0xf1          | call           | suc 0                         |
/// | 0x13 | 0x3d   | 0x3d          | returndatasize | rds suc 0                     |
/// | 0x14 | 0x82   | 0x82          | dup3           | 0 rds suc 0                   |
/// | 0x15 | 0x80   | 0x80          | dup1           | 0 0 rds suc 0                 |
/// | 0x16 | 0x3e   | 0x3e          | returndatacopy | suc 0                         |
/// | 0x17 | 0x90   | 0x90          | swap1          | 0 suc                         |
/// | 0x18 | 0x3d   | 0x3d          | returndatasize | rds 0 suc                     |
/// | 0x19 | 0x91   | 0x91          | swap2          | suc 0 rds                     |
/// | 0x1a | 0x60   | 0x601e        | push1 0x1e     | 0x1e suc 0 rds                |
/// | 0x1c | 0x57   | 0x57          | jumpi          | 0 rds                         |
/// | 0x1d | 0xfd   | 0xfd          | revert         |                               |
/// | 0x1e | 0x5b   | 0x5b          | jumpdest       | 0 rds                         |
/// | 0x1f | 0xf3   | 0xf3          | return         |                               |
/// > - Opcode + Args refers to the bytecode of the opcode and its arguments (if there are any).
/// > - Stack View is shown after the execution of the opcode.
/// > - `cds` refers to the calldata size.
/// > - `rds` refers to the returndata size (which is zero before the first external call).
/// > - `val` refers to the provided `msg.value`.
/// > - `addr` refers to the target address loaded from calldata.
/// > - `gas` refers to the return value of the `gas()` opcode: the amount of gas left.
/// > - `suc` refers to the return value of the `call()` opcode: 0 on failure, 1 on success.
/// ## Bytecode Explanation
/// - `0x00..0x03` - Calculate the offset of the payload in the calldata (first 32 bytes is target address).
/// > - `sub` pops the top two stack items, subtracts them, and pushes the result onto the stack.
/// - `0x04..0x04` - Duplicate the offset to use it later as "payload length".
/// > - `dup1` duplicates the top stack item.
/// - `0x05..0x08` - Copy the target call payload to memory.
/// > - `calldatacopy` copies a portion of the calldata to memory. Pops three top stack elements:
/// > memory offset to write to, calldata offset to read from, and length of the data to copy.
/// - `0x09..0x11` - Prepare the stack for the `call` opcode.
/// > - We are putting an extra zero on the stack to use it later on, as `returndatacopy` will not return zero
/// > after we perform the first external call.
/// > - `swap3` swaps the top stack item with the fourth stack item.
/// > - `callvalue` pushes `msg.value` onto the stack.
/// > - `calldataload` pushes a word (32 bytes) onto the stack from calldata. Pops the calldata offset from the stack.
/// > Writes the word from calldata to the stack. We are using offset==0 to load the target address.
/// > - `gas` pushes the remaining gas onto the stack.
/// - `0x12..0x12` - Call the target contract.
/// > - `call` issues an external call to a target address.
/// > -  Pops seven top stack items: gas, target address, value, input offset, input length,
/// > memory offset to write return data to, and length of return data to write to memory.
/// > - Pushes on stack: 0 on failure, 1 on success.
/// - `0x13..0x16` - Copy the return data to memory.
/// > - `returndatasize` pushes the size of the returned data from the external call onto the stack.
/// > - `dup3` duplicates the third stack item.
/// > - `returncopydata` copies a portion of the returned data to memory. Pops three top stack elements:
/// > memory offset to write to, return data offset to read from, and length of the data to copy.
/// - `0x17..0x1b` - Prepare the stack for either revert or return: jump dst, success flag, zero, and return data size.
/// > - `swap1` swaps the top stack item with the second stack item.
/// > - `swap2` swaps the top stack item with the third stack item.
/// > - `0x1e` refers to the position of the `jumpdest` opcode.
/// >  It is used to jump to the `return` opcode, if call was successful.
/// - `0x1c..0x1c` - Jump to 0x1e position, if call was successful.
/// > - `jumpi` pops two top stack items: jump destination and jump condition.
/// > If jump condition is nonzero, jumps to the jump destination.
/// - `0x1d..0x1d` - Revert if call was unsuccessful.
/// > - `revert` pops two top stack items: memory offset to read revert message from and length of the revert message.
/// > - This allows us to bubble the revert message from the external call.
/// - `0x1e..0x1e` - Jump destination for successful call.
/// > - `jumpdest` is a no-op that marks a valid jump destination.
/// - `0x1f..0x1f` - Return if call was successful.
/// > - `return` pops two top stack items: memory offset to read return data from and length of the return data.
/// > - This allows us to reuse the return data from the external call.
/// # Minimal Forwarder Init Code
/// Inspired by [Create3 Init Code](https://github.com/0xSequence/create3/blob/master/contracts/Create3.sol).
/// Following changes were made:
/// - Adjusted bytecode length to 32 bytes.
/// - Replaced second PUSH1 opcode with RETURNDATASIZE to push 0 onto the stack.
/// > `bytecode` refers to the bytecode specified in the above table.
/// ## Init Code Table
/// | Pos  | Opcode | Opcode + Args | Description     | Stack View |
/// | ---- | ------ | ------------- | --------------- | ---------- |
/// | 0x00 | 0x7f   | 0x7fXXXX      | push32 bytecode | bytecode   |
/// | 0x1b | 0x3d   | 0x3d          | returndatasize  | 0 bytecode |
/// | 0x1c | 0x52   | 0x52          | mstore          |            |
/// | 0x1d | 0x60   | 0x6020        | push1 0x20      | 32         |
/// | 0x1f | 0x3d   | 0x3d          | returndatasize  | 0 32       |
/// | 0x20 | 0xf3   | 0xf3          | return          |            |
/// > Init Code is executed when a contract is deployed. The returned value is saved as the contract code.
/// > Therefore, the init code is constructed in such a way that it returns the Minimal Forwarder bytecode.
/// ## Init Code Explanation
/// - `0x00..0x1a` - Push the Minimal Forwarder bytecode onto the stack.
/// > - `push32` pushes 32 bytes as a single stack item onto the stack.
/// - `0x1b..0x1b` - Push 0 onto the stack.
/// > No external calls were made, so the return data size is 0.
/// - `0x1c..0x1c` - Write the Minimal Forwarder bytecode to memory.
/// > - `mstore` pops two top stack items: memory offset to write to and value to write.
/// > - Minimal Forwarder bytecode is 32 bytes long, so we need a single `mstore` to write it to memory.
/// - `0x1d..0x1f` - Prepare stack for `return` opcode.
/// > - We need to put `0 32` on the stack in order to return first 32 bytes of memory.
/// - `0x20..0x20` - Return the Minimal Forwarder bytecode.
/// > - `return` pops two top stack items: memory offset to read return data from and length of the return data.
/// > - This allows us to return the Minimal Forwarder bytecode.
library MinimalForwarderLib {
    using Address for address;
    using TypeCasts for address;
    using TypeCasts for bytes32;

    /// @notice Minimal Forwarder deployed bytecode. See the above table for more details.
    bytes internal constant FORWARDER_BYTECODE =
        hex"60_20_36_03_80_60_20_3d_37_3d_3d_3d_92_3d_34_3d_35_5a_f1_3d_82_80_3e_90_3d_91_60_1e_57_fd_5b_f3";

    /// @notice Init code to deploy a minimal forwarder contract.
    bytes internal constant FORWARDER_INIT_CODE = abi.encodePacked(hex"7f", FORWARDER_BYTECODE, hex"3d_52_60_20_3d_f3");

    /// @notice Hash of the minimal forwarder init code. Used to predict the address of a deployed forwarder.
    bytes32 internal constant FORWARDER_INIT_CODE_HASH = keccak256(FORWARDER_INIT_CODE);

    /// @notice Deploys a minimal forwarder contract using `CREATE2` with a given salt.
    /// @dev Will revert if the salt is already used.
    /// @param salt         The salt to use for the deployment
    /// @return forwarder   The address of the deployed minimal forwarder
    function deploy(bytes32 salt) internal returns (address forwarder) {
        // `bytes arr` is stored in memory in the following way
        // 1. First, uint256 arr.length is stored. That requires 32 bytes (0x20).
        // 2. Then, the array data is stored.
        bytes memory initCode = FORWARDER_INIT_CODE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Deploy the minimal forwarder with our pre-made bytecode via CREATE2.
            // We add 0x20 to get the location where the init code starts.
            forwarder := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }
        // Deploy fails if the given salt is already used.
        if (forwarder == address(0)) {
            revert ForwarderDeploymentFailed();
        }
    }

    /// @notice Forwards a call to a target address using a minimal forwarder.
    /// @dev Will bubble up any revert messages from the target.
    /// @param forwarder    The address of the minimal forwarder to use
    /// @param target       The address of the target contract to call
    /// @param payload      The payload to pass to the target contract
    /// @return returnData  The return data from the target contract
    function forwardCall(
        address forwarder,
        address target,
        bytes memory payload
    ) internal returns (bytes memory returnData) {
        // Forward a call without any ETH value
        returnData = forwardCallWithValue(forwarder, target, payload, 0);
    }

    /// @notice Forwards a call to a target address using a minimal forwarder with the given `msg.value`.
    /// @dev Will bubble up any revert messages from the target.
    /// @param forwarder    The address of the minimal forwarder to use
    /// @param target       The address of the target contract to call
    /// @param payload      The payload to pass to the target contract
    /// @param value        The amount of ETH to send with the call
    /// @return returnData  The return data from the target contract
    function forwardCallWithValue(
        address forwarder,
        address target,
        bytes memory payload,
        uint256 value
    ) internal returns (bytes memory returnData) {
        // The payload to pass to the forwarder:
        // 1. First 32 bytes is the encoded target address
        // 2. The rest is the encoded payload to pass to the target
        returnData = forwarder.functionCallWithValue(abi.encodePacked(target.addressToBytes32(), payload), value);
    }

    /// @notice Predicts the address of a minimal forwarder contract deployed using `deploy()`.
    /// @param deployer     The address of the deployer of the minimal forwarder
    /// @param salt         The salt to use for the deployment
    /// @return The predicted address of the minimal forwarder deployed with the given salt
    function predictAddress(address deployer, bytes32 salt) internal pure returns (address) {
        return keccak256(abi.encodePacked(hex"ff", deployer, salt, FORWARDER_INIT_CODE_HASH)).bytes32ToAddress();
    }
}
