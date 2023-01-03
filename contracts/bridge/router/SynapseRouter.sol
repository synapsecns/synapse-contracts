// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/IWETH9.sol";
import "../interfaces/ISynapseBridge.sol";
import "../interfaces/ISwapQuoter.sol";
import "./SynapseAdapter.sol";

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

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
contract SynapseRouter is SynapseAdapter {
    // SynapseRouter is also the Adapter for the Synapse pools (this reduces the amount of token transfers).
    // SynapseRouter address will be used as swapAdapter in SwapQueries returned by a local SwapQuoter.

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @notice Indicates the type of the supported bridge token on the local chain.
     * - TokenType.Redeem: token is burnt in order to initiate a bridge tx (bridge.redeem)
     * - TokenType.Deposit: token is locked in order to initiate a bridge tx (bridge.deposit)
     */
    enum TokenType {
        Redeem,
        Deposit
    }

    /**
     * @notice Config for a supported bridge token.
     * @dev Some of the tokens require a wrapper token to make them conform SynapseERC20 interface.
     * In these cases, `bridgeToken` will feature a different address.
     * Otherwise, the token address is saved.
     * @param tokenType     Method of bridging for the token: Redeem or Deposit
     * @param bridgeToken   Bridge token address
     */
    struct TokenConfig {
        TokenType tokenType;
        address bridgeToken;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        CONSTANTS & IMMUTABLES                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Address of wrapped gas token, that is used by SynapseBridge.
    IWETH9 public immutable weth;
    /// @notice Synapse:Bridge address
    ISynapseBridge public immutable synapseBridge;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Config for each supported token.
    /// @dev If wrapper token is required for bridging, its address is stored in `.bridgeToken`
    /// i.e. for GMX: config[GMX].bridgeToken = GMXWrapper
    mapping(address => TokenConfig) public config;
    /// @dev A list of all supported bridge tokens
    EnumerableSet.AddressSet internal _bridgeTokens;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      CONSTRUCTOR & INITIALIZER                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Creates a SynapseRouter implementation, saves WETH and SynapseBridge address.
     * @dev Redeploy an implementation with different values, if an update is required.
     * Upgrading the proxy implementation then will effectively "update the immutables".
     */
    constructor(address payable _weth, address _synapseBridge) public {
        weth = IWETH9(_weth);
        synapseBridge = ISynapseBridge(_synapseBridge);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Adds a few "Redeem" tokens to the SynapseRouter config.
     * These are bridgeable from this chain by being burnt, i.e. via using synapseBridge.redeem()
     * @dev Every added token is assumed to not require a wrapper token for bridging.
     * Use {addToken} if that is not the case.
     */
    function addRedeemTokens(address[] calldata tokens) external onlyOwner {
        uint256 amount = tokens.length;
        for (uint256 i = 0; i < amount; ++i) {
            _addToken(tokens[i], TokenType.Redeem, tokens[i]);
        }
    }

    /**
     * @notice Adds a few "deposit" tokens to the SynapseRouter config.
     * These are bridgeable from this chain by being locked in SynapseBridge, i.e. via using synapseBridge.deposit()
     * @dev Every added token is assumed to not require a wrapper token for bridging.
     * Use {addToken} if that is not the case.
     */
    function addDepositTokens(address[] calldata tokens) external onlyOwner {
        uint256 amount = tokens.length;
        for (uint256 i = 0; i < amount; ++i) {
            _addToken(tokens[i], TokenType.Deposit, tokens[i]);
        }
    }

    /**
     * @notice Adds a single bridgeable token to the SynapseRouter config.
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending
     * @param tokenType     Method of bridging used for the token: Redeem or Deposit
     * @param bridgeToken   Actual token used for bridging `token`. This is the token bridge is burning/locking.
     *                      Might differ from `token`, if `token` does not conform to bridge-supported interface.
     */
    function addToken(
        address token,
        TokenType tokenType,
        address bridgeToken
    ) external onlyOwner {
        _addToken(token, tokenType, bridgeToken);
    }

    /**
     * @notice Removes a few tokens from the SynapseRouter config.
     * @dev After a token is removed, it won't be possible to bridge it using SynapseRouter,
     * but using SynapseBridge directly is always an option (provided you know what you're doing).
     */
    function removeTokens(address[] calldata tokens) external onlyOwner {
        uint256 amount = tokens.length;
        for (uint256 i = 0; i < amount; ++i) {
            _removeToken(tokens[i]);
        }
    }

    /**
     * @notice Removes a given token from the SynapseRouter config.
     * @dev After a token is removed, it won't be possible to bridge it using SynapseRouter,
     * but using SynapseBridge directly is always an option (provided you know what you're doing).
     */
    function removeToken(address token) external onlyOwner {
        _removeToken(token);
    }

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
     * @notice Initiate a bridge transaction with an optional swap on both
     * origin and destination chains.
     * @dev Note that method is payable.
     * 1. Using a msg.value == 0 forces SynapseRouter to use `token`. This way WETH could be bridged.
     * 2. Using a msg.value != 0 forces SynapseRouter to use native gas. In this case following is required:
     *    - `token` must be SynapseRouter's WETH, otherwise tx will revert
     *    - `amount` must be equal to msg.value, otherwise tx will revert
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
        // Pull initial token from the user
        _pullToken(token, amount);
        // Perform a swap, if requested
        if (_swapRequested(originQuery)) {
            (token, amount) = _adapterSwap(token, amount, originQuery);
        }
        TokenConfig memory _config = config[token];
        require(_config.bridgeToken != address(0), "Token not supported");
        token = _config.bridgeToken;
        // `amount` worth of `token` needs to be bridged.
        // Check if swap on destination chain is required.
        if (_swapRequested(destQuery)) {
            // Decode params for swapping via a Synapse pool on the destination chain.
            SynapseParams memory destParams = abi.decode(destQuery.rawParams, (SynapseParams));
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

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         VIEWS: BRIDGE TOKENS                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns a list of all supported bridge tokens.
     */
    function bridgeTokens() external view returns (address[] memory tokens) {
        uint256 amount = bridgeTokensAmount();
        tokens = new address[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            tokens[i] = _bridgeTokens.at(i);
        }
    }

    /**
     * @notice Returns the amount of the supported bridge tokens.
     */
    function bridgeTokensAmount() public view returns (uint256 amount) {
        amount = _bridgeTokens.length();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL: SWAP                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Performs a swap from `token` using the provided query,
     * which includes the swap adapter, tokenOut and the swap execution parameters.
     */
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
        // If swapAdapter is this contract (which is the case for the supported Synapse pools),
        // this will be an external call to address(this), which we are fine with.
        // The external call is used because additional Adapters will be established in the future.
        amountOut = ISwapAdapter(query.swapAdapter).adapterSwap({
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

    /**
     * Pulls a requested token from the user.
     * Or, if msg.value was provided and WETH was used as token, wraps the received ETH.
     */
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

    /**
     * @notice Checks whether the swap was requested in the query.
     * Query is considered empty (and thus swap-less) if swap adapter address was not specified.
     */
    function _swapRequested(SwapQuery memory query) internal pure returns (bool) {
        return query.swapAdapter != address(0);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                 INTERNAL: ADD & REMOVE BRIDGE TOKENS                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Adds a bridge token to the SynapseRouter config.
     */
    function _addToken(
        address token,
        TokenType tokenType,
        address bridgeToken
    ) internal {
        if (_bridgeTokens.add(token)) {
            config[token] = TokenConfig(tokenType, bridgeToken);
            // Underlying token should always implement allowance(), approve()
            if (token == bridgeToken) _approveToken(IERC20(token), address(synapseBridge));
            // Use {setAllowance} for custom wrapper token setups
        }
    }

    /**
     * @notice Removes a bridge token from the SynapseRouter config.
     */
    function _removeToken(address token) internal {
        if (_bridgeTokens.remove(token)) {
            delete config[token];
        }
    }
}
