This token is used for configuring different tokens on the bridge and mapping them across chains.



# Functions:
- [`getAllTokenIDs()`](#BridgeConfig-getAllTokenIDs--)
- [`getTokenID(uint256 chainID, address tokenAddress)`](#BridgeConfig-getTokenID-uint256-address-)
- [`getMultichainToken(address tokenID, uint256 chainID)`](#BridgeConfig-getMultichainToken-address-uint256-)
- [`isTokenIDExist(address tokenID)`](#BridgeConfig-isTokenIDExist-address-)
- [`getTokenConfig(address originToken, uint256 originChainID, uint256 destChainId)`](#BridgeConfig-getTokenConfig-address-uint256-uint256-)
- [`setTokenConfig(address tokenID, uint256 chainID, address tokenAddress, uint8 tokenDecimals, uint256 maxSwap, uint256 minSwap, uint256 swapFee, uint256 maxSwapFee, uint256 minSwapFee)`](#BridgeConfig-setTokenConfig-address-uint256-address-uint8-uint256-uint256-uint256-uint256-uint256-)
- [`calculateSwapFee(uint256 chainId, address tokenAddress, uint256 amount)`](#BridgeConfig-calculateSwapFee-uint256-address-uint256-)


# <a id="BridgeConfig-getAllTokenIDs--"></a> Function `getAllTokenIDs() → address[] result`
No description
# <a id="BridgeConfig-getTokenID-uint256-address-"></a> Function `getTokenID(uint256 chainID, address tokenAddress) → address`
No description
# <a id="BridgeConfig-getMultichainToken-address-uint256-"></a> Function `getMultichainToken(address tokenID, uint256 chainID) → address`
No description
# <a id="BridgeConfig-isTokenIDExist-address-"></a> Function `isTokenIDExist(address tokenID) → bool`
No description
# <a id="BridgeConfig-getTokenConfig-address-uint256-uint256-"></a> Function `getTokenConfig(address originToken, uint256 originChainID, uint256 destChainId) → struct BridgeConfig.TokenConfig`
you can pass 0 for origin chain to get the token address on the destination chain
# <a id="BridgeConfig-setTokenConfig-address-uint256-address-uint8-uint256-uint256-uint256-uint256-uint256-"></a> Function `setTokenConfig(address tokenID, uint256 chainID, address tokenAddress, uint8 tokenDecimals, uint256 maxSwap, uint256 minSwap, uint256 swapFee, uint256 maxSwapFee, uint256 minSwapFee) → bool`
No description
# <a id="BridgeConfig-calculateSwapFee-uint256-address-uint256-"></a> Function `calculateSwapFee(uint256 chainId, address tokenAddress, uint256 amount) → uint256`
No description

