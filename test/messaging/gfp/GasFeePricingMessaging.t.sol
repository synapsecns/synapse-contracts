// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./GasFeePricingSetup.t.sol";
import "src-messaging/libraries/Options.sol";

contract GasFeePricingUpgradeableMessagingTest is GasFeePricingSetup {
    event MessageSent(
        address indexed sender,
        uint256 srcChainID,
        bytes32 receiver,
        uint256 indexed dstChainId,
        bytes message,
        uint64 nonce,
        bytes options,
        uint256 fee,
        bytes32 indexed messageId
    );

    // set this to true to do fee refund test
    bool internal allowFeeRefund;

    receive() external payable override {
        // making sure that all fee calculations are correct
        // i.e. there are no fee refunds
        if (!allowFeeRefund) revert("Received ether");
    }

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

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           MESSAGING TESTS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function testSendUpdateConfig(
        uint112 _gasDropMax,
        uint80 _gasUnitsRcvMsg,
        uint32 _minGasUsageFeeUsd
    ) public {
        vm.assume(_gasUnitsRcvMsg != 0);
        _prepareSendingTests();
        uint256 totalFee = gasFeePricing.estimateUpdateFees();
        bytes memory message = GasFeePricingUpdates.encodeConfig(_gasDropMax, _gasUnitsRcvMsg, _minGasUsageFeeUsd);

        _expectMessagingEmits(message);
        // receive() is disabled, so this will also check if the totalFee is exactly the needed fee
        gasFeePricing.updateLocalConfig{value: totalFee}(_gasDropMax, _gasUnitsRcvMsg, _minGasUsageFeeUsd);
    }

    function testSendUpdateInfo(uint128 _gasTokenPrice, uint128 _gasUnitPrice) public {
        vm.assume(_gasTokenPrice != 0);
        _prepareSendingTests();
        uint256 totalFee = gasFeePricing.estimateUpdateFees();
        bytes memory message = GasFeePricingUpdates.encodeInfo(_gasTokenPrice, _gasUnitPrice);

        _expectMessagingEmits(message);
        // receive() is disabled, so this will also check if the totalFee is exactly the needed fee
        gasFeePricing.updateLocalInfo{value: totalFee}(_gasTokenPrice, _gasUnitPrice);
    }

    function testRcvUpdateConfig(
        uint8 _chainIndex,
        uint112 _gasDropMax,
        uint80 _gasUnitsRcvMsg,
        uint32 _minGasUsageFeeUsd
    ) public {
        vm.assume(_gasUnitsRcvMsg != 0);
        uint256 chainId = remoteChainIds[_chainIndex % TEST_CHAINS];
        bytes32 messageId = utils.getNextKappa();
        bytes32 srcAddress = utils.addressToBytes32(remoteVars[chainId].gasFeePricing);

        bytes memory message = GasFeePricingUpdates.encodeConfig(_gasDropMax, _gasUnitsRcvMsg, _minGasUsageFeeUsd);
        hoax(NODE);
        messageBus.executeMessage(chainId, srcAddress, address(gasFeePricing), 100000, 0, message, messageId);

        remoteVars[chainId].gasDropMax = _gasDropMax;
        remoteVars[chainId].gasUnitsRcvMsg = _gasUnitsRcvMsg;
        remoteVars[chainId].minGasUsageFeeUsd = _minGasUsageFeeUsd;
        _checkRemoteConfig(chainId);
    }

    function testRcvUpdateInfo(
        uint8 _chainIndex,
        uint128 _gasTokenPrice,
        uint128 _gasUnitPrice
    ) public {
        vm.assume(_gasTokenPrice != 0);
        uint256 chainId = remoteChainIds[_chainIndex % TEST_CHAINS];
        bytes32 messageId = utils.getNextKappa();
        bytes32 srcAddress = utils.addressToBytes32(remoteVars[chainId].gasFeePricing);

        bytes memory message = GasFeePricingUpdates.encodeInfo(_gasTokenPrice, _gasUnitPrice);
        hoax(NODE);
        messageBus.executeMessage(chainId, srcAddress, address(gasFeePricing), 100000, 0, message, messageId);

        remoteVars[chainId].gasTokenPrice = _gasTokenPrice;
        remoteVars[chainId].gasUnitPrice = _gasUnitPrice;
        _checkRemoteInfo(chainId);
    }

    function testGasDropMaxSucceeds() public {
        uint112 gasDropMax = 10**18;
        _testGasDrop(gasDropMax, gasDropMax);
    }

    function testGasDropTooBigReverts() public {
        uint112 gasDropMax = 10**18;
        _testGasDrop(gasDropMax + 1, gasDropMax);
    }

    function _testGasDrop(uint112 gasDropAmount, uint112 gasDropMax) internal {
        uint256 chainId = remoteChainIds[0];
        uint256 gasLimit = 100000;
        uint128 gasUnitPrice = 10**9;
        _setupSingleChain(chainId, gasDropMax, 0, uint128(localVars.gasTokenPrice), gasUnitPrice);
        uint256 fee = gasDropAmount + gasLimit * gasUnitPrice;

        bytes32 receiver = keccak256("Not a fake address");

        bytes memory options = Options.encode(100000, gasDropAmount, receiver);

        if (gasDropAmount > gasDropMax) {
            vm.expectRevert("GasDrop higher than max");
        }

        messageBus.sendMessage{value: fee}(receiver, chainId, bytes(""), options);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _setupSingleChain(
        uint256 _chainId,
        uint112 _gasDropMax,
        uint32 _minGasUsageFeeUsd,
        uint128 _gasTokenPrice,
        uint128 _gasUnitPrice
    ) internal {
        uint256[] memory chainIds = new uint256[](1);
        uint112[] memory gasDropMax = new uint112[](1);
        uint80[] memory gasUnitsRcvMsg = new uint80[](1);
        uint32[] memory minGasUsageFeeUsd = new uint32[](1);

        chainIds[0] = _chainId;
        gasDropMax[0] = _gasDropMax;
        gasUnitsRcvMsg[0] = 100000;
        minGasUsageFeeUsd[0] = _minGasUsageFeeUsd;
        _setRemoteConfig(chainIds, gasDropMax, gasUnitsRcvMsg, minGasUsageFeeUsd);

        uint128[] memory gasTokenPrice = new uint128[](1);
        uint128[] memory gasUnitPrice = new uint128[](1);
        gasTokenPrice[0] = _gasTokenPrice;
        gasUnitPrice[0] = _gasUnitPrice;
        _setRemoteInfo(chainIds, gasTokenPrice, gasUnitPrice);
    }

    function _expectMessagingEmits(bytes memory message) internal {
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            uint256 chainId = remoteChainIds[i];
            bytes memory options = Options.encode(remoteVars[chainId].gasUnitsRcvMsg);
            uint256 fee = messageBus.estimateFee(chainId, options);
            bytes32 receiver = utils.addressToBytes32(remoteVars[chainId].gasFeePricing);
            uint64 nonce = uint64(i);
            bytes32 messageId = messageBus.computeMessageId(
                address(gasFeePricing),
                block.chainid,
                receiver,
                chainId,
                nonce,
                message
            );

            vm.expectEmit(true, true, true, true);
            emit MessageSent(
                address(gasFeePricing),
                block.chainid,
                receiver,
                chainId,
                message,
                nonce,
                options,
                fee,
                messageId
            );
        }
    }

    function _prepareSendingTests() internal {
        (uint128[] memory gasTokenPrices, uint128[] memory gasUnitPrices) = _generateTestInfoValues();
        _setRemoteInfo(remoteChainIds, gasTokenPrices, gasUnitPrices);

        uint112[] memory gasDropMax = new uint112[](TEST_CHAINS);
        uint80[] memory gasUnitsRcvMsg = new uint80[](TEST_CHAINS);
        uint32[] memory minGasUsageFeeUsd = new uint32[](TEST_CHAINS);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            gasDropMax[i] = 0;
            gasUnitsRcvMsg[i] = uint80((i + 1) * 105000);
            minGasUsageFeeUsd[i] = 0;
        }
        _setRemoteConfig(remoteChainIds, gasDropMax, gasUnitsRcvMsg, minGasUsageFeeUsd);
    }
}
