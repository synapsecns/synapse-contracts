// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./GasFeePricingSetup.t.sol";

contract GasFeePricingUpgradeableSettersTest is GasFeePricingSetup {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        GETTERS/SETTERS TESTS                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function testSetRemoteConfig() public {
        uint112[] memory gasDropMax = new uint112[](TEST_CHAINS);
        uint80[] memory gasUnitsRcvMsg = new uint80[](TEST_CHAINS);
        uint32[] memory minGasUsageFeeUsd = new uint32[](TEST_CHAINS);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            gasDropMax[i] = uint112((i + 1) * 10**18);
            gasUnitsRcvMsg[i] = uint80((i + 1) * 420420);
            minGasUsageFeeUsd[i] = uint32((i + 1) * 10000);
        }
        _setRemoteConfig(remoteChainIds, gasDropMax, gasUnitsRcvMsg, minGasUsageFeeUsd);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkRemoteConfig(remoteChainIds[i]);
        }
    }

    function testSetRemoteConfigZeroDropSucceeds() public {
        uint112[] memory gasDropMax = new uint112[](TEST_CHAINS);
        uint80[] memory gasUnitsRcvMsg = new uint80[](TEST_CHAINS);
        uint32[] memory minGasUsageFeeUsd = new uint32[](TEST_CHAINS);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            gasDropMax[i] = uint112(i * 10**17);
            gasUnitsRcvMsg[i] = uint80((i + 1) * 133769);
            minGasUsageFeeUsd[i] = uint32((i + 1) * 1000);
        }
        _setRemoteConfig(remoteChainIds, gasDropMax, gasUnitsRcvMsg, minGasUsageFeeUsd);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkRemoteConfig(remoteChainIds[i]);
        }
    }

    function testSetRemoteConfigZeroFeeSucceeds() public {
        uint112[] memory gasDropMax = new uint112[](TEST_CHAINS);
        uint80[] memory gasUnitsRcvMsg = new uint80[](TEST_CHAINS);
        uint32[] memory minGasUsageFeeUsd = new uint32[](TEST_CHAINS);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            gasDropMax[i] = uint112((i + 1) * 10**16);
            gasUnitsRcvMsg[i] = uint80((i + 1) * 696969);
            minGasUsageFeeUsd[i] = uint32(i * 5000);
        }
        _setRemoteConfig(remoteChainIds, gasDropMax, gasUnitsRcvMsg, minGasUsageFeeUsd);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkRemoteConfig(remoteChainIds[i]);
        }
    }

    function testSetRemoteConfigZeroGasReverts() public {
        uint112[] memory gasDropMax = new uint112[](TEST_CHAINS);
        uint80[] memory gasUnitsRcvMsg = new uint80[](TEST_CHAINS);
        uint32[] memory minGasUsageFeeUsd = new uint32[](TEST_CHAINS);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            gasDropMax[i] = uint112((i + 1) * 10**15);
            gasUnitsRcvMsg[i] = uint80(i * 123456);
            minGasUsageFeeUsd[i] = uint32((i + 1) * 5000);
        }
        utils.checkRevert(
            address(this),
            address(gasFeePricing),
            abi.encodeWithSelector(
                MessageExecutorUpgradeable.setRemoteConfig.selector,
                remoteChainIds,
                gasDropMax,
                gasUnitsRcvMsg,
                minGasUsageFeeUsd
            ),
            "Gas amount is not set"
        );
    }

    function testSetRemoteInfo() public {
        (uint128[] memory gasTokenPrices, uint128[] memory gasUnitPrices) = _generateTestInfoValues();
        _setRemoteInfo(remoteChainIds, gasTokenPrices, gasUnitPrices);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            uint256 chainId = remoteChainIds[i];
            _checkRemoteInfo(chainId);
        }
    }

    function testSetRemoteInfoZeroTokenPriceReverts() public {
        (uint128[] memory gasTokenPrices, uint128[] memory gasUnitPrices) = _generateTestInfoValues();
        gasTokenPrices[2] = 0;
        utils.checkRevert(
            address(this),
            address(gasFeePricing),
            abi.encodeWithSelector(
                MessageExecutorUpgradeable.setRemoteInfo.selector,
                remoteChainIds,
                gasTokenPrices,
                gasUnitPrices
            ),
            "Remote gas token price is not set"
        );
    }

    function testSetRemoteInfoZeroUnitPriceSucceeds() public {
        (uint128[] memory gasTokenPrices, uint128[] memory gasUnitPrices) = _generateTestInfoValues();
        gasTokenPrices[2] = 100 * 10**18;
        gasUnitPrices[3] = 0;
        _setRemoteInfo(remoteChainIds, gasTokenPrices, gasUnitPrices);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            uint256 chainId = remoteChainIds[i];
            _checkRemoteInfo(chainId);
        }
    }

    function testSetRemoteMarkups() public {
        uint16[] memory markupGasDrop = new uint16[](TEST_CHAINS);
        uint16[] memory markupGasUsage = new uint16[](TEST_CHAINS);
        for (uint16 i = 0; i < TEST_CHAINS; ++i) {
            // this will set the first chain markups to [0, 0]
            markupGasDrop[i] = i * 13;
            markupGasUsage[i] = i * 42;
        }
        _setRemoteMarkups(remoteChainIds, markupGasDrop, markupGasUsage);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkRemoteMarkups(remoteChainIds[i]);
        }
    }

    function testUpdateLocalConfig() public {
        uint112 gasDropMax = 10 * 10**18;
        uint80 gasUnitsRcvMsg = 10**6;
        uint32 minGasUsageFeeUsd = 10**4;

        _updateLocalConfig(gasDropMax, gasUnitsRcvMsg, minGasUsageFeeUsd);
        _checkLocalConfig();
    }

    function testUpdateLocalConfigZeroDropSucceeds() public {
        // should be able to set to zero
        uint112 gasDropMax = 0;
        uint80 gasUnitsRcvMsg = 2 * 10**6;
        uint32 minGasUsageFeeUsd = 2 * 10**4;
        _updateLocalConfig(gasDropMax, gasUnitsRcvMsg, minGasUsageFeeUsd);
        _checkLocalConfig();
    }

    function testUpdateLocalConfigZeroFeeSucceeds() public {
        uint112 gasDropMax = 5 * 10**18;
        uint80 gasUnitsRcvMsg = 2 * 10**6;
        // should be able to set to zero
        uint32 minGasUsageFeeUsd = 0;
        _updateLocalConfig(gasDropMax, gasUnitsRcvMsg, minGasUsageFeeUsd);
        _checkLocalConfig();
    }

    function testUpdateLocalConfigZeroGasReverts() public {
        uint112 gasDropMax = 10**18;
        // should NOT be able to set to zero
        uint80 gasUnitsRcvMsg = 0;
        uint32 minGasUsageFeeUsd = 3 * 10**4;

        utils.checkRevert(
            address(this),
            address(gasFeePricing),
            abi.encodeWithSelector(
                MessageExecutorUpgradeable.updateLocalConfig.selector,
                gasDropMax,
                gasUnitsRcvMsg,
                minGasUsageFeeUsd
            ),
            "Gas amount is not set"
        );
    }

    function testUpdateLocalInfo() public {
        testSetRemoteInfo();

        uint128 gasTokenPrice = 2 * 10**18;
        uint128 gasUnitPrice = 10 * 10**9;
        _updateLocalInfo(gasTokenPrice, gasUnitPrice);
        _checkLocalInfo();
    }

    function testUpdateLocalInfoZeroTokenPriceReverts() public {
        testSetRemoteInfo();

        uint128 gasTokenPrice = 0;
        uint128 gasUnitPrice = 10 * 10**9;

        utils.checkRevert(
            address(this),
            address(gasFeePricing),
            abi.encodeWithSelector(MessageExecutorUpgradeable.updateLocalInfo.selector, gasTokenPrice, gasUnitPrice),
            "Gas token price is not set"
        );
    }

    function testUpdateLocalInfoZeroUnitPriceSucceeds() public {
        testSetRemoteInfo();

        uint128 gasTokenPrice = 4 * 10**17;
        uint128 gasUnitPrice = 0;
        _updateLocalInfo(gasTokenPrice, gasUnitPrice);
        _checkLocalInfo();
    }
}
