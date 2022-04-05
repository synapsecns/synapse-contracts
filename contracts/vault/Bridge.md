# Bridge Out Functions

## Naming

All functions allowing to bridge funds have the same naming convention: `bridgeTo[EVM|nonEVM]`.

- `[EVM|nonEVM]` specifies whether the destination chain is EVM-compatible or not. If chain is EVM-compatible, there's an additional parameter passed: `swapParams`,
  containing information about the swap that needs to be made on the destination chain (can be left [empty](#empty-swapparams), if no swap in needed).

## SwapParams

```solidity
struct SwapParams {
  uint256 minAmountOut;
  address[] path;
  address[] adapters;
  uint256 deadline;
}

```

- `minAmountOut`: minimum amount of tokens user is willing to receive after swap is completed, in final token's decimals precision. If swap results in less than `minAmountOut` tokens, it **will fail**.
- `path`: a list of tokens, describing the series of swaps. `path = [A, B, C]` means that two swaps will be made: `A -> B` and `B -> C`.
- `adapters`: a list of Synapse Adapters, that will do the swapping. `adapters = [AB, BC]` means that two adapters will be used: `AB` for `A -> B` swap, and `BC` for `B -> C` swap.
- `deadline`: Unix timestamp representing the deadline for swap to be completed. Swap **will fail**, if too much time passed since the transaction was submitted.

> Failed swap on initial chain this will lead to failed tx, and tokens **not** spent/bridged. On destination chain, however, failed swap will lead to user receiving bridged token, instead of the final token they specified.

### Valid SwapParams

- `swapParams` is considered **_valid_**, if `len(path) == len(adapters) + 1`.

### Empty SwapParams

- When there's no swap required, `SwapParams` should be **_empty_**, i.e.

```solidity
(swapParams.adapters.path == 0) &&
(swapParams.path.length == 1) &&
(swapParams.path[0] == neededToken)
```

> **_Empty_** `SwapParams` should have zero length array for `adapters`, and a single _needed token_ in `path`. For initial chain, that would be the starting token, for destination chain — the final token.

- `minAmountOut` and `deadline` are not checked for **_empty_** `swapParams`, but using following values is recommended for consistency:

```solidity
swapParams.minAmountOut = 0;
swapParams.deadline = type(uint256).max;
```

## Modifiers

```solidity
modifier checkSwapParams(SwapParams calldata swapParams) {
  require(swapParams.path.length == swapParams.adapters.length + 1, "Bridge: len(path)!=len(adapters)+1");

  _;
}

```

- `checkSwapParams` is used in `bridgeToEVM`, to check `destinationSwapParams` parameter for being a [valid](#valid-swapparams) swap description.

```solidity
modifier checkTokenSupported(IERC20 token) {
    require(
        bridgeTokenType[address(token)] != TokenType.NOT_SUPPORTED,
        "Bridge: token is not supported"
    );

    _;
}

```

- `checkTokenSupported` is used for every **Bridge In** and **Bridge Out** function to check if a token is supported by the `Bridge`.

- There are no access modifiers, meaning anyone can call **Bridge Out** functions. However, calling `bridgeTo[EVM|NonEVM]` requires transferring bridge token to `Bridge` first. This means one would need to interact with a smart contract, which would load token into `Bridge` and call needed **Bridge Out** function.

  > An example of such contract is `BridgeRouter`, which not only allows to bridge a token, but also enables doing a swap from any token into bridge token before that.

## Function list

```solidity
function bridgeToEVM(
  address to,
  uint256 chainId,
  IERC20 token,
  SwapParams calldata destinationSwapParams
) external;

function bridgeToNonEVM(
  bytes32 to,
  uint256 chainId,
  IERC20 token,
) external;

```

> As you may noticed, there is no `amount` parameter present. `Bridge` will use its `token` balance for bridging, which means that to use `Bridge` effectively, one must send bridge tokens to `Bridge` and call **Bridge Out** function in the same transaction. This is enabled by interacting with `BridgeRouter`.

- `to`: address that will receive the tokens on destination chain. Unless user specified a different address, this should be user's address.
  > UI should have a warning, that is another address is specified for receiving tokens on destination chain, that it should always be the non-custodial wallet, otherwise the funds might be lost (especially when bridging into destination chain's GAS).
- `chainId`: destination chain's ID.
- `token`: token that will be used for bridging.
- `destinationSwapParams`: [valid](#valid-swapparams) parameters for swapping token into bridge token on **destination chain**, if needed. Otherwise, it's [empty](#empty-swapparams).
  - `minAmountOut`: minimum amount of bridge token to receive after swap on **destination chain**, otherwise user **will receive bridge token**.
    > If bridge token on **destination chain** is `WGAS`, it will be automatically unwrapped and sent as native chain `GAS`.
  - `path`: list of tokens, specifying the swap route on **destination chain**.
    - `path[0]`: token that will be used for bridging on **destination chain**.
    - `path[1]`: token received after the first swap of the route.
    - `...`
    - `path[path.length-1]`: token that user will receive on **destination chain**.
      > If final token is `WGAS`, it will be automatically unwrapped and sent as native chain `GAS`.
  - `adapters`: list of Synapse adapters, that will be used for swaps on **initial chain**.
  - `deadline`: deadline for swap on **destination chain**. If deadline check is failed, user **will receive bridge token**.
    > If bridge token on **destination chain** is `WGAS`, it will be automatically unwrapped and sent as native chain `GAS`.

> `token` and `destinationSwapParams.path[0]` are two counterparts of the bridge token, representing its addresses on initial and destination chain respectively.

> Some tokens are not directly compatible with the bridge, and require a `Bridge Wrapper` contract for actual bridging. This concept is abstracted away from user/UI. `token` and `destinationSwapParams.path[0]` **are always** the tokens, that are actually used/traded on their respective chains.

# Bridge In Functions

## Naming

All bridge in functions are covered by `bridgeIn()`, whether it's mint|withdraw, with following swap or not.

## Modifiers

- `onlyRole(NODEGROUP_ROLE)` makes sure that only accounts from Node Group are allowed to submit _Bridge In transactions_.
- `nonReentrant` prevents reentrancy attacks.
- `whenNotPaused` leaves the ability to pause the `Bridge` if needed.
- `bridgeInTx(amount, fee, to)` checks whether `amount > fee`, proceeds to fulfill bridging in, then does a gas drop.

## Parameters

```solidity
function bridgeIn(
  address to,
  IERC20 token,
  uint256 amount,
  uint256 fee,
  SwapParams calldata swapParams,
  bytes32 kappa
)
  external
  onlyRole(NODEGROUP_ROLE)
  nonReentrant
  whenNotPaused
  bridgeInTx(amount, fee, to);

```

- `to`: address that will receive the final token (either bridged token, or tokens from swap).
- `token`: bridged token.
- `amount`: total amount bridged, including bridge fee, in `token` decimals precision.
- `fee`: bridge fee, in `token` decimals precision.
- `swapParams`: [valid](#valid-swapparams) parameters for swapping token into bridge token on **destination chain**, if needed. Otherwise, it's [empty](#empty-swapparams).
  - `minAmountOut`: minimum amount of bridge token to receive after swap on **destination chain**, otherwise user **will receive bridge token**.
    > If bridge token on **destination chain** is `WGAS`, it will be automatically unwrapped and sent as native chain `GAS`.
  - `path`: list of tokens, specifying the swap route on **destination chain**.
    - `path[0]`: token that will be used for bridging on **destination chain**.
    - `path[1]`: token received after the first swap of the route.
    - `...`
    - `path[path.length-1]`: token that user will receive on **destination chain**.
      > If final token is `WGAS`, it will be automatically unwrapped and sent as native chain `GAS`.
  - `adapters`: list of Synapse adapters, that will be used for swaps on **initial chain**.
  - `deadline`: deadline for swap on **destination chain**. If deadline check is failed, user **will receive bridge token**.
    > If bridge token on **destination chain** is `WGAS`, it will be automatically unwrapped and sent as native chain `GAS`.
- `kappa`: unique bridge transaction parameter. Only one transaction with a given `kappa` will be accepted by `Vault`.
