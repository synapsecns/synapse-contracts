


# Functions:
- [`constructor(contract IMetaSwapDeposit _metaSwap, contract ISynapseBridge _synapseBridge)`](#NerveMetaBridgeZap-constructor-contract-IMetaSwapDeposit-contract-ISynapseBridge-)
- [`calculateSwap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx)`](#NerveMetaBridgeZap-calculateSwap-uint8-uint8-uint256-)
- [`swapAndRedeem(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline)`](#NerveMetaBridgeZap-swapAndRedeem-address-uint256-contract-IERC20-uint8-uint8-uint256-uint256-uint256-)
- [`swapAndRedeemAndRemove(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline, uint8 liqTokenIndex, uint256 liqMinAmount, uint256 liqDeadline)`](#NerveMetaBridgeZap-swapAndRedeemAndRemove-address-uint256-contract-IERC20-uint8-uint8-uint256-uint256-uint256-uint8-uint256-uint256-)


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
# <a id="NerveMetaBridgeZap-swapAndRedeemAndRemove-address-uint256-contract-IERC20-uint8-uint8-uint256-uint256-uint256-uint8-uint256-uint256-"></a> Function `swapAndRedeemAndRemove(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline, uint8 liqTokenIndex, uint256 liqMinAmount, uint256 liqDeadline)`
No description

