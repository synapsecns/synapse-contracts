// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts-4.5.0/utils/Strings.sol";
import "@openzeppelin/contracts-4.5.0/proxy/transparent/TransparentUpgradeableProxy.sol";

interface IAccessControl {
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;
}

interface IProxy {
    function upgradeTo(address) external;
}

// Common utilities for forge tests
contract Utilities is Test {
    bytes32 internal nextUser = keccak256("user address");

    bytes32 internal nextKappa = keccak256("kappa");

    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address internal immutable attacker;

    constructor() {
        attacker = bytes32ToAddress(keccak256("attacker"));
    }

    // -- CAST FUNCTIONS --

    function addressToBytes32(address addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function bytes32ToAddress(bytes32 value) public pure returns (address) {
        return address(uint160(uint256(value)));
    }

    // -- SETUP FUNCTIONS --

    // create users with 100 ether balance
    function createUsers(uint256 userNum) external returns (address payable[] memory) {
        address payable[] memory users = new address payable[](userNum);
        for (uint256 i = 0; i < userNum; i++) {
            address payable user = this.getNextUserAddress();
            vm.deal(user, 100 ether);
            users[i] = user;
        }
        return users;
    }

    function createEmptyUsers(uint256 userNum) external returns (address[] memory users) {
        users = new address[](userNum);
        for (uint256 i = 0; i < userNum; ++i) {
            users[i] = this.getNextUserAddress();
        }
    }

    // generate fresh address
    function getNextUserAddress() external returns (address payable) {
        //bytes32 to address conversion
        address payable user = payable(address(uint160(uint256(nextUser))));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return user;
    }

    function getNextKappa() external returns (bytes32 kappa) {
        kappa = nextKappa;
        nextKappa = keccak256(abi.encodePacked(kappa));
    }

    function deployTransparentProxy(address impl) external returns (address proxy) {
        // Setup proxy with needed logic and custom admin,
        // we don't need to upgrade anything, so no need to setup ProxyAdmin
        proxy = address(new TransparentUpgradeableProxy(impl, address(420), bytes("")));
    }

    // Upgrades Transparent Proxy implementation
    function upgradeTo(address proxy, address impl) external {
        address admin = bytes32ToAddress(vm.load(proxy, ADMIN_SLOT));
        vm.startPrank(admin);
        IProxy(proxy).upgradeTo(impl);
        vm.stopPrank();
    }

    // -- VIEW FUNCTIONS --

    function getRoleMember(address accessControlled, bytes32 role) external view returns (address) {
        return IAccessControl(accessControlled).getRoleMember(role, 0);
    }

    // -- EVM FUNCTIONS --

    /// @notice Get state modifying function return value without modifying the state
    function peekReturnValue(
        address caller,
        address _contract,
        bytes memory payload,
        uint256 value
    ) external {
        vm.prank(caller);
        (bool success, bytes memory data) = _contract.call{value: value}(payload);
        assertTrue(success, "Call failed");
        revert(string(data));
    }

    // move block.number forward by a given number of blocks
    function mineBlocks(uint256 numBlocks) external {
        uint256 targetBlock = block.number + numBlocks;
        vm.roll(targetBlock);
    }

    function checkAccess(
        address _contract,
        bytes memory payload,
        string memory revertMsg
    ) external {
        this.checkRevert(attacker, _contract, payload, "Attacker gained access", revertMsg);
    }

    function checkAccessControl(
        address _contract,
        bytes memory payload,
        bytes32 neededRole
    ) external {
        this.checkAccess(_contract, payload, _getAccessControlRevertMsg(neededRole, attacker));
    }

    function checkRevert(
        address executor,
        address _contract,
        bytes memory payload,
        string memory revertMsg
    ) external {
        this.checkRevert(executor, _contract, payload, revertMsg, revertMsg);
    }

    function checkRevert(
        address executor,
        address _contract,
        bytes memory payload,
        string memory failReason,
        string memory revertMsg
    ) external {
        hoax(executor);
        (bool success, bytes memory returnData) = _contract.call(payload);
        assertTrue(!success, failReason);
        assertEq(this.getRevertMsg(returnData), revertMsg, "Unexpected revert message");
    }

    // -- INTERNAL STUFF --

    function _getAccessControlRevertMsg(bytes32 role, address account) internal pure returns (string memory revertMsg) {
        revertMsg = string(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(account), 20),
                " is missing role ",
                Strings.toHexString(uint256(role), 32)
            )
        );
    }

    function getRevertMsg(bytes memory _returnData) external pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}
