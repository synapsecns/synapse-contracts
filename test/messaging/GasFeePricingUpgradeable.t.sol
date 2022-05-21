// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";

import "src-messaging/AuthVerifier.sol";
import "src-messaging/GasFeePricingUpgradeable.sol";
import "src-messaging/MessageBusUpgradeable.sol";

contract GasFeePricingUpgradeableTest is Test {
    Utilities internal utils;

    AuthVerifier internal authVerifier;
    GasFeePricingUpgradeable internal gasFeePricing;
    MessageBusUpgradeable internal messageBus;

    uint256 internal srcGasTokenPrice;
    uint128 internal markupGasDrop;
    uint128 internal markupGasUsage;

    address public constant NODE = address(1337);

    function setUp() public {
        utils = new Utilities();
        authVerifier = new AuthVerifier(NODE);

        srcGasTokenPrice = 10**18;
        markupGasDrop = 150;
        markupGasUsage = 200;

        MessageBusUpgradeable busImpl = new MessageBusUpgradeable();
        GasFeePricingUpgradeable pricingImpl = new GasFeePricingUpgradeable();

        messageBus = MessageBusUpgradeable(utils.deployTransparentProxy(address(busImpl)));
        gasFeePricing = GasFeePricingUpgradeable(utils.deployTransparentProxy(address(pricingImpl)));

        // I don't have extra 10M laying around, so let's initialize those proxies
        messageBus.initialize(address(gasFeePricing), address(authVerifier));
        gasFeePricing.initialize(address(messageBus), srcGasTokenPrice, markupGasDrop, markupGasUsage);
    }

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
}
