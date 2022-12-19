// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../interfaces/IWETH9.sol";
import "../../interfaces/ISwap.sol";
import "../../interfaces/ISwapAdapter.sol";
import "../../interfaces/ISynapseBridge.sol";
import "../../libraries/BridgeStructs.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BridgeZap is Ownable, ISwapAdapter {
    using SafeERC20 for IERC20;

    enum TokenType {
        Burn,
        BurnNusd,
        Deposit
    }

    struct TokenInfo {
        TokenType tokenType;
        address bridgeToken;
    }

    uint256 internal constant MAINNET_CHAIN_ID = 1;
    uint256 internal constant MAX_UINT = type(uint256).max;

    IWETH9 public immutable weth;
    ISynapseBridge public immutable synapseBridge;

    mapping(address => TokenInfo) public tokenInfo;

    constructor(address payable _weth, address _synapseBridge) public {
        weth = IWETH9(_weth);
        synapseBridge = ISynapseBridge(_synapseBridge);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function addBurnNusd(address token) external onlyOwner {
        _addToken(token, TokenType.BurnNusd, token);
    }

    function addBurnTokens(address[] calldata tokens) external onlyOwner {
        uint256 amount = tokens.length;
        for (uint256 i = 0; i < amount; ++i) {
            _addToken(tokens[i], TokenType.Burn, tokens[i]);
        }
    }

    function addDepositTokens(address[] calldata tokens) external onlyOwner {
        uint256 amount = tokens.length;
        for (uint256 i = 0; i < amount; ++i) {
            _addToken(tokens[i], TokenType.Deposit, tokens[i]);
        }
    }

    function addToken(
        address token,
        TokenType tokenType,
        address bridgeToken
    ) external onlyOwner {
        _addToken(token, tokenType, bridgeToken);
    }

    function removeTokens(address[] calldata tokens) external onlyOwner {
        uint256 amount = tokens.length;
        for (uint256 i = 0; i < amount; ++i) {
            _removeToken(tokens[i]);
        }
    }

    function removeToken(address token) external onlyOwner {
        _removeToken(token);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            BRIDGE & SWAP                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function bridge(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable {
        // Pull initial token from the user
        _pullToken(token, amount);
        // Perform a swap, if requested
        if (_swapRequested(originQuery)) {
            (token, amount) = _adapterSwap(token, amount, originQuery);
        }
        TokenInfo memory info = tokenInfo[token];
        require(info.bridgeToken != address(0), "Token not supported");
        token = info.bridgeToken;
        // `amount` worth of `token` needs to be bridged.
        // Check if swap on destination chain is required.
        if (_swapRequested(destQuery)) {
            // Decode params for swapping via a Synapse pool on the destination chain.
            SynapseParams memory destParams = abi.decode(destQuery.rawParams, (SynapseParams));
            if (info.tokenType == TokenType.Deposit) {
                // Case 1: token needs to be deposited on origin chain.
                // We need to perform AndSwap() on destination chain.
                synapseBridge.depositAndSwap({
                    to: to,
                    chainId: chainId,
                    token: IERC20(token),
                    amount: amount,
                    tokenIndexFrom: destParams.tokenIndexFrom,
                    tokenIndexTo: destParams.tokenIndexTo,
                    minDy: destQuery.minAmountOut,
                    deadline: destQuery.deadline
                });
            } else if (info.tokenType == TokenType.Burn || chainId != MAINNET_CHAIN_ID) {
                // Case 2: token needs to be redeemed on origin chain.
                // Token is not nUSD. Or token is nUSD, but is not being bridged to Ethereum Mainnet.
                // We need to perform AndSwap() on destination chain.
                synapseBridge.redeemAndSwap({
                    to: to,
                    chainId: chainId,
                    token: IERC20(token),
                    amount: amount,
                    tokenIndexFrom: destParams.tokenIndexFrom,
                    tokenIndexTo: destParams.tokenIndexTo,
                    minDy: destQuery.minAmountOut,
                    deadline: destQuery.deadline
                });
            } else {
                // Case 3: token needs to be redeemed on origin chain.
                // This is nUSD. It is being bridged back home to Ethereum Mainnet.
                // We need to perform AndRemove() on destination chain.
                synapseBridge.redeemAndRemove({
                    to: to,
                    chainId: chainId,
                    token: IERC20(token),
                    amount: amount,
                    liqTokenIndex: destParams.tokenIndexTo,
                    liqMinAmount: destQuery.minAmountOut,
                    liqDeadline: destQuery.deadline
                });
            }
        } else {
            if (info.tokenType == TokenType.Deposit) {
                // Case 1 (Deposit): token needs to be deposited on origin chain
                synapseBridge.deposit(to, chainId, IERC20(token), amount);
            } else {
                // Case 2 (Burn || BurnNusd): token needs to be redeemed on origin chain
                synapseBridge.redeem(to, chainId, IERC20(token), amount);
            }
        }
    }

    function swap(
        address to,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes calldata rawParams
    ) external override returns (uint256 amountOut) {
        require(msg.sender == address(this), "External calls not allowed");
        // Decode params for swapping via a Synapse pool
        SynapseParams memory params = abi.decode(rawParams, (SynapseParams));
        ISwap pool = ISwap(params.pool);
        // Swap pool should exist, tokenOut should match the "swap to" token
        require(address(pool) != address(0), "!pool");
        require(pool.getToken(params.tokenIndexTo) == IERC20(tokenOut), "!tokenOut");
        // Approve token for spending if needed
        _approveToken(IERC20(tokenIn), address(pool));
        // amountOut and deadline are checked in {_adapterSwap}
        amountOut = pool.swap({
            tokenIndexFrom: params.tokenIndexFrom,
            tokenIndexTo: params.tokenIndexTo,
            dx: amountIn,
            minDy: 0,
            deadline: MAX_UINT
        });
        if (to != address(this)) {
            IERC20(tokenOut).safeTransfer(to, amountOut);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       INTERNAL: BRIDGE & SWAP                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _adapterSwap(
        address token,
        uint256 amount,
        SwapQuery memory query
    ) internal returns (address tokenOut, uint256 amountOut) {
        // Adapters could be permisionless, so we're doing all the checks on this level
        // First, check the deadline for the swap
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= query.deadline, "Deadline not met");
        if (query.swapAdapter != address(this)) {
            IERC20(token).safeTransfer(query.swapAdapter, amount);
        }
        tokenOut = query.tokenOut;
        amountOut = ISwapAdapter(query.swapAdapter).swap({
            to: address(this),
            tokenIn: token,
            amountIn: amount,
            tokenOut: tokenOut,
            rawParams: query.rawParams
        });
        // Where's the money Lebowski?
        require(IERC20(tokenOut).balanceOf(address(this)) >= amountOut, "No tokens transferred");
        // Finally, check that we received at least as much as wanted
        require(amountOut >= query.minAmountOut, "Swap didn't result in min tokens");
    }

    function _approveToken(IERC20 token, address spender) internal {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance != MAX_UINT) {
            if (allowance != 0) {
                token.safeApprove(spender, 0);
            }
            token.safeApprove(spender, MAX_UINT);
        }
    }

    function _pullToken(address token, uint256 amount) internal {
        if (msg.value == 0) {
            // Token needs to be pulled only if msg.value is zero
            // This way user can specify WETH as the origin asset
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            // Otherwise, we need to check that WETH was specified
            require(token == address(weth), "!weth");
            // And that amount matches msg.value
            require(msg.value == amount, "!msg.value");
            // Deposit in order to have WETH in this contract
            weth.deposit{value: amount}();
        }
        // Either way this contract has `amount` worth of `token`
    }

    function _swapRequested(SwapQuery memory query) internal pure returns (bool) {
        return query.swapAdapter != address(0);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                    INTERNAL: ADD & REMOVE TOKENS                     ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _addToken(
        address token,
        TokenType tokenType,
        address bridgeToken
    ) internal {
        tokenInfo[token] = TokenInfo(tokenType, bridgeToken);
        _approveToken(IERC20(bridgeToken), address(synapseBridge));
    }

    function _removeToken(address token) internal {
        delete tokenInfo[token];
    }
}
