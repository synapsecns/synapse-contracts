// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultAdapter} from "../../../contracts/router/adapters/DefaultAdapter.sol";
import {Action, DefaultParams} from "../../../contracts/router/libs/Structs.sol";

import {MockDefaultPool, MockDefaultExtendedPool} from "../mocks/MockDefaultExtendedPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockWETH} from "../mocks/MockWETH.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

contract DefaultAdapterTest is Test {
    address public constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    MockDefaultPool public nethPool;
    MockWETH public weth;
    MockERC20 public neth;

    MockDefaultExtendedPool public nusdPool;
    MockERC20 public nusd;
    MockERC20 public dai;
    MockERC20 public usdc;
    MockERC20 public usdt;

    DefaultAdapter public adapter;

    mapping(address => uint8) public tokenToIndex;

    address public user;
    address public userRecipient;

    function setUp() public {
        weth = new MockWETH();
        neth = new MockERC20("nETH", 18);

        dai = new MockERC20("DAI", 18);
        usdc = new MockERC20("USDC", 6);
        usdt = new MockERC20("USDT", 6);

        adapter = new DefaultAdapter();
        user = makeAddr("User");
        userRecipient = makeAddr("Recipient");

        {
            address[] memory tokens = new address[](2);
            tokens[0] = address(neth);
            tokens[1] = address(weth);
            nethPool = new MockDefaultPool(tokens);
            tokenToIndex[address(neth)] = 0;
            tokenToIndex[address(weth)] = 1;
            tokenToIndex[ETH] = 1;
            weth.mint(address(nethPool), 10 * 10**18);
            neth.mint(address(nethPool), 10.5 * 10**18);
        }

        {
            address[] memory tokens = new address[](3);
            tokens[0] = address(dai);
            tokens[1] = address(usdc);
            tokens[2] = address(usdt);
            nusdPool = new MockDefaultExtendedPool(tokens, "nUSD");
            nusd = nusdPool.lpToken();
            tokenToIndex[address(dai)] = 0;
            tokenToIndex[address(usdc)] = 1;
            tokenToIndex[address(usdt)] = 2;
            tokenToIndex[address(nusd)] = 0xFF;
            dai.mint(address(nusdPool), 1000 * 10**18);
            usdc.mint(address(nusdPool), 1020 * 10**6);
            usdt.mint(address(nusdPool), 1040 * 10**6);
        }
    }

    function testAdapterActionSwapTokenToTokenDiffDecimals() public {
        checkAdapterSwap(address(nusdPool), address(dai), 1 * 10**18, address(usdc));
        checkAdapterSwap(address(nusdPool), address(usdc), 1 * 10**6, address(dai));
    }

    function testAdapterActionSwapTokenToTokenSameDecimals() public {
        checkAdapterSwap(address(nusdPool), address(usdc), 1 * 10**6, address(usdt));
        checkAdapterSwap(address(nusdPool), address(usdt), 1 * 10**6, address(usdc));
    }

    function testAdapterActionSwapTokenToTokenFromWETH() public {
        checkAdapterSwap(address(nethPool), address(weth), 1 * 10**18, address(neth));
    }

    function testAdapterActionSwapTokenToTokenToWETH() public {
        checkAdapterSwap(address(nethPool), address(neth), 1 * 10**18, address(weth));
    }

    function testAdapterActionSwapETHToToken() public {
        checkAdapterSwap(address(nethPool), ETH, 1 * 10**18, address(neth));
    }

    function testAdapterActionSwapTokenToETH() public {
        checkAdapterSwap(address(nethPool), address(neth), 1 * 10**18, ETH);
    }

    function testAdapterActionAddLiquidityDiffDecimals() public {
        checkAdapterAddLiquidity(address(usdc), 1 * 10**6);
        checkAdapterAddLiquidity(address(usdt), 1 * 10**6);
    }

    function testAdapterActionAddLiquiditySameDecimals() public {
        checkAdapterAddLiquidity(address(dai), 1 * 10**18);
    }

    function testAdapterActionRemoveLiquidityDiffDecimals() public {
        checkAdapterRemoveLiquidity(1 * 10**6, address(usdc));
        checkAdapterRemoveLiquidity(1 * 10**6, address(usdt));
    }

    function testAdapterActionRemoveLiquiditySameDecimals() public {
        checkAdapterRemoveLiquidity(1 * 10**18, address(dai));
    }

    function testAdapterActionHandleEthWrap() public {
        checkHandleEth({amountIn: 10**18, wrapETH: true});
    }

    function testAdapterActionHandleEthUnwrap() public {
        checkHandleEth({amountIn: 10**18, wrapETH: false});
    }

    function checkAdapterSwap(
        address pool,
        address tokenIn,
        uint256 amountIn,
        address tokenOut
    ) public {
        // Test with external recipient
        checkAdapterSwap(pool, tokenIn, amountIn, tokenOut, userRecipient);
        // Test with self recipient
        checkAdapterSwap(pool, tokenIn, amountIn, tokenOut, address(adapter));
    }

    function checkAdapterSwap(
        address pool,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        address recipient
    ) public {
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.Swap,
                pool: pool,
                tokenIndexFrom: tokenToIndex[tokenIn],
                tokenIndexTo: tokenToIndex[tokenOut]
            })
        );
        uint256 expectedAmountOut = MockDefaultPool(pool).calculateSwap(
            tokenToIndex[tokenIn],
            tokenToIndex[tokenOut],
            amountIn
        );
        // Mint test tokens to adapter
        if (tokenIn != ETH) {
            MockERC20(tokenIn).mint(address(adapter), amountIn);
        } else {
            deal(user, amountIn);
        }
        uint256 msgValue = tokenIn == ETH ? amountIn : 0;
        vm.prank(user);
        adapter.adapterSwap{value: msgValue}(recipient, tokenIn, amountIn, tokenOut, rawParams);
        assertEq(balanceOf(tokenOut, recipient), expectedAmountOut);
        clearBalance(tokenOut, recipient);
    }

    function checkAdapterAddLiquidity(address tokenIn, uint256 amountIn) public {
        // Test with external recipient
        checkAdapterAddLiquidity(tokenIn, amountIn, userRecipient);
        // Test with self recipient
        checkAdapterAddLiquidity(tokenIn, amountIn, address(adapter));
    }

    function checkAdapterAddLiquidity(
        address tokenIn,
        uint256 amountIn,
        address recipient
    ) public {
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.AddLiquidity,
                pool: address(nusdPool),
                tokenIndexFrom: tokenToIndex[tokenIn],
                tokenIndexTo: 0xFF
            })
        );
        uint256[] memory amounts = new uint256[](3);
        amounts[tokenToIndex[tokenIn]] = amountIn;
        uint256 expectedAmountOut = nusdPool.calculateAddLiquidity(amounts);
        // Mint test tokens to adapter
        MockERC20(tokenIn).mint(address(adapter), amountIn);
        vm.prank(user);
        adapter.adapterSwap(recipient, tokenIn, amountIn, address(nusd), rawParams);
        assertEq(balanceOf(address(nusd), recipient), expectedAmountOut);
        clearBalance(address(nusd), recipient);
    }

    function checkAdapterRemoveLiquidity(uint256 amountIn, address tokenOut) public {
        // Test with external recipient
        checkAdapterRemoveLiquidity(amountIn, tokenOut, userRecipient);
        // Test with self recipient
        checkAdapterRemoveLiquidity(amountIn, tokenOut, address(adapter));
    }

    function checkAdapterRemoveLiquidity(
        uint256 amountIn,
        address tokenOut,
        address recipient
    ) public {
        bytes memory rawParams = abi.encode(
            DefaultParams({
                action: Action.RemoveLiquidity,
                pool: address(nusdPool),
                tokenIndexFrom: 0xFF,
                tokenIndexTo: tokenToIndex[tokenOut]
            })
        );
        uint256 expectedAmountOut = nusdPool.calculateRemoveLiquidityOneToken(amountIn, tokenToIndex[tokenOut]);
        // Mint test tokens to adapter
        MockERC20(address(nusd)).mint(address(adapter), amountIn);
        vm.prank(user);
        adapter.adapterSwap(recipient, address(nusd), amountIn, tokenOut, rawParams);
        assertEq(balanceOf(tokenOut, recipient), expectedAmountOut);
        clearBalance(tokenOut, recipient);
    }

    function checkHandleEth(uint256 amountIn, bool wrapETH) public {
        // Test with external recipient
        checkHandleEth(amountIn, wrapETH, userRecipient);
        // Test with self recipient
        checkHandleEth(amountIn, wrapETH, address(adapter));
    }

    function checkHandleEth(
        uint256 amountIn,
        bool wrapETH,
        address recipient
    ) public {
        bytes memory rawParams = abi.encode(
            DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
        );
        uint256 expectedAmountOut = amountIn;
        address tokenIn = wrapETH ? address(weth) : ETH;
        address tokenOut = wrapETH ? ETH : address(weth);
        // Mint test tokens to adapter
        if (tokenIn != ETH) {
            MockERC20(tokenIn).mint(address(adapter), amountIn);
        } else {
            deal(user, amountIn);
        }
        uint256 msgValue = tokenIn == ETH ? amountIn : 0;
        vm.prank(user);
        adapter.adapterSwap{value: msgValue}(recipient, tokenIn, amountIn, tokenOut, rawParams);
        assertEq(balanceOf(tokenOut, recipient), expectedAmountOut);
        clearBalance(tokenOut, recipient);
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
