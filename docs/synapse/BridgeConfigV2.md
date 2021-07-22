This token is used for configuring different tokens on the bridge and mapping them across chains.



# Functions:
- [`getAllTokenIDs()`](#BridgeConfigV2-getAllTokenIDs--)
- [`getTokenID(address tokenAddress, uint256 chainID)`](#BridgeConfigV2-getTokenID-address-uint256-)
- [`getToken(string tokenID, uint256 chainID)`](#BridgeConfigV2-getToken-string-uint256-)
- [`getToken(address tokenAddress, uint256 chainID)`](#BridgeConfigV2-getToken-address-uint256-)
- [`hasUnderlyingToken(string tokenID)`](#BridgeConfigV2-hasUnderlyingToken-string-)
- [`getUnderlyingToken(string tokenID)`](#BridgeConfigV2-getUnderlyingToken-string-)
- [`isTokenIDExist(string tokenID)`](#BridgeConfigV2-isTokenIDExist-string-)
- [`setTokenConfig(string tokenID, uint256 chainID, address tokenAddress, uint8 tokenDecimals, uint256 maxSwap, uint256 minSwap, uint256 swapFee, uint256 maxSwapFee, uint256 minSwapFee, bool hasUnderlying, bool isUnderlying)`](#BridgeConfigV2-setTokenConfig-string-uint256-address-uint8-uint256-uint256-uint256-uint256-uint256-bool-bool-)
- [`calculateSwapFee(address tokenAddress, uint256 chainID, uint256 amount)`](#BridgeConfigV2-calculateSwapFee-address-uint256-uint256-)


# <a id="BridgeConfigV2-getAllTokenIDs--"></a> Function `getAllTokenIDs() → string[] result`
No description
# <a id="BridgeConfigV2-getTokenID-address-uint256-"></a> Function `getTokenID(address tokenAddress, uint256 chainID) → string`
No description
## Parameters:
- `tokenAddress`: address of token to get ID for

- `chainID`: chainID of which to get token ID for
# <a id="BridgeConfigV2-getToken-string-uint256-"></a> Function `getToken(string tokenID, uint256 chainID) → struct BridgeConfigV2.Token token`
No description
## Parameters:
- `tokenID`: String input of the token ID for the token

- `chainID`: Chain ID of which token address + config to get
# <a id="BridgeConfigV2-getToken-address-uint256-"></a> Function `getToken(address tokenAddress, uint256 chainID) → struct BridgeConfigV2.Token token`
No description
## Parameters:
- `tokenAddress`: Matches the token ID by using a combo of address + chain ID

- `chainID`: Chain ID of which token to get config for
# <a id="BridgeConfigV2-hasUnderlyingToken-string-"></a> Function `hasUnderlyingToken(string tokenID) → bool`
No description
## Parameters:
- `tokenID`: String to check if it is a withdraw/underlying token
# <a id="BridgeConfigV2-getUnderlyingToken-string-"></a> Function `getUnderlyingToken(string tokenID) → struct BridgeConfigV2.Token token`
No description
## Parameters:
- `tokenID`: string token ID
# <a id="BridgeConfigV2-isTokenIDExist-string-"></a> Function `isTokenIDExist(string tokenID) → bool`
No description
# <a id="BridgeConfigV2-setTokenConfig-string-uint256-address-uint8-uint256-uint256-uint256-uint256-uint256-bool-bool-"></a> Function `setTokenConfig(string tokenID, uint256 chainID, address tokenAddress, uint8 tokenDecimals, uint256 maxSwap, uint256 minSwap, uint256 swapFee, uint256 maxSwapFee, uint256 minSwapFee, bool hasUnderlying, bool isUnderlying) → bool`
No description
## Parameters:
- `tokenID`: string ID to set the token config object form

- `chainID`: chain ID to use for the token config object

- `tokenAddress`: token address of the token on the given chain

- `tokenDecimals`: decimals of token 

- `maxSwap`: maximum amount of token allowed to be transferred at once - in native token decimals

- `minSwap`: minimum amount of token needed to be transferred at once - in native token decimals

- `swapFee`: percent based swap fee -- 10e6 == 10bps

- `maxSwapFee`: max swap fee to be charged - in native token decimals

- `minSwapFee`: min swap fee to be charged - in native token decimals - especially useful for mainnet ETH

- `hasUnderlying`: bool which represents whether this is a global mint token or one to withdraw()

- `isUnderlying`: bool which represents if this token is the one to withdraw on the given chain
# <a id="BridgeConfigV2-calculateSwapFee-address-uint256-uint256-"></a> Function `calculateSwapFee(address tokenAddress, uint256 chainID, uint256 amount) → uint256`
This means the fee should be calculated based on the chain that the nodes emit a tx on

## Parameters:
- `tokenAddress`: address of the destination token to query token config for

- `chainID`: destination chain ID to query the token config for

- `amount`: in native token decimals

## Return Values:
- Fee calculated in token decimals

