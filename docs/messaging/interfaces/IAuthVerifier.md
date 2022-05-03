# IAuthVerifier









## Methods

### msgAuth

```solidity
function msgAuth(bytes _authData) external view returns (bool authenticated)
```

Authentication library to allow the validator network to execute cross-chain messages.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _authData | bytes | A bytes32 address encoded via abi.encode(address) |

#### Returns

| Name | Type | Description |
|---|---|---|
| authenticated | bool | returns true if bytes data submitted and decoded to the address is correct |

### setNodeGroup

```solidity
function setNodeGroup(address _nodegroup) external nonpayable
```

Permissioned method to support upgrades to the library



#### Parameters

| Name | Type | Description |
|---|---|---|
| _nodegroup | address | address which has authentication to execute messages |




