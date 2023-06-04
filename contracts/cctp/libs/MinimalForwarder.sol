// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ForwarderDeploymentFailed} from "./Errors.sol";
import {TypeCasts} from "./TypeCasts.sol";

import {Address} from "@openzeppelin/contracts-4.5.0/utils/Address.sol";

/// # Minimal Forwarder Bytecode
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
/// # Minimal Forwarder Init Code
/// | Pos  | Opcode | Opcode + Args | Description     | Stack View |
/// | ---- | ------ | ------------- | --------------- | ---------- |
/// | 0x00 | 0x7F   | 0x7FXXXX      | push32 bytecode | bytecode   |
/// | 0x1b | 0x3d   | 0x3d          | returndatasize  | 0 bytecode |
/// | 0x1c | 0x52   | 0x52          | mstore          |            |
/// | 0x1d | 0x60   | 0x6020        | push1 0x20      | 32         |
/// | 0x1f | 0x3d   | 0x3d          | returndatasize  | 0 32       |
/// | 0x20 | 0xf3   | 0xf3          | return          |            |
library MinimalForwarderLib {
    using Address for address;
    using TypeCasts for address;
    using TypeCasts for bytes32;

    bytes internal constant FORWARDER_BYTECODE =
        hex"60_20_36_03_80_60_20_3d_37_3d_3d_3d_92_3d_34_3d_35_5a_f1_3d_82_80_3e_90_3d_91_60_1e_57_fd_5b_f3";

    bytes internal constant FORWARDER_INIT_CODE = abi.encodePacked(hex"7f", FORWARDER_BYTECODE, hex"3d_52_60_20_3d_f3");

    bytes32 internal constant FORWARDER_INIT_CODE_HASH = keccak256(FORWARDER_INIT_CODE);

    /// @notice Deploys a minimal forwarder contract using `CREATE2` with a given salt.
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
        // The payload to pass to the forwarder:
        // 1. First 32 bytes is the encoded target address
        // 2. The rest is the encoded payload to pass to the target
        returnData = forwarder.functionCall(abi.encodePacked(target.addressToBytes32(), payload));
    }

    /// @notice Predicts the address of a minimal forwarder contract deployed using `deploy()`.
    function predictAddress(address deployer, bytes32 salt) internal pure returns (address) {
        return keccak256(abi.encodePacked(hex"ff", deployer, salt, FORWARDER_INIT_CODE_HASH)).bytes32ToAddress();
    }
}
