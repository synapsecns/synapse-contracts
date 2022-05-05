# IAssistingAuctionUpgradeable









## Methods

### bid

```solidity
function bid(uint256 _tokenId, uint256 _bidAmount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |
| _bidAmount | uint256 | undefined |

### bidFor

```solidity
function bidFor(address _bidder, uint256 _tokenId, uint256 _bidAmount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _bidder | address | undefined |
| _tokenId | uint256 | undefined |
| _bidAmount | uint256 | undefined |

### cancelAuction

```solidity
function cancelAuction(uint256 _tokenId) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |

### cancelAuctionWhenPaused

```solidity
function cancelAuctionWhenPaused(uint256 _tokenId) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |

### createAuction

```solidity
function createAuction(uint256 _tokenId, uint256 _startingPrice, uint256 _endingPrice, uint256 _duration) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |
| _startingPrice | uint256 | undefined |
| _endingPrice | uint256 | undefined |
| _duration | uint256 | undefined |

### getAuction

```solidity
function getAuction(uint256 _tokenId) external view returns (address seller, uint256 startingPrice, uint256 endingPrice, uint256 duration, uint256 startedAt)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| seller | address | undefined |
| startingPrice | uint256 | undefined |
| endingPrice | uint256 | undefined |
| duration | uint256 | undefined |
| startedAt | uint256 | undefined |

### getCurrentPrice

```solidity
function getCurrentPrice(uint256 _tokenId) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### heroCore

```solidity
function heroCore() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### isOnAuction

```solidity
function isOnAuction(uint256 _tokenId) external nonpayable returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### jewelToken

```solidity
function jewelToken() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### owner

```solidity
function owner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### ownerCut

```solidity
function ownerCut() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### paused

```solidity
function paused() external view returns (bool)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```






### setFees

```solidity
function setFees(address[] _feeAddresses, uint256[] _feePercents) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _feeAddresses | address[] | undefined |
| _feePercents | uint256[] | undefined |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |




