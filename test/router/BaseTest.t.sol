// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockDefaultPool, MockDefaultExtendedPool} from "./mocks/MockDefaultExtendedPool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockWETH} from "./mocks/MockWETH.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

abstract contract BaseTest is Test {
    address public constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    MockDefaultPool public nethPool;
    MockWETH public weth;
    MockERC20 public neth;

    MockDefaultExtendedPool public nusdPool;
    MockERC20 public nusd;
    MockERC20 public dai;
    MockERC20 public usdc;
    MockERC20 public usdt;

    mapping(address => uint8) public tokenToIndex;
    mapping(address => address[]) public poolTokens;

    address public user;
    address public userRecipient;

    function setUp() public virtual {
        user = makeAddr("User");
        userRecipient = makeAddr("Recipient");

        deployEthTokens();
        deployEthPool();
        mintEthPoolTokens();

        deployUsdTokens();
        deployUsdPool();
        mintUsdPoolTokens();
    }

    function deployEthTokens() public virtual {
        weth = new MockWETH();
        neth = new MockERC20("nETH", 18);
    }

    function deployEthPool() public virtual {
        address[] memory tokens = new address[](2);
        tokens[0] = address(neth);
        tokens[1] = address(weth);
        nethPool = new MockDefaultPool(tokens);

        poolTokens[address(nethPool)] = tokens;
        tokenToIndex[address(neth)] = 0;
        tokenToIndex[address(weth)] = 1;
        tokenToIndex[ETH] = 1;
    }

    function mintEthPoolTokens() public virtual {
        weth.mint(address(nethPool), 10 * 10**18);
        neth.mint(address(nethPool), 10.5 * 10**18);
    }

    function deployUsdTokens() public virtual {
        dai = new MockERC20("DAI", 18);
        usdc = new MockERC20("USDC", 6);
        usdt = new MockERC20("USDT", 6);
    }

    function deployUsdPool() public virtual {
        address[] memory tokens = new address[](3);
        tokens[0] = address(dai);
        tokens[1] = address(usdc);
        tokens[2] = address(usdt);
        nusdPool = new MockDefaultExtendedPool(tokens, "nUSD");

        nusd = nusdPool.lpToken();
        poolTokens[address(nusdPool)] = tokens;
        tokenToIndex[address(dai)] = 0;
        tokenToIndex[address(usdc)] = 1;
        tokenToIndex[address(usdt)] = 2;
        tokenToIndex[address(nusd)] = 0xFF;
    }

    function mintUsdPoolTokens() public virtual {
        dai.mint(address(nusdPool), 1000 * 10**18);
        usdc.mint(address(nusdPool), 1020 * 10**6);
        usdt.mint(address(nusdPool), 1040 * 10**6);
    }

    // ══════════════════════════════════════════════ COMMON HELPERS ═══════════════════════════════════════════════════

    function calculateAddLiquidity(address token, uint256 amount) public view returns (uint256) {
        uint8 index = tokenToIndex[token];
        uint256[] memory amounts = new uint256[](poolTokens[address(nusdPool)].length);
        amounts[index] = amount;
        return nusdPool.calculateAddLiquidity(amounts);
    }

    function mintToUserAndApprove(
        address token,
        address spender,
        uint256 amount
    ) public {
        if (token == ETH) {
            deal(user, amount);
        } else {
            MockERC20(token).mint(user, amount);
            vm.prank(user);
            MockERC20(token).approve(spender, amount);
        }
    }

    function clearBalance(address token, address who) public {
        if (token == ETH) {
            deal(who, 0);
        } else {
            MockERC20(token).burn(who, MockERC20(token).balanceOf(who));
        }
    }

    function balanceOf(address token, address who) public view returns (uint256) {
        if (token == ETH) {
            return who.balance;
        } else {
            return IERC20(token).balanceOf(who);
        }
    }
}
