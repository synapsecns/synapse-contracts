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
    event NewAdminFee(uint256 newAdminFee);

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
        address user = address(0xBEEF);
        address p = factory.deploy(user, address(token), address(synToken), 1e18, 0.001e18, 0.01e18);
        IPrivatePool pool = IPrivatePool(p);

        assertEq(pool.factory(), address(factory));
        assertEq(pool.owner(), address(this));
        assertEq(pool.token0(), address(synToken));
        assertEq(pool.token1(), address(token));

        assertEq(pool.P(), 1e18);
        assertEq(pool.fee(), 0.001e18);
        assertEq(pool.adminFee(), 0.01e18);
    }

    function testDeployStoresPool() public {
        address user = address(0xBEEF);
        address p = factory.deploy(user, address(token), address(synToken), 1e18, 0.001e18, 0.01e18);
        assertEq(factory.pool(address(this), address(token), address(synToken)), p);
        assertEq(factory.pool(address(this), address(synToken), address(token)), p);
    }

    function testDeployEmitsDeployEvent() public {
        address token0 = address(synToken);
        address token1 = address(token);
        address user = address(0xBEEF);

        bytes memory code = type(PrivatePool).creationCode;
        bytes memory bytecode = abi.encodePacked(code, abi.encode(address(this), token0, token1));

        bytes32 salt = keccak256(abi.encode(address(this), token0, token1));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(factory), uint256(salt), keccak256(bytecode)));
        address p = address(uint160(uint256(hash)));

        vm.expectEmit(true, false, false, true);
        emit Deploy(user, address(synToken), address(token), p);
        factory.deploy(user, address(token), address(synToken), 1e18, 0.001e18, 0.01e18);
    }

    function testDeployRevertsWhenSameToken() public {
        vm.expectRevert("same token for base and quote");
        factory.deploy(address(0xBEEF), address(token), address(token), 1e18, 0.001e18, 0.01e18);
    }

    function testDeployRevertsWhenAlreadyExists() public {
        factory.deploy(address(0xBEEF), address(token), address(synToken), 1e18, 0.001e18, 0.01e18);

        vm.expectRevert("pool already exists");
        factory.deploy(address(0xBEEF), address(token), address(synToken), 1e18, 0.001e18, 0.01e18);

        vm.expectRevert("pool already exists");
        factory.deploy(address(0xBEEF), address(synToken), address(token), 1e18, 0.001e18, 0.01e18);
    }

    function testSetAdminFeeOnPoolStoresAdminFee() public {
        address user = address(0xBEEF);
        address p = factory.deploy(user, address(token), address(synToken), 1e18, 0.001e18, 0.01e18);
        assertEq(factory.pool(user, address(token), address(synToken)), p); // check exists for setup

        uint256 adminFee = 0.1e18;
        factory.setAdminFeeOnPool(user, address(token), address(synToken), adminFee);

        assertEq(PrivatePool(p).adminFee(), adminFee);
    }

    function testSetAdminFeeOnPoolEmitsNewAdminFeeEvent() public {
        address user = address(0xBEEF);
        address p = factory.deploy(user, address(token), address(synToken), 1e18, 0.001e18, 0.01e18);
        assertEq(factory.pool(user, address(token), address(synToken)), p); // check exists for setup

        uint256 adminFee = 0.1e18;
        vm.expectEmit(false, false, false, true);
        emit NewAdminFee(adminFee);
        factory.setAdminFeeOnPool(user, address(token), address(synToken), adminFee);
    }

    function testSetAdminFeeOnPoolRevertsWhenNotOwner() public {
        address user = address(0xBEEF);
        address p = factory.deploy(user, address(token), address(synToken), 1e18, 0.001e18, 0.01e18);
        assertEq(factory.pool(user, address(token), address(synToken)), p); // check exists for setup

        uint256 adminFee = 0.1e18;
        vm.expectRevert("!owner");
        vm.prank(user);
        factory.setAdminFeeOnPool(user, address(token), address(synToken), adminFee);
    }

    function testSetAdminFeeOnPoolRevertsWhenNotPool() public {
        uint256 adminFee = 0.1e18;
        vm.expectRevert("!pool");
        factory.setAdminFeeOnPool(address(0xBEEF), address(token), address(synToken), adminFee);
    }

    // SEE: PrivatePool.t.sol for skim tests

    function testSkimPoolSucceedsWhenOwner() public {
        address user = address(0xBEEF);
        address p = factory.deploy(user, address(token), address(synToken), 1e18, 0.001e18, 0.01e18);
        assertEq(factory.pool(user, address(token), address(synToken)), p); // check exists for setup

        factory.skimPool(user, address(token), address(synToken));
    }

    function testSkimPoolRevertsWhenNotOwner() public {
        address user = address(0xBEEF);
        address p = factory.deploy(user, address(token), address(synToken), 1e18, 0.001e18, 0.01e18);
        assertEq(factory.pool(user, address(token), address(synToken)), p); // check exists for setup

        vm.expectRevert("!owner");
        vm.prank(user);
        factory.skimPool(user, address(token), address(synToken));
    }

    function testSkimPoolRevertsWhenNotPool() public {
        vm.expectRevert("!pool");
        factory.skimPool(address(0xBEEF), address(token), address(synToken));
    }

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
