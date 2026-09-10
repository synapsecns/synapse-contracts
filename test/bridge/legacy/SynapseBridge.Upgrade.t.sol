// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseBridge} from "../../../contracts/bridge/SynapseBridge.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";
import {Test} from "forge-std/Test.sol";

// solhint-disable func-name-mixedcase
// TODO: rename to TestFork to remove this from CI workflow post-migration
contract SynapseBridgeUpgradeArbitrumTest is Test {
    // 2025-06-05
    uint256 internal blockNumber = 344210000;
    address payable internal bridge = 0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9;
    address internal proxyAdmin = 0x432036208d2717394d2614d6697c46DF3Ed69540;
    address internal implementation = 0x97a7af2A0323e2a40B866Df3A5F1F389427C9b68;

    uint256 internal expectedStartBlockNumber = 13219011;
    address internal expectedWethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    uint256 internal expectedBridgeVersion = 6;
    uint256 internal expectedChainGasAmount = 0.00001 ether;
    string internal rpcUrl = "https://arbitrum-one.public.blastapi.io";

    address internal newBridgeImplementation;

    address internal token = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    uint256 internal existingFees;
    bytes32 internal kappa = 0xbdecec2b295b7ed28c44d9849c7dbf773516cbe0c219df850a10c4bcc6bbb7dd;

    address internal roleAdmin;
    address internal governance;
    address internal nodeGroup;

    function setUp() public {
        vm.createSelectFork(rpcUrl, blockNumber);
        newBridgeImplementation = address(new SynapseBridge());

        existingFees = SynapseBridge(bridge).getFeeBalance(token);
        roleAdmin = SynapseBridge(bridge).getRoleMember(SynapseBridge(bridge).DEFAULT_ADMIN_ROLE(), 0);
        governance = SynapseBridge(bridge).getRoleMember(SynapseBridge(bridge).GOVERNANCE_ROLE(), 0);
        nodeGroup = SynapseBridge(bridge).getRoleMember(SynapseBridge(bridge).NODEGROUP_ROLE(), 0);

        vm.label(bridge, "SynapseBridge");
        vm.label(proxyAdmin, "ProxyAdmin");
        vm.label(implementation, "OldImplementation");
        vm.label(newBridgeImplementation, "NewImplementation");
    }

    function upgrade() public {
        address owner = ProxyAdmin(proxyAdmin).owner();
        vm.prank(owner);
        ProxyAdmin(proxyAdmin).upgrade(TransparentUpgradeableProxy(bridge), newBridgeImplementation);
    }

    function test_getters() public {
        assertEq(SynapseBridge(bridge).getRoleMember(SynapseBridge(bridge).DEFAULT_ADMIN_ROLE(), 0), roleAdmin);
        assertEq(SynapseBridge(bridge).getRoleMember(SynapseBridge(bridge).GOVERNANCE_ROLE(), 0), governance);
        assertEq(SynapseBridge(bridge).getRoleMember(SynapseBridge(bridge).NODEGROUP_ROLE(), 0), nodeGroup);
        assertNotEq(roleAdmin, address(0));
        assertNotEq(governance, address(0));
        assertNotEq(nodeGroup, address(0));

        assertEq(SynapseBridge(bridge).bridgeVersion(), expectedBridgeVersion);
        assertEq(SynapseBridge(bridge).chainGasAmount(), expectedChainGasAmount);

        assertEq(SynapseBridge(bridge).getFeeBalance(token), existingFees);
        assertGt(existingFees, 0);

        assertTrue(SynapseBridge(bridge).kappaExists(kappa));
        assertFalse(SynapseBridge(bridge).kappaExists(kappa ^ bytes32(uint256(1))));

        assertEq(SynapseBridge(bridge).startBlockNumber(), expectedStartBlockNumber);
        assertEq(SynapseBridge(bridge).WETH_ADDRESS(), expectedWethAddress);
        assertFalse(SynapseBridge(bridge).paused());
    }

    function test_upgrade() public {
        assertEq(getImplementation(), implementation);
        upgrade();
        assertEq(getImplementation(), newBridgeImplementation);
        expectedBridgeVersion = 8;
        expectedChainGasAmount = 0;
        test_getters();
        assertFalse(SynapseBridge(bridge).isLegacySendDisabled());
    }

    function getImplementation() internal view returns (address) {
        return ProxyAdmin(proxyAdmin).getProxyImplementation(TransparentUpgradeableProxy(bridge));
    }
}
