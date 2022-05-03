# IHeroCoreUpgradeable









## Methods

### DEFAULT_ADMIN_ROLE

```solidity
function DEFAULT_ADMIN_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### HERO_MODERATOR_ROLE

```solidity
function HERO_MODERATOR_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### MINTER_ROLE

```solidity
function MINTER_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### MODERATOR_ROLE

```solidity
function MODERATOR_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### PAUSER_ROLE

```solidity
function PAUSER_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### STAMINA_ROLE

```solidity
function STAMINA_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### approve

```solidity
function approve(address to, uint256 tokenId) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| tokenId | uint256 | undefined |

### assistingAuction

```solidity
function assistingAuction() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### balanceOf

```solidity
function balanceOf(address owner) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### baseCooldown

```solidity
function baseCooldown() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### baseSummonFee

```solidity
function baseSummonFee() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### bridgeMint

```solidity
function bridgeMint(Hero _hero, address dstAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _hero | Hero | undefined |
| dstAddress | address | undefined |

### burn

```solidity
function burn(uint256 tokenId) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

### calculateSummoningCost

```solidity
function calculateSummoningCost(uint256 _heroId) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _heroId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### cooldownPerGen

```solidity
function cooldownPerGen() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### cooldownPerSummon

```solidity
function cooldownPerSummon() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### cooldowns

```solidity
function cooldowns(uint256) external view returns (uint32)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint32 | undefined |

### createAssistingAuction

```solidity
function createAssistingAuction(uint256 _heroId, uint256 _startingPrice, uint256 _endingPrice, uint256 _duration) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _heroId | uint256 | undefined |
| _startingPrice | uint256 | undefined |
| _endingPrice | uint256 | undefined |
| _duration | uint256 | undefined |

### createHero

```solidity
function createHero(uint256 _statGenes, uint256 _visualGenes, enum Rarity _rarity, bool _shiny, HeroCrystal _crystal, uint256 _crystalId) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _statGenes | uint256 | undefined |
| _visualGenes | uint256 | undefined |
| _rarity | enum Rarity | undefined |
| _shiny | bool | undefined |
| _crystal | HeroCrystal | undefined |
| _crystalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### createSaleAuction

```solidity
function createSaleAuction(uint256 _heroId, uint256 _startingPrice, uint256 _endingPrice, uint256 _duration) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _heroId | uint256 | undefined |
| _startingPrice | uint256 | undefined |
| _endingPrice | uint256 | undefined |
| _duration | uint256 | undefined |

### crystalToken

```solidity
function crystalToken() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### deductStamina

```solidity
function deductStamina(uint256 _heroId, uint256 _staminaDeduction) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _heroId | uint256 | undefined |
| _staminaDeduction | uint256 | undefined |

### extractNumber

```solidity
function extractNumber(uint256 randomNumber, uint256 digits, uint256 offset) external pure returns (uint256 result)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| randomNumber | uint256 | undefined |
| digits | uint256 | undefined |
| offset | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| result | uint256 | undefined |

### geneScience

```solidity
function geneScience() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getApproved

```solidity
function getApproved(uint256 tokenId) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getCurrentStamina

```solidity
function getCurrentStamina(uint256 _heroId) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _heroId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getHero

```solidity
function getHero(uint256 _id) external view returns (struct Hero)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _id | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | Hero | undefined |

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

### getRoleMember

```solidity
function getRoleMember(bytes32 role, uint256 index) external view returns (address)
```





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





#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### increasePerGen

```solidity
function increasePerGen() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### increasePerSummon

```solidity
function increasePerSummon() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### initialize

```solidity
function initialize(string name, string symbol, string baseTokenURI) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| name | string | undefined |
| symbol | string | undefined |
| baseTokenURI | string | undefined |

### initialize

```solidity
function initialize(address _crystalAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _crystalAddress | address | undefined |

### isApprovedForAll

```solidity
function isApprovedForAll(address owner, address operator) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| operator | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### isReadyToSummon

```solidity
function isReadyToSummon(uint256 _heroId) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _heroId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### mint

```solidity
function mint(address to) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |

### name

```solidity
function name() external view returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### openCrystal

```solidity
function openCrystal(uint256 _crystalId) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _crystalId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### ownerOf

```solidity
function ownerOf(uint256 tokenId) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### pause

```solidity
function pause() external nonpayable
```






### paused

```solidity
function paused() external view returns (bool)
```






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

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 tokenId) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| tokenId | uint256 | undefined |

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 tokenId, bytes _data) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| tokenId | uint256 | undefined |
| _data | bytes | undefined |

### saleAuction

```solidity
function saleAuction() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### setApprovalForAll

```solidity
function setApprovalForAll(address operator, bool approved) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| operator | address | undefined |
| approved | bool | undefined |

### setAssistingAuctionAddress

```solidity
function setAssistingAuctionAddress(address _address) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _address | address | undefined |

### setFees

```solidity
function setFees(address[] _feeAddresses, uint256[] _feePercents) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _feeAddresses | address[] | undefined |
| _feePercents | uint256[] | undefined |

### setSaleAuctionAddress

```solidity
function setSaleAuctionAddress(address _address) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _address | address | undefined |

### setSummonCooldowns

```solidity
function setSummonCooldowns(uint256 _baseCooldown, uint256 _cooldownPerSummon, uint256 _cooldownPerGen) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _baseCooldown | uint256 | undefined |
| _cooldownPerSummon | uint256 | undefined |
| _cooldownPerGen | uint256 | undefined |

### setSummonFees

```solidity
function setSummonFees(uint256 _baseSummonFee, uint256 _increasePerSummon, uint256 _increasePerGen) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _baseSummonFee | uint256 | undefined |
| _increasePerSummon | uint256 | undefined |
| _increasePerGen | uint256 | undefined |

### setTimePerStamina

```solidity
function setTimePerStamina(uint256 _timePerStamina) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _timePerStamina | uint256 | undefined |

### summonCrystal

```solidity
function summonCrystal(uint256 _summonerId, uint256 _assistantId, uint8 _summonerTears, uint8 _assistantTears, address _enhancementStone) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _summonerId | uint256 | undefined |
| _assistantId | uint256 | undefined |
| _summonerTears | uint8 | undefined |
| _assistantTears | uint8 | undefined |
| _enhancementStone | address | undefined |

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

### symbol

```solidity
function symbol() external view returns (string)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### timePerStamina

```solidity
function timePerStamina() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### tokenByIndex

```solidity
function tokenByIndex(uint256 index) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### tokenOfOwnerByIndex

```solidity
function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| index | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### tokenURI

```solidity
function tokenURI(uint256 tokenId) external view returns (string)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 tokenId) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| tokenId | uint256 | undefined |

### unpause

```solidity
function unpause() external nonpayable
```






### updateHero

```solidity
function updateHero(Hero _hero) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _hero | Hero | undefined |

### vrf

```solidity
function vrf(uint256 blockNumber) external view returns (bytes32 result)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| blockNumber | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| result | bytes32 | undefined |




