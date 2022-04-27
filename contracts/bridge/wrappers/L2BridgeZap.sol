// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/ISwap.sol";
import "../interfaces/ISynapseBridge.sol";
import "../interfaces/IWETH9.sol";

contract L2BridgeZap {
    using SafeERC20 for IERC20;

    ISynapseBridge public immutable synapseBridge;
    // solhint-disable-next-line
    address payable public immutable WETH_ADDRESS;

    mapping(address => address) public swapMap;
    mapping(address => IERC20[]) public swapTokensMap;

    uint256 internal constant MAX_UINT256 = type(uint256).max;

    constructor(
        address payable _wethAddress,
        address[] memory _swaps,
        address[] memory _tokens,
        ISynapseBridge _synapseBridge
    ) public {
        require(_swaps.length == _tokens.length, "Arrays length differs");
        WETH_ADDRESS = _wethAddress;
        synapseBridge = _synapseBridge;
        if (_wethAddress != address(0)) {
            IERC20(_wethAddress).safeApprove(
                address(_synapseBridge),
                MAX_UINT256
            );
        }
        for (uint256 i = 0; i < _swaps.length; ++i) {
            _saveSwap(
                _swaps[i],
                _tokens[i],
                address(_synapseBridge),
                _wethAddress
            );
        }
    }

    function _saveSwap(
        address _swap,
        address _token,
        address _synapseBridge,
        address payable _wethAddress
    ) internal {
        swapMap[_token] = _swap;

        uint8 i;
        for (; i < 32; i++) {
            try ISwap(_swap).getToken(i) returns (IERC20 token) {
                swapTokensMap[_swap].push(token);
                token.safeApprove(address(_swap), MAX_UINT256);
                // Bridge is already allowed to spend WETH
                if (address(token) != _wethAddress) {
                    token.safeApprove(_synapseBridge, MAX_UINT256);
                }
            } catch {
                break;
            }
        }
        require(i > 1, "swap must have at least 2 tokens");
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
        ISwap swap = ISwap(swapMap[address(token)]);
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
        tokens[tokenIndexFrom].safeTransferFrom(msg.sender, address(this), dx);
        // swap

        uint256 swappedAmount = swap.swap(
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );
        // token already approved for spending in _saveSwap()
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
        require(address(swapMap[address(token)]) != address(0), "Swap is 0x00");
        IERC20[] memory tokens = swapTokensMap[swapMap[address(token)]];
        tokens[tokenIndexFrom].safeTransferFrom(msg.sender, address(this), dx);
        // swap

        uint256 swappedAmount = ISwap(swapMap[address(token)]).swap(
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );
        // token already approved for spending in _saveSwap()
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
        tokens[tokenIndexFrom].safeTransferFrom(msg.sender, address(this), dx);
        // swap

        uint256 swappedAmount = swap.swap(
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );
        // token already approved for spending in _saveSwap()
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
        // token might have not been approved in _saveSwap()
        _approveIfNeeded(token, amount);
        synapseBridge.redeem(to, chainId, token, amount);
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
        // token might have not been approved in _saveSwap()
        _approveIfNeeded(token, amount);
        synapseBridge.deposit(to, chainId, token, amount);
    }

    /**
     * @notice Wraps SynapseBridge deposit() function to make it compatible w/ ETH -> WETH conversions
     * @param to address on other chain to bridge assets to
     * @param chainId which chain to bridge assets onto
     * @param amount Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function depositETH(
        address to,
        uint256 chainId,
        uint256 amount
    ) external payable {
        require(msg.value > 0 && msg.value == amount, "INCORRECT MSG VALUE");
        IWETH9(WETH_ADDRESS).deposit{value: msg.value}();
        // WETH was approved for spending in constructor
        synapseBridge.deposit(to, chainId, IERC20(WETH_ADDRESS), amount);
    }

    /**
     * @notice Wraps SynapseBridge depositAndSwap() function to make it compatible w/ ETH -> WETH conversions
     * @param to address on other chain to bridge assets to
     * @param chainId which chain to bridge assets onto
     * @param amount Amount in native token decimals to transfer cross-chain pre-fees
     * @param tokenIndexFrom the token the user wants to swap from
     * @param tokenIndexTo the token the user wants to swap to
     * @param minDy the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.
     * @param deadline latest timestamp to accept this transaction
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
        require(msg.value > 0 && msg.value == amount, "INCORRECT MSG VALUE");
        IWETH9(WETH_ADDRESS).deposit{value: msg.value}();
        // WETH was approved for spending in constructor
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
        // token already approved for spending in _saveSwap()
        synapseBridge.redeem(to, chainId, token, swappedAmount);
    }

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
        // token already approved for spending in _saveSwap()
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
     * @notice Wraps redeemAndSwap on SynapseBridge.sol
     * Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
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
        // token might have not been approved in _saveSwap()
        _approveIfNeeded(token, amount);
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
     * Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount of (typically) LP token to pass to the nodes to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token
     * @param liqTokenIndex Specifies which of the underlying LP assets the nodes should attempt to redeem for
     * @param liqMinAmount Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap
     * @param liqDeadline Specifies the deadline that the nodes are allowed to try to redeem/swap the LP token
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
        // token might have not been approved in _saveSwap()
        _approveIfNeeded(token, amount);
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

    /**
     * @notice Wraps SynapseBridge redeemV2() function
     * @param to address on other chain to bridge assets to
     * @param chainId which chain to bridge assets onto
     * @param token ERC20 compatible token to redeem into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function redeemV2(
        bytes32 to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        // token might have not been approved in _saveSwap()
        _approveIfNeeded(token, amount);
        synapseBridge.redeemV2(to, chainId, token, amount);
    }

    /**
     * @notice Allow Synapse:Bridge to spend token, 
     * if existing allowance is not big enough
     */
    function _approveIfNeeded(IERC20 token, uint256 amount) internal {
        if (token.allowance(address(this), address(synapseBridge)) < amount) {
            token.safeApprove(address(synapseBridge), MAX_UINT256);
        }
    }
}
