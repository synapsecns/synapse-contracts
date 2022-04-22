// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/ISwap.sol";
import "../interfaces/ISynapseBridge.sol";
import "../interfaces/IWETH9.sol";

interface IFrax {
    function exchangeCanonicalForOld(address bridge_token_address, uint256 token_amount) external returns (uint256);
}

contract HarmonyBridgeZap {
    using SafeERC20 for IERC20;

    ISynapseBridge synapseBridge;
    address payable public immutable WETH_ADDRESS;
    IFrax private  constant CANOLICAL_FRAX = IFrax(0xFa7191D292d5633f702B0bd7E3E3BcCC0e633200);
    IERC20 private constant SYN_FRAX = IERC20(0x1852F70512298d56e9c8FDd905e02581E04ddb2a);

    mapping(address => address) public swapMap;
    mapping(address => IERC20[]) public swapTokensMap;

    uint256 constant MAX_UINT256 = 2**256 - 1;

    constructor(
        address payable _wethAddress,
        address _swapOne,
        address tokenOne,
        address _swapTwo,
        address tokenTwo,
        address _swapThree,
        address tokenThree,
        address _swapFour,
        address tokenFour,
        ISynapseBridge _synapseBridge
    ) public {
        WETH_ADDRESS = _wethAddress;
        synapseBridge = _synapseBridge;
        swapMap[tokenOne] = _swapOne;
        swapMap[tokenTwo] = _swapTwo;
        swapMap[tokenThree] = _swapThree;
        swapMap[tokenFour] = _swapFour;

        if (address(_swapOne) != address(0)) {
            {
                uint8 i;
                for (; i < 32; i++) {
                    try ISwap(_swapOne).getToken(i) returns (
                        IERC20 token
                    ) {
                        swapTokensMap[_swapOne].push(token);
                        token.safeApprove(address(_swapOne), MAX_UINT256);
                        token.safeApprove(address(synapseBridge), MAX_UINT256);
                    } catch {
                        break;
                    }
                }
                require(i > 1, "swap must have at least 2 tokens");
            }
        }
        if (address(_swapTwo) != address(0)) {
            {
                uint8 i;
                for (; i < 32; i++) {
                    try ISwap(_swapTwo).getToken(i) returns (
                        IERC20 token
                    ) {
                        swapTokensMap[_swapTwo].push(token);
                        token.safeApprove(address(_swapTwo), MAX_UINT256);
                        token.safeApprove(address(synapseBridge), MAX_UINT256);
                    } catch {
                        break;
                    }
                }
                require(i > 1, "swap must have at least 2 tokens");
            }
        }

        if (address(_swapThree) != address(0)) {
            {
                uint8 i;
                for (; i < 32; i++) {
                    try ISwap(_swapThree).getToken(i) returns (
                        IERC20 token
                    ) {
                        swapTokensMap[_swapThree].push(token);
                        token.safeApprove(address(_swapThree), MAX_UINT256);
                        token.safeApprove(address(synapseBridge), MAX_UINT256);
                    } catch {
                        break;
                    }
                }
                require(i > 1, "swap must have at least 2 tokens");
            }
        }

        if (address(_swapFour) != address(0)) {
            {
                uint8 i;
                for (; i < 32; i++) {
                    try ISwap(_swapFour).getToken(i) returns (
                        IERC20 token
                    ) {
                        swapTokensMap[_swapFour].push(token);
                        token.safeApprove(address(_swapFour), MAX_UINT256);
                        token.safeApprove(address(synapseBridge), MAX_UINT256);
                    } catch {
                        break;
                    }
                }
                require(i > 1, "swap must have at least 2 tokens");
            }
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
        ISwap swap = ISwap(
            swapMap[address(token)]
        );
        return swap.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    }

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
        ISwap swap = ISwap(swapMap[address(token)]);
        require(address(swap) != address(0), "Swap is 0x00");
        IERC20[] memory tokens = swapTokensMap[address(swap)];
        tokens[tokenIndexFrom].safeTransferFrom(
            msg.sender,
            address(this),
            dx
        );
        // swap

        uint256 swappedAmount = swap.swap(
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );
        // deposit into bridge, gets nUSD
        if (
            token.allowance(address(this), address(synapseBridge)) <
            swappedAmount
        ) {
            token.safeApprove(address(synapseBridge), MAX_UINT256);
        }
        synapseBridge.redeem(to, chainId, token, swappedAmount);
    }

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
        require(
            address(swapMap[address(token)]) != address(0),
            "Swap is 0x00"
        );
        IERC20[] memory tokens = swapTokensMap[
            swapMap[address(token)]
        ];
        tokens[tokenIndexFrom].safeTransferFrom(
            msg.sender,
            address(this),
            dx
        );
        // swap

        uint256 swappedAmount = ISwap(swapMap[address(token)]).swap(tokenIndexFrom, tokenIndexTo, dx, minDy, deadline);
        // deposit into bridge, gets nUSD
        if (
            token.allowance(address(this), address(synapseBridge)) <
            swappedAmount
        ) {
            token.safeApprove(address(synapseBridge), MAX_UINT256);
        }
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
        ISwap swap = ISwap(swapMap[address(token)]);
        require(address(swap) != address(0), "Swap is 0x00");
        IERC20[] memory tokens = swapTokensMap[address(swap)];
        tokens[tokenIndexFrom].safeTransferFrom(
            msg.sender,
            address(this),
            dx
        );
        // swap

        uint256 swappedAmount = swap.swap(
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );
        // deposit into bridge, gets nUSD
        if (
            token.allowance(address(this), address(synapseBridge)) <
            swappedAmount
        ) {
            token.safeApprove(address(synapseBridge), MAX_UINT256);
        }
        synapseBridge.redeemAndRemove(
            to,
            chainId,
            token,
            swappedAmount,
            liqTokenIndex,
            liqMinAmount,
            liqDeadline
        );
    }

    /**
     * @notice wraps SynapseBridge redeem()
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function redeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        if (address(token) == address(CANOLICAL_FRAX)) {
            uint256 swappedAmount = CANOLICAL_FRAX.exchangeCanonicalForOld(address(SYN_FRAX), amount);
            if (SYN_FRAX.allowance(address(this), address(synapseBridge)) < amount) {
                SYN_FRAX.safeApprove(address(synapseBridge), MAX_UINT256);
            }
            synapseBridge.redeem(to, chainId, SYN_FRAX, swappedAmount);
        } else {
            if (token.allowance(address(this), address(synapseBridge)) < amount) {
                token.safeApprove(address(synapseBridge), MAX_UINT256);
            }
            synapseBridge.redeem(to, chainId, token, amount);
        }
        
    }

    /**
 * @notice Wraps SynapseBridge redeemv2() function
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to redeem into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   **/
    function redeemv2(
        bytes32 to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external {
        token.safeTransferFrom(msg.sender, address(this), amount);

        if (token.allowance(address(this), address(synapseBridge)) < amount) {
            token.safeApprove(address(synapseBridge), MAX_UINT256);
        }
        synapseBridge.redeemv2(to, chainId, token, amount);
    }

    /**
     * @notice wraps SynapseBridge redeem()
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        if (token.allowance(address(this), address(synapseBridge)) < amount) {
            token.safeApprove(address(synapseBridge), MAX_UINT256);
        }
        synapseBridge.deposit(to, chainId, token, amount);
    }

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
        ISwap swap = ISwap(swapMap[address(token)]);
        require(address(swap) != address(0), "Swap is 0x00");
        IWETH9(WETH_ADDRESS).deposit{value: msg.value}();

        // swap
        uint256 swappedAmount = swap.swap(
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );
        synapseBridge.redeem(to, chainId, token, swappedAmount);
    }

    /**
     * @notice Wraps redeemAndSwap on SynapseBridge.sol
     * Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain pre-fees
     * @param tokenIndexFrom the token the user wants to swap from
     * @param tokenIndexTo the token the user wants to swap to
     * @param minDy the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.
     * @param deadline latest timestamp to accept this transaction
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
        token.safeTransferFrom(msg.sender, address(this), amount);
        if (token.allowance(address(this), address(synapseBridge)) < amount) {
            token.safeApprove(address(synapseBridge), MAX_UINT256);
        }
        synapseBridge.redeemAndSwap(
            to,
            chainId,
            token,
            amount,
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline
        );
    }

    /**
     * @notice Wraps redeemAndRemove on SynapseBridge
     * Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount of (typically) LP token to pass to the nodes to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token
     * @param liqTokenIndex Specifies which of the underlying LP assets the nodes should attempt to redeem for
     * @param liqMinAmount Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap
     * @param liqDeadline Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token
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
        token.safeTransferFrom(msg.sender, address(this), amount);
        if (token.allowance(address(this), address(synapseBridge)) < amount) {
            token.safeApprove(address(synapseBridge), MAX_UINT256);
        }
        synapseBridge.redeemAndRemove(
            to,
            chainId,
            token,
            amount,
            liqTokenIndex,
            liqMinAmount,
            liqDeadline
        );
    }
}
