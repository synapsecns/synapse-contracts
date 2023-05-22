// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "../../contracts/concentrated/PrivateFactory.sol";
import "../../contracts/concentrated/PrivatePool.sol";
import "../../contracts/concentrated/interfaces/IPrivatePool.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockAccessToken.sol";

contract PrivateFactoryTest is Test {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public constant BRIDGE = address(0xB);

    PrivateFactory public factory;
    MockToken public token;
    MockAccessToken public synToken;

    event Deploy(address indexed lp, address token0, address token1, address poolAddress);
    event NewOwner(address newOwner);

    function setUp() public {
        factory = new PrivateFactory(BRIDGE);
        token = new MockToken("X", "X", 18);

        synToken = new MockAccessToken("synX", "synX", 18);
        synToken.grantRole(MINTER_ROLE, BRIDGE);
    }

    function testSetup() public {
        assertEq(token.symbol(), "X");
        assertEq(synToken.symbol(), "synX");
        assertEq(synToken.hasRole(MINTER_ROLE, BRIDGE), true);
    }

    function testConstructor() public {
        assertEq(factory.bridge(), BRIDGE);
    }

    function testOrderTokensWhenAIsSyn() public {
        (address token0, address token1) = factory.orderTokens(address(synToken), address(token));
        assertEq(token0, address(synToken));
        assertEq(token1, address(token));
    }

    function testOrderTokensWhenBIsSyn() public {
        (address token0, address token1) = factory.orderTokens(address(token), address(synToken));
        assertEq(token0, address(synToken));
        assertEq(token1, address(token));
    }

    function testDeployCreatesPool() public {
        address p = factory.deploy(address(token), address(synToken));
        IPrivatePool pool = IPrivatePool(p);

        assertEq(pool.factory(), address(factory));
        assertEq(pool.owner(), address(this));
        assertEq(pool.token0(), address(synToken));
        assertEq(pool.token1(), address(token));
    }

    function testDeployStoresPool() public {
        address p = factory.deploy(address(token), address(synToken));
        assertEq(factory.pool(address(this), address(token), address(synToken)), p);
        assertEq(factory.pool(address(this), address(synToken), address(token)), p);
    }

    function testDeployEmitsDeployEvent() public {
        address token0 = address(synToken);
        address token1 = address(token);

        bytes memory code = type(PrivatePool).creationCode;
        bytes memory bytecode = abi.encodePacked(code, abi.encode(address(this), token0, token1));

        bytes32 salt = keccak256(abi.encode(address(this), token0, token1));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(factory), uint256(salt), keccak256(bytecode)));
        address p = address(uint160(uint256(hash)));

        vm.expectEmit(true, false, false, true);
        emit Deploy(address(this), address(synToken), address(token), p);
        factory.deploy(address(token), address(synToken));
    }

    function testDeployRevertsWhenSameToken() public {
        vm.expectRevert("same token for base and quote");
        factory.deploy(address(token), address(token));
    }

    function testDeployRevertsWhenAlreadyExists() public {
        factory.deploy(address(token), address(synToken));

        vm.expectRevert("pool already exists");
        factory.deploy(address(token), address(synToken));

        vm.expectRevert("pool already exists");
        factory.deploy(address(synToken), address(token));
    }

    // TODO: test setAdminFeeOnPool, skimPool

    function testSetOwnerStoresOwner() public {
        address newOwner = address(0xBEEF);
        factory.setOwner(newOwner);
        assertEq(factory.owner(), newOwner);
    }

    function testSetOwnerEmitsNewOwnerEvent() public {
        address newOwner = address(0xBEEF);
        vm.expectEmit(false, false, false, true);
        emit NewOwner(newOwner);
        factory.setOwner(newOwner);
    }

    function testSetOwnerRevertsWhenNotOwner() public {
        address newOwner = address(0xBEEF);
        vm.expectRevert("!owner");
        vm.prank(newOwner);
        factory.setOwner(newOwner);
    }

    function testSetOwnerRevertsWhenSameOwner() public {
        address newOwner = address(this);
        vm.expectRevert("same owner");
        factory.setOwner(newOwner);
    }
}
