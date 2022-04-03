# Bridge Out Functions

## Naming

All functions allowing to bridge funds have the same naming convention: `[deposit|redeem](Max)[EVM|nonEVM]`.

1. `[deposit|redeem]` specifies whether to deposit token into `Vault`, or to burn it on this chain.
2. (optional) If `(Max)`is present in the function name, `amount` parameter will be missing, meaning Bridge will pull as many tokens from caller,
   the token balance, or the token allowance, whichever is **smaller**.
3. `[EVM|nonEVM]` specifies whether the destination chain is EVM-compatible or not. If chain is EVM-compatible, there's an additional parameter passed: `swapParams`,
   containing information about the swap that needs to be made on the destination chain (can be left empty, if no swap in needed).

## Modifiers

There are no modifiers, meaning anyone can call bridge out functions. However, interacting via `BridgeRouter` is highly recommended, as it is doing the needed checks,
and is also handling any bridged tokens requiring a Wrapper Contract to bridge them.

## Parameters

### SwapParams

```solidity
struct SwapParams {
  uint256 minAmountOut;
  address[] path;
  address[] adapters;
  uint256 deadline;
}

```

1. `minAmountOut` minimum amount of tokens user is willing to receive after swap is completed, in final token's decimals precision. If swap results in less than `minAmountOut` tokens, it will fail. On initial chain this will lead to failed tx, and tokens spent/bridged. On destination chain, however, failed swap will lead to user receiving bridged token, instead of the final token they specified.
2. `path` is a list of tokens, describing the series of swaps. `path = [A, B, C]` means that two swaps will be made: `A -> B` and `B -> C`.
3. `adapters` is a list of Synapse Adapters, that will do the swapping. `adapters = [AB, BC]` means that two adapters will be used: `AB` for `A -> B` swap, and `BC` for `B -> C` swap.
4. `deadline` is unix timestamp representing the deadline for swap to be completed. Swap will fail, if too much time passed since the transaction was submitted. See (1) for initial/destination chain failed swap description.

When there's no swap required, `SwapParams` should be empty, i.e.

```solidity
(swapParams.path.length == 0) && (swapParams.adapters.path == 0)
```

`minAmountOut` and `deadline` are not checked for empty `swapParam`, but using following values is recommended for consistency:

```solidity
swapParams.minAmountOut = 0;
swapParams.deadline = type(uint256).max;
```

### Functions

```solidity
function someBridgeOutEVMFunction(
  address to,
  uint256 chainId,
  address token,
  uint256 amount,
  SwapParams calldata bridgedSwapParams
) external;

function someBridgeOutNonEVMFunction(
  bytes32 to,
  uint256 chainId,
  address token,
  uint256 amount
) external;

```

1. `to` is address that will receive the tokens on destination chain. Unless user specified a different address, this should be user's address. UI should have a warning, that is another address is specified for receiving tokens on destination chain, that it should always be the non-custodial wallet, otherwise the funds might be lost (especially when bridging into destination chain's GAS).
2. `chainId` specifies the destination chain's ID.
3. `token` is the token that will be used for bridging. In most cases this is also the token user wants to bridge, but some tokens are not directly compatible with the bridge, and require a `Bridge Wrapper` contract for actual bridging. This concept is abstracted away from user/UI in `BridgeRouter`, but not in `Bridge`. `token` is **always** the token that will be used for actual bridging (i.e. might differ from token that will be pulled from user).
4. `amount` is amount of tokens to bridge, in `token` decimals precision.
5. `bridgedSwapParams` specifies specifies the parameters for swapping bridged token, if needed. Otherwise, it's empty (see `SwapParams` section above).

# Bridge In Functions

## Naming

All bridge in functions are covered by `bridgeIn()`, whether it's mint|withdraw, with following swap or not.

## Modifiers

1. `onlyRole(NODEGROUP_ROLE)` makes sure that only accounts from Node Group are allowed to submit Bridge In transactions.
2. `nonReentrant` prevents reentrancy attacks
3. `whenNotPaused` leaves the ability to pause the `Bridge` if needed.
4. `bridgeInTx(amount, fee, to)` checks whether `amount > fee`, proceeds to fulfill bridging in, then does a gas drop.

## Parameters

```solidity
function bridgeIn(
  address to,
  IERC20 token,
  uint256 amount,
  uint256 fee,
  bool isMint,
  SwapParams calldata bridgedSwapParams,
  bytes32 kappa
) external;

```

1. `to` is the address that will receive the final token (either bridged token, or tokens from swap).
2. `token` is bridged token.
3. `amount` is total amount bridged, including bridge fee, in `token` decimals precision.
4. `fee` is bridge fee, in `token` decimals.
5. `isMint` refers to whether tokens needs to be minted or withdrawn by `Vault`.
6. `bridgedSwapParams` specifies the parameters for swapping bridged token, if needed. Otherwise, it's empty (see `SwapParams` section above).
7. `kappa` refers to a unique bridge transaction parameter. Only one transaction with a given kappa will be accepted by the Vault.
