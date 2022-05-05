# IStatScienceUpgradeable









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






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

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





#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### hasRole

```solidity
function hasRole(bytes32 role, address account) external view returns (bool)
```





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





#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### revokeRole

```solidity
function revokeRole(bytes32 role, address account) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| interfaceId | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |




