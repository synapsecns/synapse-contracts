// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {SynapseDeployFactory} from "../../contracts/factory/SynapseDeployFactory.sol";
import {SynapseDeployer} from "../../contracts/factory/SynapseDeployer.sol";

import {ERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/ERC20.sol";
import {Strings} from "@openzeppelin/contracts-4.5.0/utils/Strings.sol";

contract PayableMock {
    event LogValue(uint256 value);

    constructor() payable {
        emit LogValue(msg.value);
    }
}

// solhint-disable func-name-mixedcase
contract SynapseDeployerTest is Test {
    SynapseDeployFactory internal factory;
    SynapseDeployer internal synapseDeployer;

    bytes32 internal constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    address internal constant ADMIN = address(1337);

    event LogValue(uint256 value);

    function setUp() public {
        factory = new SynapseDeployFactory();
        synapseDeployer = new SynapseDeployer(factory, ADMIN);
    }

    /// @notice Should deploy contract at the predicted address for the whitelisted deployer.
    function test_deploy(
        address deployer,
        bytes32 salt,
        string memory name,
        string memory symbol
    ) public {
        vm.assume(deployer != address(0));
        _grantDeployerRole(deployer);
        // We're deploying ERC20(name, symbol) to a predetermined address
        address predicted = synapseDeployer.predictAddress(deployer, salt);
        bytes memory args = abi.encode(name, symbol);
        // Simulate a deploy call from the deployer
        vm.prank(deployer);
        address deployment = synapseDeployer.deploy(salt, abi.encodePacked(type(ERC20).creationCode, args), bytes(""));
        // Check deployment address and correctness of constructor args
        assertEq(deployment, predicted, "Predicted address wrong");
        ERC20 token = ERC20(deployment);
        assertEq(token.name(), name, "Wrong name");
        assertEq(token.symbol(), symbol, "Wrong symbol");
    }

    /// @notice Should forward full msg.value for the constructor.
    function test_deploy_payableConstructor(address deployer, uint256 value) public {
        vm.assume(deployer != address(0));
        _grantDeployerRole(deployer);
        deal(deployer, value);
        vm.expectEmit(true, true, true, true);
        emit LogValue(value);
        vm.prank(deployer);
        synapseDeployer.deploy{value: value}(bytes32(0), type(PayableMock).creationCode, bytes(""));
    }

    /// @notice Should reject calls from unauthorized deployers (including ADMIN).
    function test_deploy_revert_notDeployer(address caller) public {
        bytes memory revertMsg = _expectedRevertString(caller);
        // Simulate a deploy call from the caller
        vm.prank(caller);
        vm.expectRevert(revertMsg);
        synapseDeployer.deploy(bytes32(0), new bytes(0), new bytes(0));
    }

    function _grantDeployerRole(address account) internal {
        vm.prank(ADMIN);
        synapseDeployer.grantRole(DEPLOYER_ROLE, account);
    }

    function _expectedRevertString(address caller) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(caller), 20),
                " is missing role ",
                Strings.toHexString(uint256(DEPLOYER_ROLE), 32)
            );
    }
}
