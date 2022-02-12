


# Functions:
- [`constructor(contract IMetaSwapDeposit _metaSwap, contract ISynapseBridge _synapseBridge)`](#NerveMetaBridgeZap-constructor-contract-IMetaSwapDeposit-contract-ISynapseBridge-)
- [`calculateSwap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx)`](#NerveMetaBridgeZap-calculateSwap-uint8-uint8-uint256-)
- [`swapAndRedeem(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline)`](#NerveMetaBridgeZap-swapAndRedeem-address-uint256-contract-IERC20-uint8-uint8-uint256-uint256-uint256-)
- [`swapAndRedeemAndSwap(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline, uint8 swapTokenIndexFrom, uint8 swapTokenIndexTo, uint256 swapMinDy, uint256 swapDeadline)`](#NerveMetaBridgeZap-swapAndRedeemAndSwap-address-uint256-contract-IERC20-uint8-uint8-uint256-uint256-uint256-uint8-uint8-uint256-uint256-)
- [`swapAndRedeemAndRemove(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline, uint8 liqTokenIndex, uint256 liqMinAmount, uint256 liqDeadline)`](#NerveMetaBridgeZap-swapAndRedeemAndRemove-address-uint256-contract-IERC20-uint8-uint8-uint256-uint256-uint256-uint8-uint256-uint256-)
- [`redeem(address to, uint256 chainId, contract IERC20 token, uint256 amount)`](#NerveMetaBridgeZap-redeem-address-uint256-contract-IERC20-uint256-)
- [`redeemAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)`](#NerveMetaBridgeZap-redeemAndSwap-address-uint256-contract-IERC20-uint256-uint8-uint8-uint256-uint256-)
- [`redeemAndRemove(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 liqTokenIndex, uint256 liqMinAmount, uint256 liqDeadline)`](#NerveMetaBridgeZap-redeemAndRemove-address-uint256-contract-IERC20-uint256-uint8-uint256-uint256-)


# <a id="NerveMetaBridgeZap-constructor-contract-IMetaSwapDeposit-contract-ISynapseBridge-"></a> Function `constructor(contract IMetaSwapDeposit _metaSwap, contract ISynapseBridge _synapseBridge)`
No description
# <a id="NerveMetaBridgeZap-calculateSwap-uint8-uint8-uint256-"></a> Function `calculateSwap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx) → uint256`
No description
## Parameters:
- `tokenIndexFrom`: the token the user wants to sell

- `tokenIndexTo`: the token the user wants to buy

- `dx`: the amount of tokens the user wants to sell. If the token charges
a fee on transfers, use the amount that gets transferred after the fee.

## Return Values:
- amount of tokens the user will receive
# <a id="NerveMetaBridgeZap-swapAndRedeem-address-uint256-contract-IERC20-uint8-uint8-uint256-uint256-uint256-"></a> Function `swapAndRedeem(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline)`
No description
# <a id="NerveMetaBridgeZap-swapAndRedeemAndSwap-address-uint256-contract-IERC20-uint8-uint8-uint256-uint256-uint256-uint8-uint8-uint256-uint256-"></a> Function `swapAndRedeemAndSwap(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline, uint8 swapTokenIndexFrom, uint8 swapTokenIndexTo, uint256 swapMinDy, uint256 swapDeadline)`
No description
# <a id="NerveMetaBridgeZap-swapAndRedeemAndRemove-address-uint256-contract-IERC20-uint8-uint8-uint256-uint256-uint256-uint8-uint256-uint256-"></a> Function `swapAndRedeemAndRemove(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline, uint8 liqTokenIndex, uint256 liqMinAmount, uint256 liqDeadline)`
No description
# <a id="NerveMetaBridgeZap-redeem-address-uint256-contract-IERC20-uint256-"></a> Function `redeem(address to, uint256 chainId, contract IERC20 token, uint256 amount)`
No description
## Parameters:
- `to`: address on other chain to redeem underlying assets to

- `chainId`: which underlying chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

# <a id="NerveMetaBridgeZap-redeemAndSwap-address-uint256-contract-IERC20-uint256-uint8-uint8-uint256-uint256-"></a> Function `redeemAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)`
No description
## Parameters:
- `to`: address on other chain to redeem underlying assets to

- `chainId`: which underlying chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

- `tokenIndexFrom`: the token the user wants to swap from

- `tokenIndexTo`: the token the user wants to swap to

- `minDy`: the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.

- `deadline`: latest timestamp to accept this transaction

# <a id="NerveMetaBridgeZap-redeemAndRemove-address-uint256-contract-IERC20-uint256-uint8-uint256-uint256-"></a> Function `redeemAndRemove(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 liqTokenIndex, uint256 liqMinAmount, uint256 liqDeadline)`
No description
## Parameters:
- `to`: address on other chain to redeem underlying assets to

- `chainId`: which underlying chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount of (typically) LP token to pass to the nodes to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token 

- `liqTokenIndex`: Specifies which of the underlying LP assets the nodes should attempt to redeem for

- `liqMinAmount`: Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap

- `liqDeadline`: Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token


