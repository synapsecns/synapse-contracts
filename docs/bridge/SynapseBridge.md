# SynapseBridge









## Methods

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

### NODEGROUP_ROLE

```solidity
function NODEGROUP_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### RATE_LIMITER_ROLE

```solidity
function RATE_LIMITER_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### WETH_ADDRESS

```solidity
function WETH_ADDRESS() external view returns (address payable)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address payable | undefined |

### addKappas

```solidity
function addKappas(bytes32[] kappas) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| kappas | bytes32[] | undefined |

### bridgeVersion

```solidity
function bridgeVersion() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### chainGasAmount

```solidity
function chainGasAmount() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### deposit

```solidity
function deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount) external nonpayable
```

Relays to nodes to transfers an ERC20 token cross-chain



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to bridge assets to |
| chainId | uint256 | which chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees* |

### depositAndSwap

```solidity
function depositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline) external nonpayable
```

Relays to nodes to both transfer an ERC20 token cross-chain, and then have the nodes execute a swap through a liquidity pool on behalf of the user.



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to bridge assets to |
| chainId | uint256 | which chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees |
| tokenIndexFrom | uint8 | the token the user wants to swap from |
| tokenIndexTo | uint8 | the token the user wants to swap to |
| minDy | uint256 | the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain. |
| deadline | uint256 | latest timestamp to accept this transaction* |

### getFeeBalance

```solidity
function getFeeBalance(address tokenAddress) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | address | undefined |

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






### kappaExists

```solidity
function kappaExists(bytes32 kappa) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| kappa | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### mint

```solidity
function mint(address payable to, contract IERC20Mintable token, uint256 amount, uint256 fee, bytes32 kappa) external nonpayable
```

Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to). This is called by the nodes after a TokenDeposit event is emitted.

*This means the SynapseBridge.sol contract must have minter access to the token attempting to be minted*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address payable | address on other chain to redeem underlying assets to |
| token | contract IERC20Mintable | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain post-fees |
| fee | uint256 | Amount in native token decimals to save to the contract as fees |
| kappa | bytes32 | kappa* |

### mintAndSwap

```solidity
function mintAndSwap(address payable to, contract IERC20Mintable token, uint256 amount, uint256 fee, contract ISwap pool, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline, bytes32 kappa) external nonpayable
```

Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to), and then attempt to swap the SynERC20 into the desired destination asset. This is called by the nodes after a TokenDepositAndSwap event is emitted.

*This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address payable | address on other chain to redeem underlying assets to |
| token | contract IERC20Mintable | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain post-fees |
| fee | uint256 | Amount in native token decimals to save to the contract as fees |
| pool | contract ISwap | Destination chain&#39;s pool to use to swap SynERC20 -&gt; Asset. The nodes determine this by using PoolConfig.sol. |
| tokenIndexFrom | uint8 | Index of the SynERC20 asset in the pool |
| tokenIndexTo | uint8 | Index of the desired final asset |
| minDy | uint256 | Minumum amount (in final asset decimals) that must be swapped for, otherwise the user will receive the SynERC20. |
| deadline | uint256 | Epoch time of the deadline that the swap is allowed to be executed. |
| kappa | bytes32 | kappa* |

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

### rateLimiter

```solidity
function rateLimiter() external view returns (contract IRateLimiter)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IRateLimiter | undefined |

### redeem

```solidity
function redeem(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount) external nonpayable
```

Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to redeem underlying assets to |
| chainId | uint256 | which underlying chain to bridge assets onto |
| token | contract ERC20Burnable | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees* |

### redeemAndRemove

```solidity
function redeemAndRemove(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline) external nonpayable
```

Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g &quot;swap&quot; out of the LP token)



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to redeem underlying assets to |
| chainId | uint256 | which underlying chain to bridge assets onto |
| token | contract ERC20Burnable | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees |
| swapTokenIndex | uint8 | Specifies which of the underlying LP assets the nodes should attempt to redeem for |
| swapMinAmount | uint256 | Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap |
| swapDeadline | uint256 | Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token* |

### redeemAndSwap

```solidity
function redeemAndSwap(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline) external nonpayable
```

Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g &quot;swap&quot; out of the LP token)



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to redeem underlying assets to |
| chainId | uint256 | which underlying chain to bridge assets onto |
| token | contract ERC20Burnable | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees |
| tokenIndexFrom | uint8 | the token the user wants to swap from |
| tokenIndexTo | uint8 | the token the user wants to swap to |
| minDy | uint256 | the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain. |
| deadline | uint256 | latest timestamp to accept this transaction* |

### redeemV2

```solidity
function redeemV2(bytes32 to, uint256 chainId, contract ERC20Burnable token, uint256 amount) external nonpayable
```

Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | bytes32 | address on other chain to redeem underlying assets to |
| chainId | uint256 | which underlying chain to bridge assets onto |
| token | contract ERC20Burnable | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees* |

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

### retryMint

```solidity
function retryMint(address payable to, contract IERC20Mintable token, uint256 amount, uint256 fee, bytes32 kappa) external nonpayable
```

Rate Limiter call this function to retry a mint of a SynERC20 (or any asset that the bridge is given minter access to). This is called by the nodes after a TokenDeposit event is emitted.

*This means the SynapseBridge.sol contract must have minter access to the token attempting to be minted*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address payable | address on other chain to redeem underlying assets to |
| token | contract IERC20Mintable | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain post-fees |
| fee | uint256 | Amount in native token decimals to save to the contract as fees |
| kappa | bytes32 | kappa* |

### retryMintAndSwap

```solidity
function retryMintAndSwap(address payable to, contract IERC20Mintable token, uint256 amount, uint256 fee, contract ISwap pool, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline, bytes32 kappa) external nonpayable
```

RateLimiter call this function to retry a mint of a SynERC20 (or any asset that the bridge is given minter access to), and then attempt to swap the SynERC20 into the desired destination asset. This is called by the nodes after a TokenDepositAndSwap event is emitted.

*This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address payable | address on other chain to redeem underlying assets to |
| token | contract IERC20Mintable | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain post-fees |
| fee | uint256 | Amount in native token decimals to save to the contract as fees |
| pool | contract ISwap | Destination chain&#39;s pool to use to swap SynERC20 -&gt; Asset. The nodes determine this by using PoolConfig.sol. |
| tokenIndexFrom | uint8 | Index of the SynERC20 asset in the pool |
| tokenIndexTo | uint8 | Index of the desired final asset |
| minDy | uint256 | Minumum amount (in final asset decimals) that must be swapped for, otherwise the user will receive the SynERC20. |
| deadline | uint256 | Epoch time of the deadline that the swap is allowed to be executed. |
| kappa | bytes32 | kappa* |

### retryWithdraw

```solidity
function retryWithdraw(address to, contract IERC20 token, uint256 amount, uint256 fee, bytes32 kappa) external nonpayable
```

Function to be called by the rate limiter to retry a withdraw bypassing the rate limiter



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on chain to send underlying assets to |
| token | contract IERC20 | ERC20 compatible token to withdraw from the bridge |
| amount | uint256 | Amount in native token decimals to withdraw |
| fee | uint256 | Amount in native token decimals to save to the contract as fees |
| kappa | bytes32 | kappa* |

### retryWithdrawAndRemove

```solidity
function retryWithdrawAndRemove(address to, contract IERC20 token, uint256 amount, uint256 fee, contract ISwap pool, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline, bytes32 kappa) external nonpayable
```

Function to be called by the rate limiter to retry a withdraw of the underlying assets from the contract



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on chain to send underlying assets to |
| token | contract IERC20 | ERC20 compatible token to withdraw from the bridge |
| amount | uint256 | Amount in native token decimals to withdraw |
| fee | uint256 | Amount in native token decimals to save to the contract as fees |
| pool | contract ISwap | Destination chain&#39;s pool to use to swap SynERC20 -&gt; Asset. The nodes determine this by using PoolConfig.sol. |
| swapTokenIndex | uint8 | Specifies which of the underlying LP assets the nodes should attempt to redeem for |
| swapMinAmount | uint256 | Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap |
| swapDeadline | uint256 | Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token |
| kappa | bytes32 | kappa* |

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

### setChainGasAmount

```solidity
function setChainGasAmount(uint256 amount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | undefined |

### setRateLimiter

```solidity
function setRateLimiter(contract IRateLimiter _rateLimiter) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _rateLimiter | contract IRateLimiter | undefined |

### setWethAddress

```solidity
function setWethAddress(address payable _wethAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _wethAddress | address payable | undefined |

### startBlockNumber

```solidity
function startBlockNumber() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### unpause

```solidity
function unpause() external nonpayable
```






### withdraw

```solidity
function withdraw(address to, contract IERC20 token, uint256 amount, uint256 fee, bytes32 kappa) external nonpayable
```

Function to be called by the node group to withdraw the underlying assets from the contract



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on chain to send underlying assets to |
| token | contract IERC20 | ERC20 compatible token to withdraw from the bridge |
| amount | uint256 | Amount in native token decimals to withdraw |
| fee | uint256 | Amount in native token decimals to save to the contract as fees |
| kappa | bytes32 | kappa* |

### withdrawAndRemove

```solidity
function withdrawAndRemove(address to, contract IERC20 token, uint256 amount, uint256 fee, contract ISwap pool, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline, bytes32 kappa) external nonpayable
```

Function to be called by the node group to withdraw the underlying assets from the contract



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on chain to send underlying assets to |
| token | contract IERC20 | ERC20 compatible token to withdraw from the bridge |
| amount | uint256 | Amount in native token decimals to withdraw |
| fee | uint256 | Amount in native token decimals to save to the contract as fees |
| pool | contract ISwap | Destination chain&#39;s pool to use to swap SynERC20 -&gt; Asset. The nodes determine this by using PoolConfig.sol. |
| swapTokenIndex | uint8 | Specifies which of the underlying LP assets the nodes should attempt to redeem for |
| swapMinAmount | uint256 | Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap |
| swapDeadline | uint256 | Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token |
| kappa | bytes32 | kappa* |

### withdrawFees

```solidity
function withdrawFees(contract IERC20 token, address to) external nonpayable
```

withdraw specified ERC20 token fees to a given address



#### Parameters

| Name | Type | Description |
|---|---|---|
| token | contract IERC20 | ERC20 token in which fees acccumulated to transfer |
| to | address | Address to send the fees to |



## Events

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

### TokenDeposit

```solidity
event TokenDeposit(address indexed to, uint256 chainId, contract IERC20 token, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| chainId  | uint256 | undefined |
| token  | contract IERC20 | undefined |
| amount  | uint256 | undefined |

### TokenDepositAndSwap

```solidity
event TokenDepositAndSwap(address indexed to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| chainId  | uint256 | undefined |
| token  | contract IERC20 | undefined |
| amount  | uint256 | undefined |
| tokenIndexFrom  | uint8 | undefined |
| tokenIndexTo  | uint8 | undefined |
| minDy  | uint256 | undefined |
| deadline  | uint256 | undefined |

### TokenMint

```solidity
event TokenMint(address indexed to, contract IERC20Mintable token, uint256 amount, uint256 fee, bytes32 indexed kappa)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| token  | contract IERC20Mintable | undefined |
| amount  | uint256 | undefined |
| fee  | uint256 | undefined |
| kappa `indexed` | bytes32 | undefined |

### TokenMintAndSwap

```solidity
event TokenMintAndSwap(address indexed to, contract IERC20Mintable token, uint256 amount, uint256 fee, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline, bool swapSuccess, bytes32 indexed kappa)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| token  | contract IERC20Mintable | undefined |
| amount  | uint256 | undefined |
| fee  | uint256 | undefined |
| tokenIndexFrom  | uint8 | undefined |
| tokenIndexTo  | uint8 | undefined |
| minDy  | uint256 | undefined |
| deadline  | uint256 | undefined |
| swapSuccess  | bool | undefined |
| kappa `indexed` | bytes32 | undefined |

### TokenRedeem

```solidity
event TokenRedeem(address indexed to, uint256 chainId, contract IERC20 token, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| chainId  | uint256 | undefined |
| token  | contract IERC20 | undefined |
| amount  | uint256 | undefined |

### TokenRedeemAndRemove

```solidity
event TokenRedeemAndRemove(address indexed to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| chainId  | uint256 | undefined |
| token  | contract IERC20 | undefined |
| amount  | uint256 | undefined |
| swapTokenIndex  | uint8 | undefined |
| swapMinAmount  | uint256 | undefined |
| swapDeadline  | uint256 | undefined |

### TokenRedeemAndSwap

```solidity
event TokenRedeemAndSwap(address indexed to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| chainId  | uint256 | undefined |
| token  | contract IERC20 | undefined |
| amount  | uint256 | undefined |
| tokenIndexFrom  | uint8 | undefined |
| tokenIndexTo  | uint8 | undefined |
| minDy  | uint256 | undefined |
| deadline  | uint256 | undefined |

### TokenRedeemV2

```solidity
event TokenRedeemV2(bytes32 indexed to, uint256 chainId, contract IERC20 token, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | bytes32 | undefined |
| chainId  | uint256 | undefined |
| token  | contract IERC20 | undefined |
| amount  | uint256 | undefined |

### TokenWithdraw

```solidity
event TokenWithdraw(address indexed to, contract IERC20 token, uint256 amount, uint256 fee, bytes32 indexed kappa)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| token  | contract IERC20 | undefined |
| amount  | uint256 | undefined |
| fee  | uint256 | undefined |
| kappa `indexed` | bytes32 | undefined |

### TokenWithdrawAndRemove

```solidity
event TokenWithdrawAndRemove(address indexed to, contract IERC20 token, uint256 amount, uint256 fee, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline, bool swapSuccess, bytes32 indexed kappa)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| token  | contract IERC20 | undefined |
| amount  | uint256 | undefined |
| fee  | uint256 | undefined |
| swapTokenIndex  | uint8 | undefined |
| swapMinAmount  | uint256 | undefined |
| swapDeadline  | uint256 | undefined |
| swapSuccess  | bool | undefined |
| kappa `indexed` | bytes32 | undefined |

### Unpaused

```solidity
event Unpaused(address account)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |



