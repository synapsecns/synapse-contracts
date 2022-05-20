# RateLimiter









## Methods

### BRIDGE_ADDRESS

```solidity
function BRIDGE_ADDRESS() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### BRIDGE_ROLE

```solidity
function BRIDGE_ROLE() external view returns (bytes32)
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

### GOVERNANCE_ROLE

```solidity
function GOVERNANCE_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### LIMITER_ROLE

```solidity
function LIMITER_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### MIN_RETRY_TIMEOUT

```solidity
function MIN_RETRY_TIMEOUT() external view returns (uint32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | undefined |

### NAME

```solidity
function NAME() external view returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### VERSION

```solidity
function VERSION() external view returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### addToRetryQueue

```solidity
function addToRetryQueue(bytes32 kappa, bytes toRetry) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| kappa | bytes32 | undefined |
| toRetry | bytes | undefined |

### allowances

```solidity
function allowances(address) external view returns (uint96 amount, uint96 spent, uint16 resetTimeMin, uint32 lastResetMin, bool initialized)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| amount | uint96 | undefined |
| spent | uint96 | undefined |
| resetTimeMin | uint16 | undefined |
| lastResetMin | uint32 | undefined |
| initialized | bool | undefined |

### checkAndUpdateAllowance

```solidity
function checkAndUpdateAllowance(address token, uint256 amount) external nonpayable returns (bool)
```

Checks the allowance for a given token. If the new amount exceeds the allowance, it is not updated and false is returned otherwise true is returned and the transaction can proceed



#### Parameters

| Name | Type | Description |
|---|---|---|
| token | address | undefined |
| amount | uint256 | to transfer* |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### deleteByKappa

```solidity
function deleteByKappa(bytes32 kappa) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| kappa | bytes32 | undefined |

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

### getTokenAllowance

```solidity
function getTokenAllowance(address token) external view returns (uint256[4])
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| token | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[4] | undefined |

### getTokens

```solidity
function getTokens() external view returns (address[])
```

Gets a  list of tokens with allowances*




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address[] | undefined |

### getTransactionAt

```solidity
function getTransactionAt(uint256 index) external view returns (bytes32 key, bytes payload, uint32 storedAtMin)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| key | bytes32 | undefined |
| payload | bytes | undefined |
| storedAtMin | uint32 | undefined |

### getTransactionByKappa

```solidity
function getTransactionByKappa(bytes32 kappa) external view returns (bytes payload, uint32 storedAtMin)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| kappa | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| payload | bytes | undefined |
| storedAtMin | uint32 | undefined |

### getUnhandledKappas

```solidity
function getUnhandledKappas() external view returns (bytes32[] kappas)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| kappas | bytes32[] | undefined |

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

### initialize

```solidity
function initialize() external nonpayable
```






### renounceRole

```solidity
function renounceRole(bytes32 role, address account) external nonpayable
```



*Revokes `role` from the calling account. Roles are often managed via {grantRole} and {revokeRole}: this function&#39;s purpose is to provide a mechanism for accounts to lose their privileges if they are compromised (such as when a trusted device is misplaced). If the calling account had been revoked `role`, emits a {RoleRevoked} event. Requirements: - the caller must be `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### resetAllowance

```solidity
function resetAllowance(address token) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| token | address | undefined |

### retryByKappa

```solidity
function retryByKappa(bytes32 kappa) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| kappa | bytes32 | undefined |

### retryCount

```solidity
function retryCount(uint8 count) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| count | uint8 | undefined |

### retryQueueLength

```solidity
function retryQueueLength() external view returns (uint256 length)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| length | uint256 | undefined |

### retryTimeout

```solidity
function retryTimeout() external view returns (uint32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | undefined |

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

### setAllowance

```solidity
function setAllowance(address token, uint96 allowanceAmount, uint16 resetTimeMin, uint32 resetBaseMin) external nonpayable
```

Updates the allowance for a given token



#### Parameters

| Name | Type | Description |
|---|---|---|
| token | address | to update the allowance for |
| allowanceAmount | uint96 | for the token |
| resetTimeMin | uint16 | minimum reset time (amount goes to 0 after this) |
| resetBaseMin | uint32 | amount Amount in native token decimals to transfer cross-chain pre-fees* |

### setBridgeAddress

```solidity
function setBridgeAddress(address bridge) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| bridge | address | undefined |

### setRetryTimeout

```solidity
function setRetryTimeout(uint32 _retryTimeout) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _retryTimeout | uint32 | undefined |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```



*See {IERC165-supportsInterface}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| interfaceId | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### tokens

```solidity
function tokens(uint256) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### unhandledKappasCount

```solidity
function unhandledKappasCount() external view returns (uint256 kappaCount)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| kappaCount | uint256 | undefined |



## Events

### ResetAllowance

```solidity
event ResetAllowance(address indexed token)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| token `indexed` | address | undefined |

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

### SetAllowance

```solidity
event SetAllowance(address indexed token, uint96 allowanceAmount, uint16 resetTime)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| token `indexed` | address | undefined |
| allowanceAmount  | uint96 | undefined |
| resetTime  | uint16 | undefined |



