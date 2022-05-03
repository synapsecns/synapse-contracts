# BridgeConfigV3



> BridgeConfig contract

This token is used for configuring different tokens on the bridge and mapping them across chains.*



## Methods

### BRIDGEMANAGER_ROLE

```solidity
function BRIDGEMANAGER_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### DEFAULT_ADMIN_ROLE

```solidity
function DEFAULT_ADMIN_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### bridgeConfigVersion

```solidity
function bridgeConfigVersion() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### calculateSwapFee

```solidity
function calculateSwapFee(string tokenAddress, uint256 chainID, uint256 amount) external view returns (uint256)
```

Calculates bridge swap fee based on the destination chain&#39;s token transfer.

*This means the fee should be calculated based on the chain that the nodes emit a tx on*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | string | address of the destination token to query token config for |
| chainID | uint256 | destination chain ID to query the token config for |
| amount | uint256 | in native token decimals |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Fee calculated in token decimals |

### calculateSwapFee

```solidity
function calculateSwapFee(address tokenAddress, uint256 chainID, uint256 amount) external view returns (uint256)
```

Calculates bridge swap fee based on the destination chain&#39;s token transfer.

*This means the fee should be calculated based on the chain that the nodes emit a tx on*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | address | address of the destination token to query token config for |
| chainID | uint256 | destination chain ID to query the token config for |
| amount | uint256 | in native token decimals |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Fee calculated in token decimals |

### getAllTokenIDs

```solidity
function getAllTokenIDs() external view returns (string[] result)
```

Returns a list of all existing token IDs converted to strings




#### Returns

| Name | Type | Description |
|---|---|---|
| result | string[] | undefined |

### getMaxGasPrice

```solidity
function getMaxGasPrice(uint256 chainID) external view returns (uint256)
```

gets the max gas price for a chain



#### Parameters

| Name | Type | Description |
|---|---|---|
| chainID | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getPoolConfig

```solidity
function getPoolConfig(address tokenAddress, uint256 chainID) external view returns (struct BridgeConfigV3.Pool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | address | undefined |
| chainID | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | BridgeConfigV3.Pool | undefined |

### getRoleAdmin

```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32)
```



*Returns the admin role that controls `role`. See {grantRole} and {revokeRole}. To change a role&#39;s admin, use {_setRoleAdmin}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### getRoleMember

```solidity
function getRoleMember(bytes32 role, uint256 index) external view returns (address)
```



*Returns one of the accounts that have `role`. `index` must be a value between 0 and {getRoleMemberCount}, non-inclusive. Role bearers are not sorted in any particular way, and their ordering may change at any point. WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure you perform all queries on the same block. See the following https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post] for more information.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| index | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getRoleMemberCount

```solidity
function getRoleMemberCount(bytes32 role) external view returns (uint256)
```



*Returns the number of accounts that have `role`. Can be used together with {getRoleMember} to enumerate all bearers of a role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getToken

```solidity
function getToken(string tokenID, uint256 chainID) external view returns (struct BridgeConfigV3.Token token)
```

Returns the full token config struct



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenID | string | String input of the token ID for the token |
| chainID | uint256 | Chain ID of which token address + config to get |

#### Returns

| Name | Type | Description |
|---|---|---|
| token | BridgeConfigV3.Token | undefined |

### getTokenByAddress

```solidity
function getTokenByAddress(string tokenAddress, uint256 chainID) external view returns (struct BridgeConfigV3.Token token)
```

Returns token config struct, given an address and chainID



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | string | Matches the token ID by using a combo of address + chain ID |
| chainID | uint256 | Chain ID of which token to get config for |

#### Returns

| Name | Type | Description |
|---|---|---|
| token | BridgeConfigV3.Token | undefined |

### getTokenByEVMAddress

```solidity
function getTokenByEVMAddress(address tokenAddress, uint256 chainID) external view returns (struct BridgeConfigV3.Token token)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | address | undefined |
| chainID | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| token | BridgeConfigV3.Token | undefined |

### getTokenByID

```solidity
function getTokenByID(string tokenID, uint256 chainID) external view returns (struct BridgeConfigV3.Token token)
```

Returns the full token config struct



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenID | string | String input of the token ID for the token |
| chainID | uint256 | Chain ID of which token address + config to get |

#### Returns

| Name | Type | Description |
|---|---|---|
| token | BridgeConfigV3.Token | undefined |

### getTokenID

```solidity
function getTokenID(address tokenAddress, uint256 chainID) external view returns (string)
```

Returns the token ID (string) of the cross-chain token inputted



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | address | address of token to get ID for |
| chainID | uint256 | chainID of which to get token ID for |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### getTokenID

```solidity
function getTokenID(string tokenAddress, uint256 chainID) external view returns (string)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | string | undefined |
| chainID | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### getUnderlyingToken

```solidity
function getUnderlyingToken(string tokenID) external view returns (struct BridgeConfigV3.Token token)
```

Returns which token is the underlying token to withdraw



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenID | string | string token ID |

#### Returns

| Name | Type | Description |
|---|---|---|
| token | BridgeConfigV3.Token | undefined |

### grantRole

```solidity
function grantRole(bytes32 role, address account) external nonpayable
```



*Grants `role` to `account`. If `account` had not been already granted `role`, emits a {RoleGranted} event. Requirements: - the caller must have ``role``&#39;s admin role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### hasRole

```solidity
function hasRole(bytes32 role, address account) external view returns (bool)
```



*Returns `true` if `account` has been granted `role`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### hasUnderlyingToken

```solidity
function hasUnderlyingToken(string tokenID) external view returns (bool)
```

Returns true if the token has an underlying token -- meaning the token is deposited into the bridge



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenID | string | String to check if it is a withdraw/underlying token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### isTokenIDExist

```solidity
function isTokenIDExist(string tokenID) external view returns (bool)
```

Public function returning if token ID exists given a string



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenID | string | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### renounceRole

```solidity
function renounceRole(bytes32 role, address account) external nonpayable
```



*Revokes `role` from the calling account. Roles are often managed via {grantRole} and {revokeRole}: this function&#39;s purpose is to provide a mechanism for accounts to lose their privileges if they are compromised (such as when a trusted device is misplaced). If the calling account had been granted `role`, emits a {RoleRevoked} event. Requirements: - the caller must be `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### revokeRole

```solidity
function revokeRole(bytes32 role, address account) external nonpayable
```



*Revokes `role` from `account`. If `account` had been granted `role`, emits a {RoleRevoked} event. Requirements: - the caller must have ``role``&#39;s admin role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### setMaxGasPrice

```solidity
function setMaxGasPrice(uint256 chainID, uint256 maxPrice) external nonpayable
```

sets the max gas price for a chain



#### Parameters

| Name | Type | Description |
|---|---|---|
| chainID | uint256 | undefined |
| maxPrice | uint256 | undefined |

### setPoolConfig

```solidity
function setPoolConfig(address tokenAddress, uint256 chainID, address poolAddress, bool metaswap) external nonpayable returns (struct BridgeConfigV3.Pool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | address | undefined |
| chainID | uint256 | undefined |
| poolAddress | address | undefined |
| metaswap | bool | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | BridgeConfigV3.Pool | undefined |

### setTokenConfig

```solidity
function setTokenConfig(string tokenID, uint256 chainID, address tokenAddress, uint8 tokenDecimals, uint256 maxSwap, uint256 minSwap, uint256 swapFee, uint256 maxSwapFee, uint256 minSwapFee, bool hasUnderlying, bool isUnderlying) external nonpayable returns (bool)
```

Main write function of this contract - Handles creating the struct and passing it to the internal logic function



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenID | string | string ID to set the token config object form |
| chainID | uint256 | chain ID to use for the token config object |
| tokenAddress | address | token address of the token on the given chain |
| tokenDecimals | uint8 | decimals of token |
| maxSwap | uint256 | maximum amount of token allowed to be transferred at once - in native token decimals |
| minSwap | uint256 | minimum amount of token needed to be transferred at once - in native token decimals |
| swapFee | uint256 | percent based swap fee -- 10e6 == 10bps |
| maxSwapFee | uint256 | max swap fee to be charged - in native token decimals |
| minSwapFee | uint256 | min swap fee to be charged - in native token decimals - especially useful for mainnet ETH |
| hasUnderlying | bool | bool which represents whether this is a global mint token or one to withdraw() |
| isUnderlying | bool | bool which represents if this token is the one to withdraw on the given chain |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### setTokenConfig

```solidity
function setTokenConfig(string tokenID, uint256 chainID, string tokenAddress, uint8 tokenDecimals, uint256 maxSwap, uint256 minSwap, uint256 swapFee, uint256 maxSwapFee, uint256 minSwapFee, bool hasUnderlying, bool isUnderlying) external nonpayable returns (bool)
```

Main write function of this contract - Handles creating the struct and passing it to the internal logic function



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenID | string | string ID to set the token config object form |
| chainID | uint256 | chain ID to use for the token config object |
| tokenAddress | string | token address of the token on the given chain |
| tokenDecimals | uint8 | decimals of token |
| maxSwap | uint256 | maximum amount of token allowed to be transferred at once - in native token decimals |
| minSwap | uint256 | minimum amount of token needed to be transferred at once - in native token decimals |
| swapFee | uint256 | percent based swap fee -- 10e6 == 10bps |
| maxSwapFee | uint256 | max swap fee to be charged - in native token decimals |
| minSwapFee | uint256 | min swap fee to be charged - in native token decimals - especially useful for mainnet ETH |
| hasUnderlying | bool | bool which represents whether this is a global mint token or one to withdraw() |
| isUnderlying | bool | bool which represents if this token is the one to withdraw on the given chain |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |



## Events

### RoleAdminChanged

```solidity
event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| role `indexed` | bytes32 | undefined |
| previousAdminRole `indexed` | bytes32 | undefined |
| newAdminRole `indexed` | bytes32 | undefined |

### RoleGranted

```solidity
event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| role `indexed` | bytes32 | undefined |
| account `indexed` | address | undefined |
| sender `indexed` | address | undefined |

### RoleRevoked

```solidity
event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| role `indexed` | bytes32 | undefined |
| account `indexed` | address | undefined |
| sender `indexed` | address | undefined |



