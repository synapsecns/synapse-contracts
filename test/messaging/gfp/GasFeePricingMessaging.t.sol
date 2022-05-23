// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./GasFeePricingSetup.t.sol";

contract GasFeePricingUpgradeableMessagingTest is GasFeePricingSetup {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            ENCODING TESTS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function testEncodeConfig(
        uint112 newValueA,
        uint80 newValueB,
        uint32 newValueC
    ) public {
        bytes memory message = GasFeePricingUpdates.encodeConfig(newValueA, newValueB, newValueC);
        uint8 _msgType = GasFeePricingUpdates.messageType(message);
        (uint112 _newValueA, uint80 _newValueB, uint32 _newValueC) = GasFeePricingUpdates.decodeConfig(message);
        assertEq(_msgType, uint8(GasFeePricingUpdates.MsgType.UPDATE_CONFIG), "Failed to encode msgType");
        assertEq(_newValueA, newValueA, "Failed to encode newValueA");
        assertEq(_newValueB, newValueB, "Failed to encode newValueB");
        assertEq(_newValueC, newValueC, "Failed to encode newValueC");
    }

    function testEncodeInfo(uint128 newValueA, uint128 newValueB) public {
        bytes memory message = GasFeePricingUpdates.encodeInfo(newValueA, newValueB);
        uint8 _msgType = GasFeePricingUpdates.messageType(message);
        (uint128 _newValueA, uint128 _newValueB) = GasFeePricingUpdates.decodeInfo(message);
        assertEq(_msgType, uint8(GasFeePricingUpdates.MsgType.UPDATE_INFO), "Failed to encode msgType");
        assertEq(_newValueA, newValueA, "Failed to encode newValueA");
        assertEq(_newValueB, newValueB, "Failed to encode newValueB");
    }
}
