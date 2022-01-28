// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract SynapseBridgeV2 {
    constructor() public {}

    event TokenDepositAndSwapV2(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        address[] path,
        address[] adapters,
        uint256 maxBridgeSlippage
    );
    event TokenMintAndSwapV2(
        address indexed to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        address[] path,
        address[] adapters,
        uint256 maxBridgeSlippage,
        bool swapSuccess,
        bytes32 indexed kappa
    );
    event TokenRedeemAndSwapV2(
        address indexed to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        address[] path,
        address[] adapters,
        uint256 maxBridgeSlippage
    );
    event TokenWithdrawAndSwapV2(
        address indexed to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        address[] path,
        address[] adapters,
        uint256 maxBridgeSlippage,
        bool swapSuccess,
        bytes32 indexed kappa
    );

    // ******* V2 FUNCTIONS
    /**
   * @notice Relays to nodes to both transfer an ERC20 token cross-chain, and then have the nodes execute a swap through a liquidity pool on behalf of the user.
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge

   **/
    function depositMaxAndSwapV2(
        address to,
        uint256 chainId,
        IERC20 token,
        address[] calldata path,
        address[] calldata adapters,
        uint256 maxBridgeSlippage
    ) external nonReentrant() whenNotPaused() {
        uint256 amount = getMaxAmount(token);
        emit TokenDepositAndSwapV2(
            to,
            chainId,
            token,
            amount,
            path,
            adapters,
            maxBridgeSlippage
        );
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
   * @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge

   **/
    function redeemMaxAndSwapV2(
        address to,
        uint256 chainId,
        ERC20Burnable token,
        address[] calldata path,
        address[] calldata adapters,
        uint256 maxBridgeSlippage
    ) external nonReentrant() whenNotPaused() {
        uint256 amount = getMaxAmount(token);
        emit TokenRedeemAndSwapV2(
            to,
            chainId,
            token,
            amount,
            path,
            adapters,
            maxBridgeSlippage
        );
        token.burnFrom(msg.sender, amount);
    }

    function handleRouterSwap(
        address to,
        uint256 amountSubFee,
        RouterTrade calldata _trade
    ) private returns (bool) {
        try
        IRouter(ROUTER).selfSwap(
            amountSubFee,
            0,
            _trade.path,
            _trade.adapters,
            to,
            0
        )
        {
            return true;
        } catch {
            return false;
        }
    }

    /**
   * @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to), and then attempt to swap the SynERC20 into the desired destination asset. This is called by the nodes after a TokenDepositAndSwapV2 event is emitted.
   * @dev This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted
   * @param to address on other chain to redeem underlying assets to
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain post-fees
   * @param fee Amount in native token decimals to save to the contract as fees

   * @param kappa kappa
   **/
    function mintAndSwapV2(
        address payable to,
        IERC20Mintable token,
        uint256 amount,
        uint256 fee,
        RouterTrade calldata _trade,
        bytes32 kappa
    ) external nonReentrant() whenNotPaused() {
        validateBridgeFunction(amount, fee, kappa);
        uint256 amountSubFee = amount - fee;
        fees[address(token)] = fees[address(token)] + fee;

        // Transfer gas airdrop
        if (checkChainGasAmount()) {
            (bool success, ) = to.call{value: chainGasAmount}("");
            require(success, "GAS_AIRDROP_FAILED");
        }

        token.mint(ROUTER, amountSubFee);
        token.mint(address(this), fee);

        bool swapSuccess = handleRouterSwap(to, amountSubFee, _trade);
        if (swapSuccess) {
            emit TokenMintAndSwapV2(
                to,
                token,
                amountSubFee,
                fee,
                _trade.path,
                _trade.adapters,
                _trade.maxBridgeSlippage,
                true,
                kappa
            );
        } else {
            token.safeTransferFrom(ROUTER, to, amountSubFee);
            emit TokenMintAndSwapV2(
                to,
                token,
                amountSubFee,
                fee,
                _trade.path,
                _trade.adapters,
                _trade.maxBridgeSlippage,
                false,
                kappa
            );
        }
    }

    /**
     * @notice Function to be called by the node group to withdraw the underlying assets from the contract
     * @param to address on chain to send underlying assets to
     * @param token ERC20 compatible token to withdraw from the bridge
     * @param amount Amount in native token decimals to withdraw
     * @param fee Amount in native token decimals to save to the contract as fees
     * @param kappa kappa
     **/
    function withdrawAndSwapV2(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        RouterTrade calldata _trade,
        bytes32 kappa
    ) external nonReentrant() whenNotPaused() {
        validateBridgeFunction(amount, fee, kappa);
        uint256 amountSubFee = amount - fee;
        fees[address(token)] = fees[address(token)] + fee;

        // Transfer gas airdrop
        if (checkChainGasAmount()) {
            (bool success, ) = to.call{value: chainGasAmount}("");
            require(success, "GAS_AIRDROP_FAILED");
        }

        token.safeTransfer(ROUTER, amountSubFee);
        // (bool success, bytes memory result) = ROUTER.call(routeraction);
        //  if (success) {
        //   // Swap successful
        //   emit TokenWithdrawAndSwapV2(to, token, amount.sub(fee), fee, routeraction, true, kappa);
        // } else {
        //     IERC20(token).safeTransferFrom(ROUTER, to, amount.sub(fee));
        //     emit TokenWithdrawAndSwapV2(to, token, amount.sub(fee), fee, routeraction, false, kappa);
        // }
        bool swapSuccess = handleRouterSwap(to, amountSubFee, _trade);
        if (swapSuccess) {
            emit TokenWithdrawAndSwapV2(
                to,
                token,
                amountSubFee,
                fee,
                _trade.path,
                _trade.adapters,
                _trade.maxBridgeSlippage,
                true,
                kappa
            );
        } else {
            token.safeTransferFrom(ROUTER, to, amountSubFee);
            emit TokenWithdrawAndSwapV2(
                to,
                token,
                amountSubFee,
                fee,
                _trade.path,
                _trade.adapters,
                _trade.maxBridgeSlippage,
                false,
                kappa
            );
        }
        // try IRouter(ROUTER).selfSwap(amountSubFee, 0, path, adapters, to, 0) {
        //   emit TokenWithdrawAndSwapV2(to, token, amountSubFee, fee, path, adapters, maxBridgeSlippage, true, kappa);
        // } catch {
        //   IERC20(token).safeTransferFrom(ROUTER, to, amount.sub(fee));
        //   emit TokenWithdrawAndSwapV2(to, token, amountSubFee, fee, path, adapters, maxBridgeSlippage, false, kappa);
        // }
    }

    function checkChainGasAmount() internal view returns (bool) {
        return chainGasAmount != 0 && address(this).balance >= chainGasAmount;
    }

    function getMaxAmount(IERC20 token) internal view returns (uint256) {
        uint256 allowance = token.allowance(msg.sender, address(this));
        uint256 tokenBalance = token.balanceOf(msg.sender);
        return (allowance > tokenBalance) ? tokenBalance : allowance;
    }

    function transferToken(
        address to,
        IERC20 token,
        uint256 amount
    ) internal {
        if (address(token) == WETH_ADDRESS && WETH_ADDRESS != address(0)) {
            IWETH9(WETH_ADDRESS).withdraw(amount);
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH_TRANSFER_FAILED");
        } else {
            token.safeTransfer(to, amount);
        }
    }
}
