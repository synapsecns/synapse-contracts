// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ISwap.sol";
import "../interfaces/ISynapseBridge.sol";
import "../interfaces/IWETH9.sol";

contract L2BridgeZap is Ownable {
    using SafeERC20 for IERC20;

    ISynapseBridge public immutable synapseBridge;
    // solhint-disable-next-line var-name-mixedcase
    address payable public immutable WETH_ADDRESS;

    mapping(IERC20 => ISwap) public swapMap;
    mapping(ISwap => IERC20[]) public swapTokensMap;

    uint256 internal constant MAX_UINT256 = 2**256 - 1;

    constructor(
        address payable _wethAddress,
        ISwap[] memory _swaps,
        IERC20[] memory _bridgeTokens,
        ISynapseBridge _synapseBridge
    ) public {
        require(_swaps.length == _bridgeTokens.length, "!arrays");
        WETH_ADDRESS = _wethAddress;
        synapseBridge = _synapseBridge;
        if (_wethAddress != address(0)) {
            _setInfiniteAllowance(IERC20(_wethAddress), address(_synapseBridge));
        }
        for (uint256 i = 0; i < _swaps.length; ++i) {
            _setTokenPool(_swaps[i], _bridgeTokens[i], address(_synapseBridge));
        }
    }

    /**
     * @notice Calculate amount of tokens you receive on swap
     * @param tokenIndexFrom the token the user wants to sell
     * @param tokenIndexTo the token the user wants to buy
     * @param dx the amount of tokens the user wants to sell. If the token charges
     * a fee on transfers, use the amount that gets transferred after the fee.
     * @return amount of tokens the user will receive
     */
    function calculateSwap(
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view virtual returns (uint256) {
        ISwap swap = swapMap[token];
        return swap.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              ONLY OWNER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function setInfiniteAllowance(IERC20 _token, address _spender) external onlyOwner {
        _setInfiniteAllowance(_token, _spender);
    }

    function setTokenPool(ISwap _swap, IERC20 _bridgeToken) external onlyOwner {
        _setTokenPool(_swap, _bridgeToken, address(synapseBridge));
    }

    function removeTokenPool(IERC20 _bridgeToken) external onlyOwner {
        swapMap[_bridgeToken] = ISwap(address(0));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         ZAP FUNCTIONS: SWAP                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Swaps a token and then bridges the received token using SynapseBridge.redeem()
     * @param to                Address on other chain to receive tokens
     * @param chainId           Which chain to bridge assets onto
     * @param token             ERC20 compatible token to redeem into the bridge
     * @param tokenIndexFrom    Index of token user want to swap from
     * @param tokenIndexTo      Index of token that will be used for bridging (see `token` above)
     * @param dx                Amount in native token decimals to swap on this chain
     * @param minDy             The min amount of bridge token obtained after the swap, or transaction will revert
     * @param deadline          Latest timestamp to accept this transaction
     */
    function swapAndRedeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external {
        ISwap swap = swapMap[token];
        require(address(swap) != address(0), "Swap is 0x00");
        IERC20[] memory tokens = swapTokensMap[swap];
        tokens[tokenIndexFrom].safeTransferFrom(msg.sender, address(this), dx);
        // swap allowance was given in _setTokenPool()
        uint256 swappedAmount = swap.swap(tokenIndexFrom, tokenIndexTo, dx, minDy, deadline);
        // synapseBridge allowance was given in _setTokenPool()
        synapseBridge.redeem(to, chainId, token, swappedAmount);
    }

    /**
     * @notice Swaps a token and then bridges the received token using SynapseBridge.redeemAndSwap()
     * @param to                    Address on other chain to receive tokens
     * @param chainId               Which chain to bridge assets onto
     * @param token                 ERC20 compatible token to redeem into the bridge
     * @param tokenIndexFrom        Index of token user want to swap from
     * @param tokenIndexTo          Index of token that will be used for bridging (see `token` above)
     * @param dx                    Amount in native token decimals to swap on this chain
     * @param minDy                 The min amount of bridge token obtained after the swap, or transaction will revert
     * @param deadline              Latest timestamp to accept this transaction
     * @param swapTokenIndexFrom    Index of token that will be used for bridging on remote chain
     * @param swapTokenIndexTo      Index of token that user would like to receive on remote chain
     * @param swapMinDy             The min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain
     * @param swapDeadline          Latest timestamp to perform a swap on remote chain, or revert to only minting the SynERC20 token crosschain
     */
    function swapAndRedeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 swapTokenIndexFrom,
        uint8 swapTokenIndexTo,
        uint256 swapMinDy,
        uint256 swapDeadline
    ) external {
        require(address(swapMap[token]) != address(0), "Swap is 0x00");
        IERC20[] memory tokens = swapTokensMap[swapMap[token]];
        tokens[tokenIndexFrom].safeTransferFrom(msg.sender, address(this), dx);
        // swap allowance was given in _setTokenPool()
        uint256 swappedAmount = swapMap[token].swap(tokenIndexFrom, tokenIndexTo, dx, minDy, deadline);
        // synapseBridge allowance was given in _setTokenPool()
        synapseBridge.redeemAndSwap(
            to,
            chainId,
            token,
            swappedAmount,
            swapTokenIndexFrom,
            swapTokenIndexTo,
            swapMinDy,
            swapDeadline
        );
    }

    /**
     * @notice Swaps a token and then bridges the received token using SynapseBridge.redeemAndRemove()
     * @param to                Address on other chain to receive tokens
     * @param chainId           Which chain to bridge assets onto
     * @param token             ERC20 compatible token to redeem into the bridge
     * @param tokenIndexFrom    Index of token user want to swap from
     * @param tokenIndexTo      Index of token that will be used for bridging (see `token` above)
     * @param dx                Amount in native token decimals to swap on this chain
     * @param minDy             The min amount of bridge token obtained after the swap, or transaction will revert
     * @param deadline          Latest timestamp to accept this transaction
     * @param liqTokenIndex     Index of token that user would like to receive on remote chain
     * @param liqMinAmount      The min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain
     * @param liqDeadline       Latest timestamp to perform a swap on remote chain, or revert to only minting the SynERC20 token crosschain
     */
    function swapAndRedeemAndRemove(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 liqTokenIndex,
        uint256 liqMinAmount,
        uint256 liqDeadline
    ) external {
        ISwap swap = swapMap[token];
        require(address(swap) != address(0), "Swap is 0x00");
        IERC20[] memory tokens = swapTokensMap[swap];
        tokens[tokenIndexFrom].safeTransferFrom(msg.sender, address(this), dx);
        // swap allowance was given in _setTokenPool()
        uint256 swappedAmount = swap.swap(tokenIndexFrom, tokenIndexTo, dx, minDy, deadline);
        // synapseBridge allowance was given in _setTokenPool()
        synapseBridge.redeemAndRemove(to, chainId, token, swappedAmount, liqTokenIndex, liqMinAmount, liqDeadline);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      ZAP FUNCTIONS: SWAP (ETH)                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Swaps native gas and then bridges the received token using SynapseBridge.redeemAndRemove()
     * @param to                Address on other chain to receive tokens
     * @param chainId           Which chain to bridge assets onto
     * @param token             ERC20 compatible token to redeem into the bridge
     * @param tokenIndexFrom    Index of token user want to swap from
     * @param tokenIndexTo      Index of token that will be used for bridging (see `token` above)
     * @param dx                Amount in native gas decimals to swap on this chain
     * @param minDy             The min amount of bridge token obtained after the swap, or transaction will revert
     * @param deadline          Latest timestamp to accept this transaction
     */
    function swapETHAndRedeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external payable {
        require(WETH_ADDRESS != address(0), "WETH 0");
        require(msg.value > 0 && msg.value == dx, "INCORRECT MSG VALUE");
        ISwap swap = swapMap[token];
        require(address(swap) != address(0), "Swap is 0x00");
        IWETH9(WETH_ADDRESS).deposit{value: msg.value}();
        // swap allowance was given in _setTokenPool()
        uint256 swappedAmount = swap.swap(tokenIndexFrom, tokenIndexTo, dx, minDy, deadline);
        // synapseBridge allowance was given in _setTokenPool()
        synapseBridge.redeem(to, chainId, token, swappedAmount);
    }

    /**
     * @notice Swaps native gas and then bridges the received token using SynapseBridge.redeemAndSwap()
     * @param to                    Address on other chain to receive tokens
     * @param chainId               Which chain to bridge assets onto
     * @param token                 ERC20 compatible token to redeem into the bridge
     * @param tokenIndexFrom        Index of token user want to swap from
     * @param tokenIndexTo          Index of token that will be used for bridging (see `token` above)
     * @param dx                    Amount in native gas decimals to swap on this chain
     * @param minDy                 The min amount of bridge token obtained after the swap, or transaction will revert
     * @param deadline              Latest timestamp to accept this transaction
     * @param swapTokenIndexFrom    Index of token that will be used for bridging on remote chain
     * @param swapTokenIndexTo      Index of token that user would like to receive on remote chain
     * @param swapMinDy             The min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain
     * @param swapDeadline          Latest timestamp to perform a swap on remote chain, or revert to only minting the SynERC20 token crosschain
     */
    function swapETHAndRedeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 swapTokenIndexFrom,
        uint8 swapTokenIndexTo,
        uint256 swapMinDy,
        uint256 swapDeadline
    ) external payable {
        require(WETH_ADDRESS != address(0), "WETH 0");
        require(msg.value > 0 && msg.value == dx, "INCORRECT MSG VALUE");
        ISwap swap = swapMap[token];
        require(address(swap) != address(0), "Swap is 0x00");
        IWETH9(WETH_ADDRESS).deposit{value: msg.value}();
        // swap allowance was given in _setTokenPool()
        uint256 swappedAmount = swap.swap(tokenIndexFrom, tokenIndexTo, dx, minDy, deadline);
        // synapseBridge allowance was given in _setTokenPool()
        synapseBridge.redeemAndSwap(
            to,
            chainId,
            token,
            swappedAmount,
            swapTokenIndexFrom,
            swapTokenIndexTo,
            swapMinDy,
            swapDeadline
        );
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                    ZAP FUNCTIONS: REDEEM│DEPOSIT                     ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Wraps SynapseBridge.redeem()
     * @param to        Address on other chain to receive tokens
     * @param chainId   Which chain to bridge assets onto
     * @param token     ERC20 compatible token to redeem into the bridge
     * @param amount    Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function redeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external {
        _pullAndApprove(token, amount);
        synapseBridge.redeem(to, chainId, token, amount);
    }

    /**
     * @notice Wraps SynapseBridge.redeemAndSwap()
     * @param to                Address on other chain to receive tokens
     * @param chainId           Which chain to bridge assets onto
     * @param token             ERC20 compatible token to redeem into the bridge
     * @param amount            Amount in native token decimals to transfer cross-chain pre-fees
     * @param tokenIndexFrom    Index of token that will be used for bridging on remote chain
     * @param tokenIndexTo      Index of token that user would like to receive on remote chain
     * @param minDy             The min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain
     * @param deadline          Latest timestamp to perform a swap on remote chain, or revert to only minting the SynERC20 token crosschain
     **/
    function redeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external {
        _pullAndApprove(token, amount);
        synapseBridge.redeemAndSwap(to, chainId, token, amount, tokenIndexFrom, tokenIndexTo, minDy, deadline);
    }

    /**
     * @notice Wraps SynapseBridge.redeemAndRemove()
     * @param to            Address on other chain to receive tokens
     * @param chainId       Which chain to bridge assets onto
     * @param token         ERC20 compatible token to redeem into the bridge
     * @param amount        Amount in native token decimals to transfer cross-chain pre-fees
     * @param liqTokenIndex Index of token that user would like to receive on remote chain
     * @param liqMinAmount  The min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain
     * @param liqDeadline   Latest timestamp to perform a swap on remote chain, or revert to only minting the SynERC20 token crosschain
     **/
    function redeemAndRemove(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 liqTokenIndex,
        uint256 liqMinAmount,
        uint256 liqDeadline
    ) external {
        _pullAndApprove(token, amount);
        synapseBridge.redeemAndRemove(to, chainId, token, amount, liqTokenIndex, liqMinAmount, liqDeadline);
    }

    /**
     * @notice Wraps SynapseBridge.redeemV2()
     * @param to        Address on other chain to receive tokens
     * @param chainId   Which chain to bridge assets onto
     * @param token     ERC20 compatible token to redeem into the bridge
     * @param amount    Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function redeemV2(
        bytes32 to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external {
        _pullAndApprove(token, amount);
        synapseBridge.redeemV2(to, chainId, token, amount);
    }

    /**
     * @notice Wraps SynapseBridge.deposit()
     * @param to        Address on other chain to receive tokens
     * @param chainId   Which chain to bridge assets onto
     * @param token     ERC20 compatible token to deposit into the bridge
     * @param amount    Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external {
        _pullAndApprove(token, amount);
        synapseBridge.deposit(to, chainId, token, amount);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     ZAP FUNCTIONS: DEPOSIT (ETH)                     ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Wraps SynapseBridge.deposit() for deposits of WGAS using native gas
     * @param to        Address on other chain to receive tokens
     * @param chainId   Which chain to bridge assets onto
     * @param amount    Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function depositETH(
        address to,
        uint256 chainId,
        uint256 amount
    ) external payable {
        require(WETH_ADDRESS != address(0), "WETH 0");
        require(msg.value > 0 && msg.value == amount, "INCORRECT MSG VALUE");
        IWETH9(WETH_ADDRESS).deposit{value: msg.value}();
        // WETH inf allowance was set in the constructor
        synapseBridge.deposit(to, chainId, IERC20(WETH_ADDRESS), amount);
    }

    /**
     * @notice Wraps SynapseBridge.depositAndSwap() for deposits of WGAS using native gas
     * @param to                Address on other chain to receive tokens
     * @param chainId           Which chain to bridge assets onto
     * @param amount            Amount in native token decimals to transfer cross-chain pre-fees
     * @param tokenIndexFrom    Index of token that will be used for bridging on remote chain
     * @param tokenIndexTo      Index of token that user would like to receive on remote chain
     * @param minDy             The min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain
     * @param deadline          Latest timestamp to perform a swap on remote chain, or revert to only minting the SynERC20 token crosschain
     **/
    function depositETHAndSwap(
        address to,
        uint256 chainId,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    ) external payable {
        require(WETH_ADDRESS != address(0), "WETH 0");
        require(msg.value > 0 && msg.value == amount, "INCORRECT MSG VALUE");
        IWETH9(WETH_ADDRESS).deposit{value: msg.value}();
        // WETH inf allowance was set in the constructor
        synapseBridge.depositAndSwap(
            to,
            chainId,
            IERC20(WETH_ADDRESS),
            amount,
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline
        );
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Collects token from user and approves its spending by the SynapseBridge.
    function _pullAndApprove(IERC20 _token, uint256 _amount) internal {
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        // set infinite allowance if it hasn't been set before
        _setInfiniteAllowance(_token, address(synapseBridge));
    }

    /// @dev Sets infinite allowance for a token using as little token.approve() call as possible.
    function _setInfiniteAllowance(IERC20 _token, address _spender) internal {
        uint256 allowance = _token.allowance(address(this), _spender);
        // check if inf allowance has been granted
        if (allowance != MAX_UINT256) {
            /// @dev We can get away with using approve instead of safeApprove,
            /// as we're either setting the allowance to zero, or changing it from zero

            // If allowance is non-zero, we need to clear it first, as some tokens
            // have a built-in defense against changing allowance from non-zero to non-zero.
            // eg: USDT on Mainnet
            if (allowance != 0) _token.approve(_spender, 0);
            _token.approve(_spender, MAX_UINT256);
        }
    }

    /// @dev Registers a swap pool as the liquidity pool for a bridge token. Also sets infinite allowances for later use.
    function _setTokenPool(
        ISwap _swap,
        IERC20 _bridgeToken,
        address _synapseBridge
    ) internal {
        // do nothing, if swap is already saved
        // SLOAD + SSTORE doesn't waste any gas compared to just SSTORE
        if (address(swapMap[_bridgeToken]) == address(_swap)) return;
        swapMap[_bridgeToken] = _swap;
        // load tokens from a swap pool exactly once
        if (swapTokensMap[_swap].length == 0) {
            for (uint256 i = 0; ; ++i) {
                try _swap.getToken(uint8(i)) returns (IERC20 token) {
                    swapTokensMap[_swap].push(token);
                    // allow swap pool to spend all pool tokens
                    _setInfiniteAllowance(token, address(_swap));
                } catch {
                    break;
                }
            }
        }
        // allow bridge to spend _bridgeToken
        _setInfiniteAllowance(IERC20(_bridgeToken), address(_synapseBridge));
    }
}
