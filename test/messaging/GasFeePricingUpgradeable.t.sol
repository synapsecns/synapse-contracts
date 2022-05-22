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
        uint256 gasAmountNeeded;
        uint256 maxGasDrop;
        uint256 markupGasDrop;
        uint256 markupGasUsage;
        address gasFeePricing;
    }

    Utilities internal utils;

    AuthVerifier internal authVerifier;
    GasFeePricingUpgradeable internal gasFeePricing;
    MessageBusUpgradeable internal messageBus;

    ChainVars internal srcVars;

    mapping(uint256 => ChainVars) internal dstVars;

    uint256[] internal dstChainIds;
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

        // src gas token is worth exactly 1 USD
        srcVars.gasTokenPrice = 10**18;

        MessageBusUpgradeable busImpl = new MessageBusUpgradeable();
        GasFeePricingUpgradeable pricingImpl = new GasFeePricingUpgradeable();

        messageBus = MessageBusUpgradeable(utils.deployTransparentProxy(address(busImpl)));
        gasFeePricing = GasFeePricingUpgradeable(utils.deployTransparentProxy(address(pricingImpl)));

        // I don't have extra 10M laying around, so let's initialize those proxies
        messageBus.initialize(address(gasFeePricing), address(authVerifier));
        gasFeePricing.initialize(address(messageBus), srcVars.gasTokenPrice);

        dstChainIds = new uint256[](TEST_CHAINS);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            uint256 dstChainId = i + 1;
            dstChainIds[i] = dstChainId;
            address dstGasFeePricing = utils.getNextUserAddress();
            dstVars[dstChainId].gasFeePricing = dstGasFeePricing;
            gasFeePricing.setTrustedRemote(dstChainId, utils.addressToBytes32(dstGasFeePricing));
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
                GasFeePricingUpgradeable.setDstConfig.selector,
                new uint256[](1),
                new uint256[](1),
                new uint256[](1)
            ),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setDstInfo.selector,
                new uint256[](1),
                new uint256[](1),
                new uint256[](1)
            ),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setDstMarkups.selector,
                new uint256[](1),
                new uint16[](1),
                new uint16[](1)
            ),
            "Ownable: caller is not the owner"
        );

        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(GasFeePricingUpgradeable.setMinFee.selector, 0),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(GasFeePricingUpgradeable.setMinFeeUsd.selector, 0),
            "Ownable: caller is not the owner"
        );

        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(GasFeePricingUpgradeable.updateSrcConfig.selector, 0, 0),
            "Ownable: caller is not the owner"
        );

        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(GasFeePricingUpgradeable.updateSrcInfo.selector, 0, 0),
            "Ownable: caller is not the owner"
        );
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            ENCODING TESTS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function testEncodeDecode(
        uint8 msgType,
        uint128 newValueA,
        uint128 newValueB
    ) public {
        bytes memory message = GasFeePricingUpdates.encode(msgType, newValueA, newValueB);
        (uint8 _msgType, uint128 _newValueA, uint128 _newValueB) = GasFeePricingUpdates.decode(message);
        assertEq(_msgType, msgType, "Failed to encode msgType");
        assertEq(_newValueA, newValueA, "Failed to encode newValueA");
        assertEq(_newValueB, newValueB, "Failed to encode newValueB");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        GETTERS/SETTERS TESTS                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function testInitializedCorrectly() public {
        (uint128 _gasTokenPrice, ) = gasFeePricing.srcInfo();
        assertEq(_gasTokenPrice, srcVars.gasTokenPrice, "Failed to init: gasTokenPrice");
        assertEq(gasFeePricing.messageBus(), address(messageBus), "Failed to init: messageBus");
        _checkMinFeeUsd(10**18);
    }

    function testSetDstConfig() public {
        uint256[] memory gasAmountsNeeded = new uint256[](TEST_CHAINS);
        uint256[] memory maxGasDrops = new uint256[](TEST_CHAINS);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            gasAmountsNeeded[i] = (i + 1) * 420420;
            maxGasDrops[i] = (i + 1) * 10**18;
        }
        _setDstConfig(dstChainIds, gasAmountsNeeded, maxGasDrops);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkDstConfig(dstChainIds[i]);
        }
    }

    function testSetDstConfigZeroDropSucceeds() public {
        uint256[] memory gasAmountsNeeded = new uint256[](TEST_CHAINS);
        uint256[] memory maxGasDrops = new uint256[](TEST_CHAINS);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            gasAmountsNeeded[i] = (i + 1) * 133769;
            maxGasDrops[i] = i * 10**18;
        }
        _setDstConfig(dstChainIds, gasAmountsNeeded, maxGasDrops);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkDstConfig(dstChainIds[i]);
        }
    }

    function testSetDstConfigZeroGasReverts() public {
        uint256[] memory gasAmountsNeeded = new uint256[](TEST_CHAINS);
        uint256[] memory maxGasDrops = new uint256[](TEST_CHAINS);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            gasAmountsNeeded[i] = i * 133769;
            maxGasDrops[i] = (i + 1) * 10**18;
        }
        utils.checkRevert(
            address(this),
            address(gasFeePricing),
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setDstConfig.selector,
                dstChainIds,
                gasAmountsNeeded,
                maxGasDrops
            ),
            "Gas amount is not set"
        );
    }

    function testSetDstInfo() public {
        (uint256[] memory gasUnitPrices, uint256[] memory gasTokenPrices) = _generateTestInfoValues();
        _setDstInfo(dstChainIds, gasTokenPrices, gasUnitPrices);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            uint256 chainId = dstChainIds[i];
            _checkDstInfo(chainId);
            _checkDstRatios(chainId);
        }
    }

    function testSetDstInfoZeroTokenPriceReverts() public {
        (uint256[] memory gasTokenPrices, uint256[] memory gasUnitPrices) = _generateTestInfoValues();
        gasTokenPrices[2] = 0;
        utils.checkRevert(
            address(this),
            address(gasFeePricing),
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setDstInfo.selector,
                dstChainIds,
                gasTokenPrices,
                gasUnitPrices
            ),
            "Dst gas token price is not set"
        );
    }

    function testSetDstInfoZeroUnitPriceSucceeds() public {
        (uint256[] memory gasTokenPrices, uint256[] memory gasUnitPrices) = _generateTestInfoValues();
        gasTokenPrices[2] = 100 * 10**18;
        gasUnitPrices[3] = 0;
        _setDstInfo(dstChainIds, gasTokenPrices, gasUnitPrices);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            uint256 chainId = dstChainIds[i];
            _checkDstInfo(chainId);
            _checkDstRatios(chainId);
        }
    }

    function _generateTestInfoValues()
        internal
        pure
        returns (uint256[] memory gasTokenPrices, uint256[] memory gasUnitPrices)
    {
        gasTokenPrices = new uint256[](TEST_CHAINS);
        gasUnitPrices = new uint256[](TEST_CHAINS);
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

    function testSetDstMarkups() public {
        uint16[] memory markupsGasDrop = new uint16[](TEST_CHAINS);
        uint16[] memory markupsGasUsage = new uint16[](TEST_CHAINS);
        for (uint16 i = 0; i < TEST_CHAINS; ++i) {
            // this will set the first chain markups to [0, 0]
            markupsGasDrop[i] = i * 13;
            markupsGasUsage[i] = i * 42;
        }
        _setDstMarkups(dstChainIds, markupsGasDrop, markupsGasUsage);
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkDstMarkups(dstChainIds[i]);
        }
    }

    function testSetMinFee() public {
        uint256 minGasUsageFee = 1234567890;
        gasFeePricing.setMinFee(minGasUsageFee);
        _checkMinFee(minGasUsageFee);
    }

    function testSetMinFeeUsd(uint16 alphaUsd) public {
        uint256 minGasFeeUsageUsd = uint256(alphaUsd) * 10**16;
        gasFeePricing.setMinFeeUsd(minGasFeeUsageUsd);
        _checkMinFeeUsd(minGasFeeUsageUsd);
    }

    function testUpdateSrcConfig() public {
        uint256 gasAmountNeeded = 10**6;
        uint256 maxGasDrop = 10 * 10**18;
        _updateSrcConfig(gasAmountNeeded, maxGasDrop);
        _checkSrcConfig();
    }

    function testUpdateSrcConfigZeroDropSucceeds() public {
        uint256 gasAmountNeeded = 2 * 10**6;
        // should be able to set to zero
        uint256 maxGasDrop = 0;
        _updateSrcConfig(gasAmountNeeded, maxGasDrop);
        _checkSrcConfig();
    }

    function testUpdateSrcConfigZeroGasReverts() public {
        // should NOT be able to set to zero
        uint256 gasAmountNeeded = 0;
        uint256 maxGasDrop = 10**18;
        utils.checkRevert(
            address(this),
            address(gasFeePricing),
            abi.encodeWithSelector(GasFeePricingUpgradeable.updateSrcConfig.selector, gasAmountNeeded, maxGasDrop),
            "Gas amount is not set"
        );
    }

    function testUpdateSrcInfo() public {
        testSetDstInfo();

        uint256 gasTokenPrice = 2 * 10**18;
        uint256 gasUnitPrice = 10 * 10**9;
        _updateSrcInfo(gasTokenPrice, gasUnitPrice);
        _checkSrcInfo();
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkDstRatios(i + 1);
        }
    }

    function testUpdateSrcInfoZeroTokenPriceReverts() public {
        testSetDstInfo();

        uint256 gasTokenPrice = 0;
        uint256 gasUnitPrice = 10 * 10**9;

        utils.checkRevert(
            address(this),
            address(gasFeePricing),
            abi.encodeWithSelector(GasFeePricingUpgradeable.updateSrcInfo.selector, gasTokenPrice, gasUnitPrice),
            "Gas token price is not set"
        );
    }

    function testUpdateSrcInfoZeroUnitPriceSucceeds() public {
        testSetDstInfo();

        uint256 gasTokenPrice = 4 * 10**17;
        uint256 gasUnitPrice = 0;
        _updateSrcInfo(gasTokenPrice, gasUnitPrice);
        _checkSrcInfo();
        for (uint256 i = 0; i < TEST_CHAINS; ++i) {
            _checkDstRatios(i + 1);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          INTERNAL CHECKERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _checkDstConfig(uint256 _dstChainId) internal {
        (uint112 gasAmountNeeded, uint112 maxGasDrop, , ) = gasFeePricing.dstConfig(_dstChainId);
        assertEq(gasAmountNeeded, dstVars[_dstChainId].gasAmountNeeded, "dstGasAmountNeeded is incorrect");
        assertEq(maxGasDrop, dstVars[_dstChainId].maxGasDrop, "dstMaxGasDrop is incorrect");
    }

    function _checkDstInfo(uint256 _dstChainId) internal {
        (uint128 gasTokenPrice, uint128 gasUnitPrice) = gasFeePricing.dstInfo(_dstChainId);
        assertEq(gasTokenPrice, dstVars[_dstChainId].gasTokenPrice, "dstGasTokenPrice is incorrect");
        assertEq(gasUnitPrice, dstVars[_dstChainId].gasUnitPrice, "dstGasUnitPrice is incorrect");
    }

    function _checkDstMarkups(uint256 _dstChainId) internal {
        (, , uint16 markupGasDrop, uint16 markupGasUsage) = gasFeePricing.dstConfig(_dstChainId);
        assertEq(markupGasDrop, dstVars[_dstChainId].markupGasDrop, "dstMarkupGasDrop is incorrect");
        assertEq(markupGasUsage, dstVars[_dstChainId].markupGasUsage, "dstMarkupGasUsage is incorrect");
    }

    function _checkDstRatios(uint256 _dstChainId) internal {
        (uint96 gasTokenPriceRatio, uint160 gasUnitPriceRatio) = gasFeePricing.dstRatios(_dstChainId);
        uint256 _gasTokenPriceRatio = (dstVars[_dstChainId].gasTokenPrice * 10**18) / srcVars.gasTokenPrice;
        uint256 _gasUnitPriceRatio = (dstVars[_dstChainId].gasUnitPrice * dstVars[_dstChainId].gasTokenPrice * 10**18) /
            srcVars.gasTokenPrice;
        assertEq(gasTokenPriceRatio, _gasTokenPriceRatio, "gasTokenPriceRatio is incorrect");
        assertEq(gasUnitPriceRatio, _gasUnitPriceRatio, "gasUnitPriceRatio is incorrect");
    }

    function _checkMinFee(uint256 _expectedMinFee) internal {
        assertEq(gasFeePricing.minGasUsageFee(), _expectedMinFee, "minGasUsageFee is incorrect");
    }

    function _checkMinFeeUsd(uint256 _expectedMinFeeUsd) internal {
        uint256 _expectedMinFee = (_expectedMinFeeUsd * 10**18) / srcVars.gasTokenPrice;
        _checkMinFee(_expectedMinFee);
    }

    function _checkSrcConfig() internal {
        (uint112 gasAmountNeeded, uint112 maxGasDrop, , ) = gasFeePricing.srcConfig();
        assertEq(gasAmountNeeded, srcVars.gasAmountNeeded, "srcGasAmountNeeded is incorrect");
        assertEq(maxGasDrop, srcVars.maxGasDrop, "srcMaxGasDrop is incorrect");
    }

    function _checkSrcInfo() internal {
        (uint128 gasTokenPrice, uint128 gasUnitPrice) = gasFeePricing.srcInfo();
        assertEq(gasTokenPrice, srcVars.gasTokenPrice, "srcGasTokenPrice is incorrect");
        assertEq(gasUnitPrice, srcVars.gasUnitPrice, "gasUnitPrice is incorrect");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL SETTERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _setDstConfig(
        uint256[] memory _dstChainIds,
        uint256[] memory _gasAmountsNeeded,
        uint256[] memory _maxGasDrops
    ) internal {
        for (uint256 i = 0; i < _dstChainIds.length; ++i) {
            dstVars[_dstChainIds[i]].gasAmountNeeded = _gasAmountsNeeded[i];
            dstVars[_dstChainIds[i]].maxGasDrop = _maxGasDrops[i];
        }
        gasFeePricing.setDstConfig(_dstChainIds, _gasAmountsNeeded, _maxGasDrops);
    }

    function _setDstInfo(
        uint256[] memory _dstChainIds,
        uint256[] memory _gasTokenPrices,
        uint256[] memory _gasUnitPrices
    ) internal {
        for (uint256 i = 0; i < _dstChainIds.length; ++i) {
            dstVars[_dstChainIds[i]].gasTokenPrice = _gasTokenPrices[i];
            dstVars[_dstChainIds[i]].gasUnitPrice = _gasUnitPrices[i];
        }
        gasFeePricing.setDstInfo(_dstChainIds, _gasTokenPrices, _gasUnitPrices);
    }

    function _setDstMarkups(
        uint256[] memory _dstChainIds,
        uint16[] memory _markupsGasDrop,
        uint16[] memory _markupsGasUsage
    ) internal {
        for (uint256 i = 0; i < _dstChainIds.length; ++i) {
            dstVars[_dstChainIds[i]].markupGasDrop = _markupsGasDrop[i];
            dstVars[_dstChainIds[i]].markupGasUsage = _markupsGasUsage[i];
        }
        gasFeePricing.setDstMarkups(_dstChainIds, _markupsGasDrop, _markupsGasUsage);
    }

    function _updateSrcConfig(uint256 _gasAmountNeeded, uint256 _maxGasDrop) internal {
        srcVars.gasAmountNeeded = _gasAmountNeeded;
        srcVars.maxGasDrop = _maxGasDrop;
        uint256 fee = gasFeePricing.estimateUpdateFees();
        gasFeePricing.updateSrcConfig{value: fee}(_gasAmountNeeded, _maxGasDrop);
    }

    function _updateSrcInfo(uint256 _gasTokenPrice, uint256 _gasUnitPrice) internal {
        srcVars.gasTokenPrice = _gasTokenPrice;
        srcVars.gasUnitPrice = _gasUnitPrice;
        uint256 fee = gasFeePricing.estimateUpdateFees();
        gasFeePricing.updateSrcInfo{value: fee}(_gasTokenPrice, _gasUnitPrice);
    }
}
