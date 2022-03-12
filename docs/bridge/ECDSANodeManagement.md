# ECDSANodeManagement









## Methods

### closeKeep

```solidity
function closeKeep() external nonpayable
```

Closes keep when owner decides that they no longer need it. Releases bonds to the keep members.

*The function can be called only by the owner of the keep and only if the keep has not been already closed.*


### getMembers

```solidity
function getMembers() external view returns (address[])
```

Returns members of the keep.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address[] | List of the keep members&#39; addresses. |

### getOpenedTimestamp

```solidity
function getOpenedTimestamp() external view returns (uint256)
```

Gets the timestamp the keep was opened at.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | Timestamp the keep was opened at. |

### getOwner

```solidity
function getOwner() external view returns (address)
```

Gets the owner of the keep.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | Address of the keep owner. |

### getPublicKey

```solidity
function getPublicKey() external view returns (bytes)
```

Returns keep&#39;s ECDSA public key.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | Keep&#39;s ECDSA public key. |

### honestThreshold

```solidity
function honestThreshold() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### initialize

```solidity
function initialize(address _owner, address[] _members, uint256 _honestThreshold) external nonpayable
```

Initialization function.

*We use clone factory to create new keep. That is why this contract doesn&#39;t have a constructor. We provide keep parameters for each instance function after cloning instances from the master contract. Initialization must happen in the same transaction in which the clone is created.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _owner | address | Address of the keep owner. |
| _members | address[] | Addresses of the keep members. |
| _honestThreshold | uint256 | Minimum number of honest keep members. |

### isActive

```solidity
function isActive() external view returns (bool)
```

Returns true if the keep is active.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | true if the keep is active, false otherwise. |

### isClosed

```solidity
function isClosed() external view returns (bool)
```

Returns true if the keep is closed and members no longer support this keep.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | true if the keep is closed, false otherwise. |

### isTerminated

```solidity
function isTerminated() external view returns (bool)
```

Returns true if the keep has been terminated. Keep is terminated when bonds are seized and members no longer support this keep.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | true if the keep has been terminated, false otherwise. |

### members

```solidity
function members(uint256) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### publicKey

```solidity
function publicKey() external view returns (bytes)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### submitPublicKey

```solidity
function submitPublicKey(bytes _publicKey) external nonpayable
```

Submits a public key to the keep.

*Public key is published successfully if all members submit the same value. In case of conflicts with others members submissions it will emit `ConflictingPublicKeySubmitted` event. When all submitted keys match it will store the key as keep&#39;s public key and emit a `PublicKeyPublished` event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _publicKey | bytes | Signer&#39;s public key. |



## Events

### ConflictingPublicKeySubmitted

```solidity
event ConflictingPublicKeySubmitted(address indexed submittingMember, bytes conflictingPublicKey)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| submittingMember `indexed` | address | undefined |
| conflictingPublicKey  | bytes | undefined |

### KeepClosed

```solidity
event KeepClosed()
```






### KeepTerminated

```solidity
event KeepTerminated()
```






### PublicKeyPublished

```solidity
event PublicKeyPublished(bytes publicKey)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| publicKey  | bytes | undefined |



