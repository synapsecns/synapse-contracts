// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";

import "src-messaging/AuthVerifier.sol";
import "src-messaging/GasFeePricingUpgradeable.sol";
import "src-messaging/MessageBusUpgradeable.sol";

contract GasFeePricingUpgradeableTest is Test {
    struct ChainVars {
        uint256 gasTokenPrice;
        uint256 gasUnitPrice;
        uint256 gasAmountNeeded;
        uint256 maxGasDrop;
        address gasFeePricing;
    }

    Utilities internal utils;

    AuthVerifier internal authVerifier;
    GasFeePricingUpgradeable internal gasFeePricing;
    MessageBusUpgradeable internal messageBus;

    ChainVars internal srcVars;

    uint128 internal markupGasDrop;
    uint128 internal markupGasUsage;

    mapping(uint256 => ChainVars) internal dstVars;

    address public constant NODE = address(1337);

    // enable receiving overpaid fees
    receive() external payable {
        this;
    }

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                                SETUP                                 │
      └──────────────────────────────────────────────────────────────────────┘*/

    function setUp() public {
        utils = new Utilities();
        authVerifier = new AuthVerifier(NODE);

        srcVars.gasTokenPrice = 10**18;
        markupGasDrop = 150;
        markupGasUsage = 200;

        MessageBusUpgradeable busImpl = new MessageBusUpgradeable();
        GasFeePricingUpgradeable pricingImpl = new GasFeePricingUpgradeable();

        messageBus = MessageBusUpgradeable(utils.deployTransparentProxy(address(busImpl)));
        gasFeePricing = GasFeePricingUpgradeable(utils.deployTransparentProxy(address(pricingImpl)));

        // I don't have extra 10M laying around, so let's initialize those proxies
        messageBus.initialize(address(gasFeePricing), address(authVerifier));
        gasFeePricing.initialize(address(messageBus), srcVars.gasTokenPrice, markupGasDrop, markupGasUsage);
    }

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                            SECURITY TESTS                            │
      └──────────────────────────────────────────────────────────────────────┘*/

    function testInitialized() public {
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
            abi.encodeWithSelector(GasFeePricingUpgradeable.setCostPerChain.selector, 0, 0, 0),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setCostPerChains.selector,
                new uint256[](1),
                new uint256[](1),
                new uint256[](1)
            ),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(GasFeePricingUpgradeable.setDstChainConfig.selector, 0, 0, 0),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setDstChainConfigs.selector,
                new uint256[](1),
                new uint256[](1),
                new uint256[](1)
            ),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(
                GasFeePricingUpgradeable.setGasFeePricingAddresses.selector,
                new uint256[](1),
                new address[](1)
            ),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(GasFeePricingUpgradeable.updateChainConfig.selector, 0, 0),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(GasFeePricingUpgradeable.updateChainInfo.selector, 0, 0),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(GasFeePricingUpgradeable.updateMarkups.selector, 0, 0),
            "Ownable: caller is not the owner"
        );
    }

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                        GETTERS/SETTERS TESTS                         │
      └──────────────────────────────────────────────────────────────────────┘*/

    function testInitializedCorrectly() public {
        (uint128 _gasTokenPrice, ) = gasFeePricing.srcInfo();
        assertEq(_gasTokenPrice, srcVars.gasTokenPrice, "Failed to init: gasTokenPrice");
        assertEq(gasFeePricing.markupGasDrop(), markupGasDrop, "Failed to init: markupGasDrop");
        assertEq(gasFeePricing.markupGasUsage(), markupGasUsage, "Failed to init: markupGasUsage");
        assertEq(gasFeePricing.messageBus(), address(messageBus), "Failed to init: messageBus");
    }

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                          INTERNAL CHECKERS                           │
      └──────────────────────────────────────────────────────────────────────┘*/

    function _checkDstChainConfig(uint256 _dstChainId) internal {
        (uint128 gasAmountNeeded, uint128 maxGasDrop) = gasFeePricing.dstConfig(_dstChainId);
        assertEq(gasAmountNeeded, dstVars[_dstChainId].gasAmountNeeded, "dstGasAmountNeeded is incorrect");
        assertEq(maxGasDrop, dstVars[_dstChainId].maxGasDrop, "dstMaxGasDrop is incorrect");
    }

    function _checkDstChainInfo(uint256 _dstChainId) internal {
        (uint128 gasTokenPrice, uint128 gasUnitPrice) = gasFeePricing.dstInfo(_dstChainId);
        assertEq(gasTokenPrice, dstVars[_dstChainId].gasTokenPrice, "dstGasTokenPrice is incorrect");
        assertEq(gasUnitPrice, dstVars[_dstChainId].gasUnitPrice, "dstGasUnitPrice is incorrect");
    }

    function _checkDstChainRatios(uint256 _dstChainId) internal {
        (uint96 gasTokenPriceRatio, uint160 gasUnitPriceRatio) = gasFeePricing.dstRatios(_dstChainId);
        uint256 _gasTokenPriceRatio = (dstVars[_dstChainId].gasTokenPrice * 10**18) / srcVars.gasTokenPrice;
        uint256 _gasUnitPriceRatio = (dstVars[_dstChainId].gasUnitPrice * dstVars[_dstChainId].gasTokenPrice * 10**18) /
            srcVars.gasTokenPrice;
        assertEq(gasTokenPriceRatio, _gasTokenPriceRatio, "gasTokenPriceRatio is incorrect");
        assertEq(gasUnitPriceRatio, _gasUnitPriceRatio, "gasUnitPriceRatio is incorrect");
    }

    function _checkSrcChainConfig() internal {
        (uint128 gasAmountNeeded, uint128 maxGasDrop) = gasFeePricing.srcConfig();
        assertEq(gasAmountNeeded, srcVars.gasAmountNeeded, "srcGasAmountNeeded is incorrect");
        assertEq(maxGasDrop, srcVars.maxGasDrop, "srcMaxGasDrop is incorrect");
    }

    function _checkSrcChainInfo() internal {
        (uint128 gasTokenPrice, uint128 gasUnitPrice) = gasFeePricing.srcInfo();
        assertEq(gasTokenPrice, srcVars.gasTokenPrice, "srcGasTokenPrice is incorrect");
        assertEq(gasUnitPrice, srcVars.gasUnitPrice, "gasUnitPrice is incorrect");
    }

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                           INTERNAL SETTERS                           │
      └──────────────────────────────────────────────────────────────────────┘*/

    function _setDstChainConfig(
        uint256 _dstChainId,
        uint256 _gasAmountNeeded,
        uint256 _maxGasDrop
    ) internal {
        dstVars[_dstChainId].gasAmountNeeded = _gasAmountNeeded;
        dstVars[_dstChainId].maxGasDrop = _maxGasDrop;
        gasFeePricing.setDstChainConfig(_dstChainId, _gasAmountNeeded, _maxGasDrop);
    }

    function _setDstChainConfigs(
        uint256[] memory _dstChainIds,
        uint256[] memory _gasAmountsNeeded,
        uint256[] memory _maxGasDrops
    ) internal {
        for (uint256 i = 0; i < _dstChainIds.length; ++i) {
            dstVars[_dstChainIds[i]].gasAmountNeeded = _gasAmountsNeeded[i];
            dstVars[_dstChainIds[i]].maxGasDrop = _maxGasDrops[i];
        }
        gasFeePricing.setDstChainConfigs(_dstChainIds, _gasAmountsNeeded, _maxGasDrops);
    }

    function _setDstChainInfo(
        uint256 _dstChainId,
        uint256 _gasTokenPrice,
        uint256 _gasUnitPrice
    ) internal {
        dstVars[_dstChainId].gasTokenPrice = _gasTokenPrice;
        dstVars[_dstChainId].gasUnitPrice = _gasUnitPrice;
        gasFeePricing.setCostPerChain(_dstChainId, _gasUnitPrice, _gasTokenPrice);
    }

    function _setDstChainsInfo(
        uint256[] memory _dstChainIds,
        uint256[] memory _gasTokenPrices,
        uint256[] memory _gasUnitPrices
    ) internal {
        for (uint256 i = 0; i < _dstChainIds.length; ++i) {
            dstVars[_dstChainIds[i]].gasTokenPrice = _gasTokenPrices[i];
            dstVars[_dstChainIds[i]].gasUnitPrice = _gasUnitPrices[i];
        }
        gasFeePricing.setCostPerChains(_dstChainIds, _gasUnitPrices, _gasTokenPrices);
    }

    function _setDstGasFeePricingAddresses(uint256[] memory _dstChainIds, address[] memory _dstGasFeePricing) internal {
        for (uint256 i = 0; i < _dstChainIds.length; ++i) {
            dstVars[_dstChainIds[i]].gasFeePricing = _dstGasFeePricing[i];
        }
        gasFeePricing.setGasFeePricingAddresses(_dstChainIds, _dstGasFeePricing);
    }

    function _setSrcChainConfig(uint256 _gasAmountNeeded, uint256 _maxGasDrop) internal {
        srcVars.gasAmountNeeded = _gasAmountNeeded;
        srcVars.maxGasDrop = _maxGasDrop;
        uint256 fee = gasFeePricing.estimateUpdateFees();
        gasFeePricing.updateChainConfig{value: fee}(_gasAmountNeeded, _maxGasDrop);
    }

    function _setSrcChainInfo(uint256 _gasTokenPrice, uint256 _gasUnitPrice) internal {
        srcVars.gasTokenPrice = _gasTokenPrice;
        srcVars.gasUnitPrice = _gasUnitPrice;
        uint256 fee = gasFeePricing.estimateUpdateFees();
        gasFeePricing.updateChainInfo{value: fee}(_gasTokenPrice, _gasUnitPrice);
    }

    function _setSrcMarkups(uint128 _markupGasDrop, uint128 _markupGasUsage) internal {
        markupGasDrop = _markupGasDrop;
        markupGasUsage = _markupGasUsage;
        gasFeePricing.updateMarkups(_markupGasDrop, _markupGasUsage);
    }
}
