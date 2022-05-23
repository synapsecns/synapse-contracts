// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";

import "src-messaging/AuthVerifier.sol";
import "src-messaging/GasFeePricingUpgradeable.sol";
import "src-messaging/MessageBusUpgradeable.sol";
import "src-messaging/libraries/GasFeePricingUpdates.sol";

contract GasFeePricingUpgradeableTest is Test {
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

    address public constant NODE = address(1337);

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
    ▏*║                            SECURITY TESTS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function testIsInitialized() public {
        utils.checkAccess(
            address(messageBus),
            abi.encodeWithSelector(MessageBusUpgradeable.initialize.selector, address(0), address(0)),
            "Initializable: contract is already initialized"
        );

        utils.checkAccess(
            address(gasFeePricing),
            abi.encodeWithSelector(GasFeePricingUpgradeable.initialize.selector, address(0), 0, 0, 0),
            "Initializable: contract is already initialized"
        );
    }

    function testCheckAccessControl() public {
        address _gfp = address(gasFeePricing);
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setRemoteConfig.selector,
                new uint256[](1),
                new uint112[](1),
                new uint80[](1),
                new uint32[](1)
            ),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setRemoteInfo.selector,
                new uint256[](1),
                new uint128[](1),
                new uint128[](1)
            ),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setRemoteMarkups.selector,
                new uint256[](1),
                new uint16[](1),
                new uint16[](1)
            ),
            "Ownable: caller is not the owner"
        );

        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(GasFeePricingUpgradeable.updateLocalConfig.selector, 0, 0, 0),
            "Ownable: caller is not the owner"
        );

        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(GasFeePricingUpgradeable.updateLocalInfo.selector, 0, 0),
            "Ownable: caller is not the owner"
        );
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
    ▏*║                        GETTERS/SETTERS TESTS                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function testInitializedCorrectly() public {
        (uint128 _gasTokenPrice, ) = gasFeePricing.localInfo();
        assertEq(_gasTokenPrice, localVars.gasTokenPrice, "Failed to init: gasTokenPrice");
        assertEq(gasFeePricing.messageBus(), address(messageBus), "Failed to init: messageBus");
    }

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
                GasFeePricingUpgradeable.setRemoteConfig.selector,
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
            _checkRemoteRatios(chainId);
        }
    }

    function testSetRemoteInfoZeroTokenPriceReverts() public {
        (uint128[] memory gasTokenPrices, uint128[] memory gasUnitPrices) = _generateTestInfoValues();
        gasTokenPrices[2] = 0;
        utils.checkRevert(
            address(this),
            address(gasFeePricing),
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setRemoteInfo.selector,
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
            _checkRemoteRatios(chainId);
        }
    }

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
                GasFeePricingUpgradeable.updateLocalConfig.selector,
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
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkRemoteRatios(i + 1);
        }
    }

    function testUpdateLocalInfoZeroTokenPriceReverts() public {
        testSetRemoteInfo();

        uint128 gasTokenPrice = 0;
        uint128 gasUnitPrice = 10 * 10**9;

        utils.checkRevert(
            address(this),
            address(gasFeePricing),
            abi.encodeWithSelector(GasFeePricingUpgradeable.updateLocalInfo.selector, gasTokenPrice, gasUnitPrice),
            "Gas token price is not set"
        );
    }

    function testUpdateLocalInfoZeroUnitPriceSucceeds() public {
        testSetRemoteInfo();

        uint128 gasTokenPrice = 4 * 10**17;
        uint128 gasUnitPrice = 0;
        _updateLocalInfo(gasTokenPrice, gasUnitPrice);
        _checkLocalInfo();
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkRemoteRatios(i + 1);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          INTERNAL CHECKERS                           ║*▕
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

    function _checkRemoteRatios(uint256 _chainId) internal {
        (uint96 gasTokenPriceRatio, uint160 gasUnitPriceRatio) = gasFeePricing.remoteRatios(_chainId);
        uint256 _gasTokenPriceRatio = (remoteVars[_chainId].gasTokenPrice * 10**18) / localVars.gasTokenPrice;
        uint256 _gasUnitPriceRatio = (remoteVars[_chainId].gasUnitPrice * remoteVars[_chainId].gasTokenPrice * 10**18) /
            localVars.gasTokenPrice;
        assertEq(gasTokenPriceRatio, _gasTokenPriceRatio, "gasTokenPriceRatio is incorrect");
        assertEq(gasUnitPriceRatio, _gasUnitPriceRatio, "gasUnitPriceRatio is incorrect");
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
    ▏*║                           INTERNAL SETTERS                           ║*▕
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
