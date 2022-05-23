// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../../utils/Utilities.sol";

import "src-messaging/AuthVerifier.sol";
import "src-messaging/GasFeePricingUpgradeable.sol";
import "src-messaging/MessageBusUpgradeable.sol";
import "src-messaging/libraries/GasFeePricingUpdates.sol";

abstract contract GasFeePricingSetup is Test {
    struct ChainVars {
        uint256 gasTokenPrice;
        uint256 gasUnitPrice;
        uint256 gasDropMax;
        uint256 gasUnitsRcvMsg;
        uint256 minGasUsageFeeUsd;
        uint256 markupGasDrop;
        uint256 markupGasUsage;
        address gasFeePricing;
    }

    Utilities internal utils;

    AuthVerifier internal authVerifier;
    GasFeePricingUpgradeable internal gasFeePricing;
    MessageBusUpgradeable internal messageBus;

    ChainVars internal localVars;

    mapping(uint256 => ChainVars) internal remoteVars;

    uint256[] internal remoteChainIds;
    uint256 internal constant TEST_CHAINS = 5;

    address internal constant NODE = address(1337);

    // enable receiving overpaid fees
    receive() external payable {
        this;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                SETUP                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function setUp() public {
        utils = new Utilities();
        authVerifier = new AuthVerifier(NODE);

        // local gas token is worth exactly 1 USD
        localVars.gasTokenPrice = 10**18;

        MessageBusUpgradeable busImpl = new MessageBusUpgradeable();
        GasFeePricingUpgradeable pricingImpl = new GasFeePricingUpgradeable();

        messageBus = MessageBusUpgradeable(utils.deployTransparentProxy(address(busImpl)));
        gasFeePricing = GasFeePricingUpgradeable(utils.deployTransparentProxy(address(pricingImpl)));

        // I don't have extra 10M laying around, so let's initialize those proxies
        messageBus.initialize(address(gasFeePricing), address(authVerifier));
        gasFeePricing.initialize(address(messageBus), localVars.gasTokenPrice);

        remoteChainIds = new uint256[](TEST_CHAINS);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            uint256 remoteChainId = i + 1;
            remoteChainIds[i] = remoteChainId;
            address remoteGasFeePricing = utils.getNextUserAddress();
            remoteVars[remoteChainId].gasFeePricing = remoteGasFeePricing;
            gasFeePricing.setTrustedRemote(remoteChainId, utils.addressToBytes32(remoteGasFeePricing));
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          VALUES GENERATORS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _generateTestInfoValues()
        internal
        pure
        returns (uint128[] memory gasTokenPrices, uint128[] memory gasUnitPrices)
    {
        gasTokenPrices = new uint128[](TEST_CHAINS);
        gasUnitPrices = new uint128[](TEST_CHAINS);
        // 100 gwei, gasToken = $2000
        gasTokenPrices[0] = 2000 * 10**18;
        gasUnitPrices[0] = 100 * 10**9;
        // 5 gwei, gasToken = $1000
        gasTokenPrices[1] = 1000 * 10**18;
        gasUnitPrices[1] = 5 * 10**9;
        // 2000 gwei, gasToken = $0.5
        gasTokenPrices[2] = (5 * 10**18) / 10;
        gasUnitPrices[2] = 2000 * 10**9;
        // 1 gwei, gasToken = $2000
        gasTokenPrices[3] = 2000 * 10**18;
        gasUnitPrices[3] = 10**9;
        // 0.04 gwei, gasToken = $0.01
        gasTokenPrices[4] = (1 * 10**18) / 100;
        gasUnitPrices[4] = (4 * 10**9) / 100;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               CHECKERS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _checkRemoteConfig(uint256 _chainId) internal {
        (uint112 gasDropMax, uint80 gasUnitsRcvMsg, uint32 minGasUsageFeeUsd, , ) = gasFeePricing.remoteConfig(
            _chainId
        );
        assertEq(gasDropMax, remoteVars[_chainId].gasDropMax, "remoteMaxGasDrop is incorrect");
        assertEq(gasUnitsRcvMsg, remoteVars[_chainId].gasUnitsRcvMsg, "remoteGasUnitsRcvMsg is incorrect");
        assertEq(minGasUsageFeeUsd, remoteVars[_chainId].minGasUsageFeeUsd, "remoteMinGasUsageFeeUsd is incorrect");
    }

    function _checkRemoteInfo(uint256 _chainId) internal {
        (uint128 gasTokenPrice, uint128 gasUnitPrice) = gasFeePricing.remoteInfo(_chainId);
        assertEq(gasTokenPrice, remoteVars[_chainId].gasTokenPrice, "remoteGasTokenPrice is incorrect");
        assertEq(gasUnitPrice, remoteVars[_chainId].gasUnitPrice, "remoteGasUnitPrice is incorrect");
    }

    function _checkRemoteMarkups(uint256 _chainId) internal {
        (, , , uint16 markupGasDrop, uint16 markupGasUsage) = gasFeePricing.remoteConfig(_chainId);
        assertEq(markupGasDrop, remoteVars[_chainId].markupGasDrop, "remoteMarkupGasDrop is incorrect");
        assertEq(markupGasUsage, remoteVars[_chainId].markupGasUsage, "remoteMarkupGasUsage is incorrect");
    }

    function _checkLocalConfig() internal {
        (uint112 gasDropMax, uint80 gasUnitsRcvMsg, uint32 minGasUsageFeeUsd, , ) = gasFeePricing.localConfig();
        assertEq(gasDropMax, localVars.gasDropMax, "localMaxGasDrop is incorrect");
        assertEq(gasUnitsRcvMsg, localVars.gasUnitsRcvMsg, "localGasUnitsRcvMsg is incorrect");
        assertEq(minGasUsageFeeUsd, localVars.minGasUsageFeeUsd, "localMinGasUsageFeeUsd is incorrect");
    }

    function _checkLocalInfo() internal {
        (uint128 gasTokenPrice, uint128 gasUnitPrice) = gasFeePricing.localInfo();
        assertEq(gasTokenPrice, localVars.gasTokenPrice, "localGasTokenPrice is incorrect");
        assertEq(gasUnitPrice, localVars.gasUnitPrice, "gasUnitPrice is incorrect");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               SETTERS                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _setRemoteConfig(
        uint256[] memory _chainIds,
        uint112[] memory _gasDropMax,
        uint80[] memory _gasUnitsRcvMsg,
        uint32[] memory _minGasUsageFeeUsd
    ) internal {
        for (uint256 i = 0; i < _chainIds.length; ++i) {
            uint256 chainId = _chainIds[i];
            remoteVars[chainId].gasDropMax = _gasDropMax[i];
            remoteVars[chainId].gasUnitsRcvMsg = _gasUnitsRcvMsg[i];
            remoteVars[chainId].minGasUsageFeeUsd = _minGasUsageFeeUsd[i];
        }
        gasFeePricing.setRemoteConfig(_chainIds, _gasDropMax, _gasUnitsRcvMsg, _minGasUsageFeeUsd);
    }

    function _setRemoteInfo(
        uint256[] memory _chainIds,
        uint128[] memory _gasTokenPrice,
        uint128[] memory _gasUnitPrice
    ) internal {
        for (uint256 i = 0; i < _chainIds.length; ++i) {
            uint256 chainId = _chainIds[i];
            remoteVars[chainId].gasTokenPrice = _gasTokenPrice[i];
            remoteVars[chainId].gasUnitPrice = _gasUnitPrice[i];
        }
        gasFeePricing.setRemoteInfo(_chainIds, _gasTokenPrice, _gasUnitPrice);
    }

    function _setRemoteMarkups(
        uint256[] memory _chainIds,
        uint16[] memory _markupGasDrop,
        uint16[] memory _markupGasUsage
    ) internal {
        for (uint256 i = 0; i < _chainIds.length; ++i) {
            remoteVars[_chainIds[i]].markupGasDrop = _markupGasDrop[i];
            remoteVars[_chainIds[i]].markupGasUsage = _markupGasUsage[i];
        }
        gasFeePricing.setRemoteMarkups(_chainIds, _markupGasDrop, _markupGasUsage);
    }

    function _updateLocalConfig(
        uint112 _gasDropMax,
        uint80 _gasUnitsRcvMsg,
        uint32 _minGasUsageFeeUsd
    ) internal {
        localVars.gasDropMax = _gasDropMax;
        localVars.gasUnitsRcvMsg = _gasUnitsRcvMsg;
        localVars.minGasUsageFeeUsd = _minGasUsageFeeUsd;
        uint256 fee = gasFeePricing.estimateUpdateFees();
        gasFeePricing.updateLocalConfig{value: fee}(_gasDropMax, _gasUnitsRcvMsg, _minGasUsageFeeUsd);
    }

    function _updateLocalInfo(uint128 _gasTokenPrice, uint128 _gasUnitPrice) internal {
        localVars.gasTokenPrice = _gasTokenPrice;
        localVars.gasUnitPrice = _gasUnitPrice;
        uint256 fee = gasFeePricing.estimateUpdateFees();
        gasFeePricing.updateLocalInfo{value: fee}(_gasTokenPrice, _gasUnitPrice);
    }
}
