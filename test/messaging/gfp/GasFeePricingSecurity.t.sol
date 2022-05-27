// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./GasFeePricingSetup.t.sol";

contract GasFeePricingUpgradeableSecurityTest is GasFeePricingSetup {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            SECURITY TESTS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function testInitializedCorrectly() public {
        (uint128 _gasTokenPrice, ) = gasFeePricing.localInfo();
        assertEq(_gasTokenPrice, localVars.gasTokenPrice, "Failed to init: gasTokenPrice");
        assertEq(gasFeePricing.messageBus(), address(messageBus), "Failed to init: messageBus");
    }

    function testIsInitialized() public {
        utils.checkAccess(
            address(messageBus),
            abi.encodeWithSelector(MessageBusUpgradeable.initialize.selector, address(0), address(0)),
            "Initializable: contract is already initialized"
        );

        utils.checkAccess(
            address(gasFeePricing),
            abi.encodeWithSelector(MessageExecutorUpgradeable.initialize.selector, address(0), 0, 0, 0),
            "Initializable: contract is already initialized"
        );
    }

    function testCheckAccessControl() public {
        address _gfp = address(gasFeePricing);
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(
                MessageExecutorUpgradeable.setRemoteConfig.selector,
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
                MessageExecutorUpgradeable.setRemoteInfo.selector,
                new uint256[](1),
                new uint128[](1),
                new uint128[](1)
            ),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(
                MessageExecutorUpgradeable.setRemoteMarkups.selector,
                new uint256[](1),
                new uint16[](1),
                new uint16[](1)
            ),
            "Ownable: caller is not the owner"
        );

        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(MessageExecutorUpgradeable.updateLocalConfig.selector, 0, 0, 0),
            "Ownable: caller is not the owner"
        );

        utils.checkAccess(
            _gfp,
            abi.encodeWithSelector(MessageExecutorUpgradeable.updateLocalInfo.selector, 0, 0),
            "Ownable: caller is not the owner"
        );
    }
}
