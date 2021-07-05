This contract is responsible for handling user Zaps into the SynapseBridge contract, through the Nerve Swap contracts. It does so
It does so by combining the action of addLiquidity() to the base swap pool, and then calling either deposit() or depositAndSwap() on the bridge.
This is done in hopes of automating portions of the bridge user experience to users, while keeping the SynapseBridge contract logic small.



This contract should be deployed with a base Swap.sol address and a SynapseBridge.sol address, otherwise, it will not function.

# Functions:
- [`constructor(contract ISwap _baseSwap, contract ISynapseBridge _synapseBridge)`](#NerveBridgeZap-constructor-contract-ISwap-contract-ISynapseBridge-)
- [`zapAndDeposit(address to, uint256 chainId, contract IERC20 token, uint256[] liquidityAmounts, uint256 minToMint, uint256 deadline)`](#NerveBridgeZap-zapAndDeposit-address-uint256-contract-IERC20-uint256---uint256-uint256-)
- [`zapAndDepositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256[] liquidityAmounts, uint256 minToMint, uint256 liqDeadline, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 swapDeadline)`](#NerveBridgeZap-zapAndDepositAndSwap-address-uint256-contract-IERC20-uint256---uint256-uint256-uint8-uint8-uint256-uint256-)


# Function `constructor(contract ISwap _baseSwap, contract ISynapseBridge _synapseBridge)` {#NerveBridgeZap-constructor-contract-ISwap-contract-ISynapseBridge-}
Constructs the contract, approves each token inside of baseSwap to be used by baseSwap (needed for addLiquidity())

# Function `zapAndDeposit(address to, uint256 chainId, contract IERC20 token, uint256[] liquidityAmounts, uint256 minToMint, uint256 deadline)` {#NerveBridgeZap-zapAndDeposit-address-uint256-contract-IERC20-uint256---uint256-uint256-}
Combines adding liquidity to the given Swap, and calls deposit() on the bridge using that LP token


## Parameters:
- `to`: address on other chain to bridge assets to

- `chainId`: which chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `liquidityAmounts`: the amounts of each token to add, in their native precision

- `minToMint`: the minimum LP tokens adding this amount of liquidity
should mint, otherwise revert. Handy for front-running mitigation

- `deadline`: latest timestamp to accept this transaction

# Function `zapAndDepositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256[] liquidityAmounts, uint256 minToMint, uint256 liqDeadline, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 swapDeadline)` {#NerveBridgeZap-zapAndDepositAndSwap-address-uint256-contract-IERC20-uint256---uint256-uint256-uint8-uint8-uint256-uint256-}
Combines adding liquidity to the given Swap, and calls depositAndSwap() on the bridge using that LP token


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


