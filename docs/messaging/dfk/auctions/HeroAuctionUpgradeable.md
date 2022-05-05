# HeroAuctionUpgradeable



> Auction modified for sale of heroes

We omit a fallback function to prevent accidental sends to this contract.



## Methods

### BIDDER_ROLE

```solidity
function BIDDER_ROLE() external view returns (bytes32)
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

### ERC721

```solidity
function ERC721() external view returns (contract IERC721Upgradeable)
```

CONTRACTS ///




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC721Upgradeable | undefined |

### MODERATOR_ROLE

```solidity
function MODERATOR_ROLE() external view returns (bytes32)
```

ROLES ///




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### assistingAuction

```solidity
function assistingAuction() external view returns (contract IAssistingAuctionUpgradeable)
```

CONTRACTS ///




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IAssistingAuctionUpgradeable | undefined |

### auctionIdOffset

```solidity
function auctionIdOffset() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### auctions

```solidity
function auctions(uint256) external view returns (address seller, uint256 tokenId, uint128 startingPrice, uint128 endingPrice, uint64 duration, uint64 startedAt, address winner, bool open)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| seller | address | undefined |
| tokenId | uint256 | undefined |
| startingPrice | uint128 | undefined |
| endingPrice | uint128 | undefined |
| duration | uint64 | undefined |
| startedAt | uint64 | undefined |
| winner | address | undefined |
| open | bool | undefined |

### bid

```solidity
function bid(uint256 _tokenId, uint256 _bidAmount) external nonpayable
```



*Bids on an open auction, completing the auction and transferring  ownership of the NFT if enough CRYSTALs are supplied.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | - ID of token to bid on. |
| _bidAmount | uint256 | The bid amount. |

### bidFor

```solidity
function bidFor(address _bidder, uint256 _tokenId, uint256 _bidAmount) external nonpayable
```



*Bids on an open auction, completing the auction if enough JEWELs are supplied.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _bidder | address | undefined |
| _tokenId | uint256 | - ID of token to bid on. |
| _bidAmount | uint256 | The bid amount. |

### cancelAuction

```solidity
function cancelAuction(uint256 _tokenId) external nonpayable
```

This is a state-modifying function that can  be called while the contract is paused.

*Cancels an auction that hasn&#39;t been won yet.  Returns the NFT to original owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | - ID of token on auction |

### cancelAuctionWhenPaused

```solidity
function cancelAuctionWhenPaused(uint256 _tokenId) external nonpayable
```



*Cancels an auction when the contract is paused.  Only the owner may do this, and NFTs are returned to  the seller. This should only be used in emergencies.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | - ID of the NFT on auction to cancel. |

### createAuction

```solidity
function createAuction(uint256 _tokenId, uint128 _startingPrice, uint128 _endingPrice, uint64 _duration, address _winner) external nonpayable
```



*Creates and begins a new auction.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | - ID of token to auction, sender must be owner. |
| _startingPrice | uint128 | - Price of item (in wei) at beginning of auction. |
| _endingPrice | uint128 | - Price of item (in wei) at end of auction. |
| _duration | uint64 | - Length of auction (in seconds). |
| _winner | address | undefined |

### crystalToken

```solidity
function crystalToken() external view returns (contract IERC20Upgradeable)
```

CONTRACTS ///




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20Upgradeable | undefined |

### feeAddresses

```solidity
function feeAddresses(uint256) external view returns (address)
```

STATE ///



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### feePercents

```solidity
function feePercents(uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getAuction

```solidity
function getAuction(uint256 _tokenId) external view returns (struct Auction)
```



*Returns auction info for an NFT on auction.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | - ID of NFT on auction. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | Auction | undefined |

### getAuctions

```solidity
function getAuctions(uint256[] _tokenIds) external view returns (struct Auction[])
```



*single endpoint gets an array of auctions*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenIds | uint256[] | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | Auction[] | undefined |

### getCurrentPrice

```solidity
function getCurrentPrice(uint256 _tokenId) external view returns (uint256)
```



*Returns the current price of an auction.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | - ID of the token price we are checking. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### getUserAuctions

```solidity
function getUserAuctions(address _address) external view returns (uint256[])
```



*returns the accounts auctions*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _address | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | undefined |

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
function initialize(address _heroCoreAddress, address _crystalAddress, uint256 _cut, address _assistingAuctionAddress, uint256 _auctionIdOffset) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _heroCoreAddress | address | undefined |
| _crystalAddress | address | undefined |
| _cut | uint256 | undefined |
| _assistingAuctionAddress | address | undefined |
| _auctionIdOffset | uint256 | undefined |

### isOnAuction

```solidity
function isOnAuction(uint256 _tokenId) external view returns (bool)
```



*Checks if the token is currently on auction.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### onERC721Received

```solidity
function onERC721Received(address, address, uint256, bytes) external pure returns (bytes4)
```

Always returns `IERC721Receiver.onERC721Received.selector`.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | address | undefined |
| _2 | uint256 | undefined |
| _3 | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes4 | undefined |

### ownerCut

```solidity
function ownerCut() external view returns (uint256)
```

STATE ///




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### pause

```solidity
function pause() external nonpayable
```






### paused

```solidity
function paused() external view returns (bool)
```



*Returns true if the contract is paused, and false otherwise.*


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

### setFees

```solidity
function setFees(address[] _feeAddresses, uint256[] _feePercents) external nonpayable
```



*Sets the addresses and percentages that will receive fees.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _feeAddresses | address[] | An array of addresses to send fees to. |
| _feePercents | uint256[] | An array of percentages for the addresses to get. |

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

### totalAuctions

```solidity
function totalAuctions() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### unpause

```solidity
function unpause() external nonpayable
```






### userAuctions

```solidity
function userAuctions(address, uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |



## Events

### AuctionCancelled

```solidity
event AuctionCancelled(uint256 auctionId, uint256 indexed tokenId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| auctionId  | uint256 | undefined |
| tokenId `indexed` | uint256 | undefined |

### AuctionCreated

```solidity
event AuctionCreated(uint256 auctionId, address indexed owner, uint256 indexed tokenId, uint256 startingPrice, uint256 endingPrice, uint256 duration, address winner)
```

EVENTS ///



#### Parameters

| Name | Type | Description |
|---|---|---|
| auctionId  | uint256 | undefined |
| owner `indexed` | address | undefined |
| tokenId `indexed` | uint256 | undefined |
| startingPrice  | uint256 | undefined |
| endingPrice  | uint256 | undefined |
| duration  | uint256 | undefined |
| winner  | address | undefined |

### AuctionSuccessful

```solidity
event AuctionSuccessful(uint256 auctionId, uint256 indexed tokenId, uint256 totalPrice, address winner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| auctionId  | uint256 | undefined |
| tokenId `indexed` | uint256 | undefined |
| totalPrice  | uint256 | undefined |
| winner  | address | undefined |

### Paused

```solidity
event Paused(address account)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |

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

### Unpaused

```solidity
event Unpaused(address account)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |



