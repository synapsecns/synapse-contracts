# StatScienceUpgradeable

*Frisky Fox - Defi Kingdoms*

> StatScience contains the logic to calculate starting stats.





## Methods

### DEFAULT_ADMIN_ROLE

```solidity
function DEFAULT_ADMIN_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### WHITELIST_ROLE

```solidity
function WHITELIST_ROLE() external view returns (bytes32)
```

ROLES ///




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### addRarityBonus

```solidity
function addRarityBonus(HeroStats _heroStats, enum Rarity _rarity, HeroCrystal _crystal, uint256 _crystalId) external nonpayable returns (struct HeroStats, uint8[8])
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _heroStats | HeroStats | undefined |
| _rarity | enum Rarity | undefined |
| _crystal | HeroCrystal | undefined |
| _crystalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | HeroStats | undefined |
| _1 | uint8[8] | undefined |

### augmentStat

```solidity
function augmentStat(HeroStats _stats, uint256 _stat, uint8 _increase) external pure returns (struct HeroStats)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _stats | HeroStats | undefined |
| _stat | uint256 | undefined |
| _increase | uint8 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | HeroStats | undefined |

### generateStatGrowth

```solidity
function generateStatGrowth(uint256 _statGenes, HeroCrystal, enum Rarity, bool _isPrimary) external pure returns (struct HeroStatGrowth)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _statGenes | uint256 | undefined |
| _1 | HeroCrystal | undefined |
| _2 | enum Rarity | undefined |
| _isPrimary | bool | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | HeroStatGrowth | undefined |

### generateStats

```solidity
function generateStats(uint256 _statGenes, HeroCrystal _crystal, enum Rarity _rarity, uint256 _crystalId) external nonpayable returns (struct HeroStats)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _statGenes | uint256 | undefined |
| _crystal | HeroCrystal | undefined |
| _rarity | enum Rarity | undefined |
| _crystalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | HeroStats | undefined |

### getGene

```solidity
function getGene(uint256 _genes, uint8 _position) external pure returns (uint8)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _genes | uint256 | undefined |
| _position | uint8 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### getJobTier

```solidity
function getJobTier(uint8 _class) external pure returns (enum JobTier)
```



*Gets the job tier for genes.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _class | uint8 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | enum JobTier | undefined |

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



