This contract is responsible for handling user Zaps into the SynapseBridge contract, through the Nerve Swap contracts. It does so
It does so by combining the action of addLiquidity() to the base swap pool, and then calling either deposit() or depositAndSwap() on the bridge.
This is done in hopes of automating portions of the bridge user experience to users, while keeping the SynapseBridge contract logic small.


This contract should be deployed with a base Swap.sol address and a SynapseBridge.sol address, otherwise, it will not function.

# Functions:
- [`constructor(contract ISwap _baseSwap, contract ISynapseBridge _synapseBridge)`](#NerveBridgeZap-constructor-contract-ISwap-contract-ISynapseBridge-)
- [`calculateTokenAmount(uint256[] amounts, bool deposit)`](#NerveBridgeZap-calculateTokenAmount-uint256---bool-)
- [`zapAndDeposit(address to, uint256 chainId, contract IERC20 token, uint256[] liquidityAmounts, uint256 minToMint, uint256 deadline)`](#NerveBridgeZap-zapAndDeposit-address-uint256-contract-IERC20-uint256---uint256-uint256-)
- [`zapAndDepositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256[] liquidityAmounts, uint256 minToMint, uint256 liqDeadline, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 swapDeadline)`](#NerveBridgeZap-zapAndDepositAndSwap-address-uint256-contract-IERC20-uint256---uint256-uint256-uint8-uint8-uint256-uint256-)
- [`deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount)`](#NerveBridgeZap-deposit-address-uint256-contract-IERC20-uint256-)
- [`depositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)`](#NerveBridgeZap-depositAndSwap-address-uint256-contract-IERC20-uint256-uint8-uint8-uint256-uint256-)


# <a id="NerveBridgeZap-constructor-contract-ISwap-contract-ISynapseBridge-"></a> Function `constructor(contract ISwap _baseSwap, contract ISynapseBridge _synapseBridge)`
No description
# <a id="NerveBridgeZap-calculateTokenAmount-uint256---bool-"></a> Function `calculateTokenAmount(uint256[] amounts, bool deposit) → uint256`
This shouldn't be used outside frontends for user estimates.


## Parameters:
- `amounts`: an array of token amounts to deposit or withdrawal,
corresponding to pooledTokens. The amount should be in each
pooled token's native precision.

- `deposit`: whether this is a deposit or a withdrawal

## Return Values:
- token amount the user will receive
# <a id="NerveBridgeZap-zapAndDeposit-address-uint256-contract-IERC20-uint256---uint256-uint256-"></a> Function `zapAndDeposit(address to, uint256 chainId, contract IERC20 token, uint256[] liquidityAmounts, uint256 minToMint, uint256 deadline)`
No description
## Parameters:
- `to`: address on other chain to bridge assets to

- `chainId`: which chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `liquidityAmounts`: the amounts of each token to add, in their native precision

- `minToMint`: the minimum LP tokens adding this amount of liquidity
should mint, otherwise revert. Handy for front-running mitigation

- `deadline`: latest timestamp to accept this transaction

# <a id="NerveBridgeZap-zapAndDepositAndSwap-address-uint256-contract-IERC20-uint256---uint256-uint256-uint8-uint8-uint256-uint256-"></a> Function `zapAndDepositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256[] liquidityAmounts, uint256 minToMint, uint256 liqDeadline, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 swapDeadline)`
No description
## Parameters:
- `to`: address on other chain to bridge assets to

- `chainId`: which chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `liquidityAmounts`: the amounts of each token to add, in their native precision

- `minToMint`: the minimum LP tokens adding this amount of liquidity
should mint, otherwise revert. Handy for front-running mitigation

- `liqDeadline`: latest timestamp to accept this transaction

- `tokenIndexFrom`: the token the user wants to swap from

- `tokenIndexTo`: the token the user wants to swap to

- `minDy`: the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.

- `swapDeadline`: latest timestamp to accept this transaction

# <a id="NerveBridgeZap-deposit-address-uint256-contract-IERC20-uint256-"></a> Function `deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount)`
No description
## Parameters:
- `to`: address on other chain to bridge assets to

- `chainId`: which chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

# <a id="NerveBridgeZap-depositAndSwap-address-uint256-contract-IERC20-uint256-uint8-uint8-uint256-uint256-"></a> Function `depositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)`
No description
## Parameters:
- `to`: address on other chain to bridge assets to

- `chainId`: which chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

- `tokenIndexFrom`: the token the user wants to swap from

- `tokenIndexTo`: the token the user wants to swap to

- `minDy`: the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.

- `deadline`: latest timestamp to accept this transaction


