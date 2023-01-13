// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/ISynapseBridge.sol";
import "./LocalBridgeConfig.sol";
import "./SynapseAdapter.sol";
import "../utils/MulticallView.sol";

/**
 * @notice SynapseRouter contract that can be used together with SynapseBridge on any chain.
 * On every supported chain SynapseRouter and SwapQuoter contracts need to be deployed.
 * Chain pools, that are present in the global BridgeConfig should be added to SwapQuoter.
 * router.setSwapQuoter(swapQuoter) should be executed to link these contracts.
 * SynapseRouter should be using the same WETH contract that SynapseBridge is (or will be) using.
 * All supported bridge tokens should be added to SynapseRouter contract.
 *
 * @dev Bridging workflow with SynapseRouter contract.
 * Suppose `routerO` and `routerD` are SynapseRouter deployments on origin and destination chain respectively.
 * Suppose user wants to send `tokenIn` on origin chain, and receive `tokenOut` on destination chain.
 * Suppose for this transaction `bridgeToken` needs to be used.
 * Bridge token address is `bridgeTokenO` and `bridgeTokenD` on origin and destination chain respectively.
 * There might or might not be a swap on origin and destination chains.
 * Following set of actions is required:
 * 1. originQuery = routerO.getAmountOut(tokenIn, bridgeTokenO, amountIn)
 * 2. Adjust originQuery.minAmountOut and originQuery.deadline using user defined slippage and deadline
 * 3. fee = BridgeConfig.calculateSwapFee(bridgeTokenD, destChainId, originQuery.minAmountOut)
 * // ^ Needs special logic for Avalanche's GMX ^
 * 4. destQuery = brideZapD.getAmountOut(bridgeTokenD, tokenOut, originQuery.minAmountOut - fee)
 * 5. Do the bridging with router.bridge(to, destChainId, tokenIn, amountIn, originQuery, destQuery)
 * // If tokenIn is WETH, do router.bridge{value: amount} to use native ETH instead of WETH.
 * Note: the transaction will be reverted, if `bridgeTokenO` is not set up in SynapseRouter.
 */
contract SynapseRouter is LocalBridgeConfig, SynapseAdapter, MulticallView {
    // SynapseRouter is also the Adapter for the Synapse pools (this reduces the amount of token transfers).
    // SynapseRouter address will be used as swapAdapter in SwapQueries returned by a local SwapQuoter.

    using SafeERC20 for IERC20;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        CONSTANTS & IMMUTABLES                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Synapse:Bridge address
    ISynapseBridge public immutable synapseBridge;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      CONSTRUCTOR & INITIALIZER                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Creates a SynapseRouter implementation, saves WETH and SynapseBridge address.
     * @dev Redeploy an implementation with different values, if an update is required.
     * Upgrading the proxy implementation then will effectively "update the immutables".
     */
    constructor(address _synapseBridge) public {
        synapseBridge = ISynapseBridge(_synapseBridge);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Sets a custom allowance for the given token.
     * @dev To be used for the wrapper token setups.
     */
    function setAllowance(
        IERC20 token,
        address spender,
        uint256 amount
    ) external onlyOwner {
        token.safeApprove(spender, amount);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            BRIDGE & SWAP                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Initiate a bridge transaction with an optional swap on both origin and destination chains.
     * @dev Note that method is payable.
     * If token is ETH_ADDRESS, this method should be invoked with `msg.value = amountIn`.
     * If token is ERC20, the tokens will be pulled from msg.sender (use `msg.value = 0`).
     * Make sure to approve this contract for spending `token` beforehand.
     * originQuery.tokenOut should never be ETH_ADDRESS, bridge only works with ERC20 tokens.
     *
     * `token` is always a token user is sending. In case token requires a wrapper token to be bridge,
     * use underlying address for `token` instead of the wrapper one.
     *
     * `originQuery` contains instructions for the swap on origin chain. As above, originQuery.tokenOut
     * should always use the underlying address. In other words, the concept of wrapper token is fully
     * abstracted away from the end user.
     *
     * `originQuery` and `destQuery` are supposed to be fetched using SynapseRouter.getAmountOut(tokenIn, tokenOut, amountIn)
     *
     * @param to            Address to receive tokens on destination chain
     * @param chainId       Destination chain id
     * @param token         Initial token for the bridge transaction to be pulled from the user
     * @param amount        Amount of the initial tokens for the bridge transaction
     * @param originQuery   Origin swap query. Empty struct indicates no swap is required
     * @param destQuery     Destination swap query. Empty struct indicates no swap is required
     */
    function bridge(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable {
        if (_hasAdapter(originQuery)) {
            // Perform a swap using the swap adapter, transfer the swapped tokens to this contract
            (token, amount) = _adapterSwap(address(this), token, amount, originQuery);
        } else {
            // Pull initial token from the user to this contract
            _pullToken(address(this), token, amount);
        }
        // Either way, this contract has `amount` worth of `token`
        TokenConfig memory _config = config[token];
        require(_config.bridgeToken != address(0), "Token not supported");
        token = _config.bridgeToken;
        // Decode params for swapping via a Synapse pool on the destination chain, if they were requested.
        SynapseParams memory destParams;
        if (_hasAdapter(destQuery)) destParams = abi.decode(destQuery.rawParams, (SynapseParams));
        // Check if Swap/RemoveLiquidity Action on destination chain is required.
        // Swap adapter needs to be specified.
        // HandleETH action is done automatically by SynapseBridge.
        if (_hasAdapter(destQuery) && destParams.action != Action.HandleEth) {
            if (_config.tokenType == TokenType.Deposit) {
                require(destParams.action == Action.Swap, "Unsupported dest action");
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
            } else if (destParams.action == Action.Swap) {
                // Case 2: token needs to be redeemed on origin chain.
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
                require(destParams.action == Action.RemoveLiquidity, "Unsupported dest action");
                // Case 3: token needs to be redeemed on origin chain.
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
            if (_config.tokenType == TokenType.Deposit) {
                // Case 1 (Deposit): token needs to be deposited on origin chain
                synapseBridge.deposit(to, chainId, IERC20(token), amount);
            } else {
                // Case 2 (Redeem): token needs to be redeemed on origin chain
                synapseBridge.redeem(to, chainId, IERC20(token), amount);
            }
        }
    }

    /**
     * @notice Perform a swap using the supplied parameters.
     * @dev Note that method is payable.
     * If token is ETH_ADDRESS, this method should be invoked with `msg.value = amountIn`.
     * If token is ERC20, the tokens will be pulled from msg.sender (use `msg.value = 0`).
     * Make sure to approve this contract for spending `token` beforehand.
     * If query.tokenOut is ETH_ADDRESS, native ETH will be sent to the recipient (be aware of potential reentrancy).
     * If query.tokenOut is ERC20, the tokens will be transferred to the recipient.
     * @param to            Address to receive swapped tokens
     * @param token         Token to swap
     * @param amount        Amount of tokens to swap
     * @param query         Query with the swap parameters (see BridgeStructs.sol)
     * @return amountOut    Amount of swapped tokens received by the user
     */
    function swap(
        address to,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) external payable returns (uint256 amountOut) {
        require(to != address(0), "!recipient: zero address");
        require(to != address(this), "!recipient: router address");
        require(_hasAdapter(query), "!swapAdapter");
        // Perform a swap through the Adapter. Adapter will be the one handling ETH/WETH interactions.
        (, amountOut) = _adapterSwap(to, token, amount, query);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         VIEWS: BRIDGE QUOTES                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Finds the best path between `tokenIn` and every supported bridge token from the given list,
     * treating the swap as "origin swap", without putting any restrictions on the swap.
     * @dev Will NOT revert if any of the tokens are not supported, instead will return an empty query for that symbol.
     * Check (query.minAmountOut != 0): this is true only if the swap is possible and bridge token is supported.
     * The returned queries with minAmountOut != 0 could be used as `originQuery` with SynapseRouter.
     * Note: it is possible to form a SwapQuery off-chain using alternative SwapAdapter for the origin swap.
     * @param tokenIn       Initial token that user wants to bridge/swap
     * @param tokenSymbols  List of symbols representing bridge tokens
     * @param amountIn      Amount of tokens user wants to bridge/swap
     * @return originQueries    List of structs that could be used as `originQuery` in SynapseRouter.
     *                          minAmountOut and deadline fields will need to be adjusted based on the user settings.
     */
    function getOriginAmountOut(
        address tokenIn,
        string[] memory tokenSymbols,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries) {
        uint256 length = tokenSymbols.length;
        originQueries = new SwapQuery[](length);
        for (uint256 i = 0; i < length; ++i) {
            // Check if token with given symbol is supported on this chain
            address bridgeToken = symbolToToken[tokenSymbols[i]];
            // Skip not supported tokens
            if (bridgeToken == address(0)) continue;
            // Every possible action is supported for origin swap
            LimitedToken memory _tokenIn = LimitedToken(ActionLib.allActions(), tokenIn);
            originQueries[i] = swapQuoter.getAmountOut(_tokenIn, bridgeToken, amountIn);
        }
    }

    /**
     * @notice Finds the best path between every supported bridge token from the given list and `tokenOut`,
     * treating the swap as "destination swap", limiting possible actions to those available for every bridge token.
     * @dev Will NOT revert if any of the tokens are not supported, instead will return an empty query for that symbol.
     * Note: it is NOT possible to form a SwapQuery off-chain using alternative SwapAdapter for the destination swap.
     * For the time being, only swaps through the Synapse-supported pools are available on destination chain.
     * @param requests  List of structs with following information:
     *                  - symbol: unique token ID consistent among all chains
     *                  - amountIn: amount of bridge token to start with, before the bridge fee is applied
     * @param tokenOut  Token user wants to receive on destination chain
     * @return destQueries  List of structs that could be used as `destQuery` in SynapseRouter.
     *                      minAmountOut and deadline fields will need to be adjusted based on the user settings.
     */
    function getDestinationAmountOut(DestRequest[] memory requests, address tokenOut)
        external
        view
        returns (SwapQuery[] memory destQueries)
    {
        uint256 length = requests.length;
        destQueries = new SwapQuery[](length);
        for (uint256 i = 0; i < length; ++i) {
            address token = symbolToToken[requests[i].symbol];
            // Skip if token is not supported
            if (token == address(0)) continue;
            // token is confirmed to be a supported bridge token at this point
            uint256 amountIn = _calculateBridgeAmountOut(token, requests[i].amountIn);
            // Skip if fee is greater than amountIn
            if (amountIn == 0) continue;
            TokenType bridgeTokenType = config[token].tokenType;
            // See what kind of "Actions" are available for the given bridge token:
            LimitedToken memory tokenIn = LimitedToken(_bridgeTokenActions(bridgeTokenType), token);
            destQueries[i] = swapQuoter.getAmountOut(tokenIn, tokenOut, amountIn);
        }
    }

    /**
     * @notice Gets the list of all bridge tokens (and their symbols), such that destination swap
     * from a bridge token to `tokenOut` is possible.
     * @param tokenOut  Token address to swap to on destination chain
     * @return tokens   List of structs with following information:
     *                  - symbol: unique token ID consistent among all chains
     *                  - token: bridge token address
     */
    function getConnectedBridgeTokens(address tokenOut) external view returns (BridgeToken[] memory tokens) {
        uint256 amount = bridgeTokensAmount();
        // Try connecting every supported bridge token to tokenOut
        LimitedToken[] memory allTokens = new LimitedToken[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            address token = _bridgeTokens.at(i);
            // Make sure only "supported actions" for destination swap are included
            allTokens[i].actionMask = _bridgeTokenActions(config[token].tokenType);
            allTokens[i].token = token;
        }
        (uint256 amountFound, bool[] memory isConnected) = swapQuoter.findConnectedTokens(allTokens, tokenOut);
        tokens = new BridgeToken[](amountFound);
        // This will now track amount of found connected tokens so far during the next for loop
        amountFound = 0;
        for (uint256 i = 0; i < amount; ++i) {
            if (isConnected[i]) {
                // Record the connected token
                address token = allTokens[i].token;
                tokens[amountFound].symbol = tokenToSymbol[token];
                tokens[amountFound].token = token;
                // Increase the counter
                ++amountFound;
            }
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL: SWAP                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Performs a swap from `token` using the provided query,
     * which includes the swap adapter, tokenOut and the swap execution parameters.
     * Swapped token is transferred to the specified recipient.
     */
    function _adapterSwap(
        address recipient,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) internal returns (address tokenOut, uint256 amountOut) {
        // First, check the deadline for the swap
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= query.deadline, "Deadline not met");
        // Pull initial token from the user to specified swap adapter
        _pullToken(query.swapAdapter, token, amount);
        tokenOut = query.tokenOut;
        // If swapAdapter is this contract (which is the case for the supported Synapse pools),
        // this will be an external call to address(this), which we are fine with.
        // The external call is used because additional Adapters will be established in the future.
        // We are forwarding `msg.value` and are expecting the Adapter to handle ETH/WETH interactions.
        amountOut = ISwapAdapter(query.swapAdapter).adapterSwap{value: msg.value}({
            to: recipient,
            tokenIn: token,
            amountIn: amount,
            tokenOut: tokenOut,
            rawParams: query.rawParams
        });
        // We can trust the supported adapters to return the exact swapped amount
        // Finally, check that the recipient received at least as much as they wanted
        require(amountOut >= query.minAmountOut, "Swap didn't result in min tokens");
    }

    /**
     * Pulls a requested token from the user to the requested recipient.
     * Or, if msg.value was provided, check that ETH_ADDRESS was used and msg.value is correct.
     */
    function _pullToken(
        address recipient,
        address token,
        uint256 amount
    ) internal {
        if (msg.value == 0) {
            // Token needs to be pulled only if msg.value is zero
            // This way user can specify WETH as the origin asset
            IERC20(token).safeTransferFrom(msg.sender, recipient, amount);
        } else {
            // Otherwise, we need to check that ETH was specified
            require(token == UniversalToken.ETH_ADDRESS, "!eth");
            // And that amount matches msg.value
            require(msg.value == amount, "!msg.value");
            // We will forward msg.value in the external call to the recipient
        }
    }

    /**
     * @notice Checks whether the swap adapter was specified in the query.
     * Query without a swap adapter specifies that no action needs to be taken.
     */
    function _hasAdapter(SwapQuery memory query) internal pure returns (bool) {
        return query.swapAdapter != address(0);
    }

    function _bridgeTokenActions(TokenType tokenType) internal pure returns (uint256 actionMask) {
        if (tokenType == TokenType.Redeem) {
            // For tokens that are minted on destination chain
            // possible bridge functions are mint() and mintAndSwap(). Thus:
            // Swap: available via mintAndSwap()
            // (Add/Remove)Liquidity is unavailable
            // HandleETH is unavailable, as WETH could only be withdrawn by SynapseBridge
            actionMask = ActionLib.mask(Action.Swap);
        } else {
            // For tokens that are withdrawn on destination chain
            // possible bridge functions are withdraw() and withdrawAndRemove().
            // Swap/AddLiquidity: not available
            // RemoveLiquidity: available via withdrawAndRemove()
            // HandleETH: available via withdraw(). SwapQuoter will check if the bridge token is WETH or not.
            actionMask = ActionLib.mask(Action.RemoveLiquidity, Action.HandleEth);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                 INTERNAL: ADD & REMOVE BRIDGE TOKENS                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Adds a bridge token config and its fee structure, if it's not present.
    /// If a token was added, approves it for spending by SynapseBridge.
    function _addToken(
        string memory symbol,
        address token,
        TokenType tokenType,
        address bridgeToken,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) internal override returns (bool wasAdded) {
        // Add token and its fee structure
        wasAdded = LocalBridgeConfig._addToken(symbol, token, tokenType, bridgeToken, bridgeFee, minFee, maxFee);
        if (wasAdded) {
            // Approve token only if it wasn't previously added
            // Underlying token should always implement allowance(), approve()
            if (token == bridgeToken) token.universalApproveInfinity(address(synapseBridge));
            // Use {setAllowance} for custom wrapper token setups
        }
    }
}
