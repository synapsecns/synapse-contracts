



# Functions:
- [`initialize()`](#SynapseBridge-initialize--)
- [`getFeeBalance(address tokenAddress)`](#SynapseBridge-getFeeBalance-address-)
- [`getETHFeeBalance()`](#SynapseBridge-getETHFeeBalance--)
- [`withdrawFees(contract IERC20 token, address to)`](#SynapseBridge-withdrawFees-contract-IERC20-address-)
- [`withdrawETHFees(address payable to)`](#SynapseBridge-withdrawETHFees-address-payable-)
- [`depositETH(address to, uint256 chainId, uint256 amount)`](#SynapseBridge-depositETH-address-uint256-uint256-)
- [`deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount)`](#SynapseBridge-deposit-address-uint256-contract-IERC20-uint256-)
- [`redeem(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount)`](#SynapseBridge-redeem-address-uint256-contract-ERC20Burnable-uint256-)
- [`withdraw(address to, contract IERC20 token, uint256 amount, uint256 fee)`](#SynapseBridge-withdraw-address-contract-IERC20-uint256-uint256-)
- [`withdrawETH(address payable to, uint256 amount, uint256 fee)`](#SynapseBridge-withdrawETH-address-payable-uint256-uint256-)
- [`mint(address to, contract IERC20Mintable token, uint256 amount, uint256 fee)`](#SynapseBridge-mint-address-contract-IERC20Mintable-uint256-uint256-)
- [`depositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)`](#SynapseBridge-depositAndSwap-address-uint256-contract-IERC20-uint256-uint8-uint8-uint256-uint256-)
- [`redeemAndSwap(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount, uint256 swapTokenAmount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline)`](#SynapseBridge-redeemAndSwap-address-uint256-contract-ERC20Burnable-uint256-uint256-uint8-uint256-uint256-)
- [`mintAndSwap(address to, contract IERC20Mintable token, uint256 amount, uint256 fee, contract IMetaSwapDeposit pool, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)`](#SynapseBridge-mintAndSwap-address-contract-IERC20Mintable-uint256-uint256-contract-IMetaSwapDeposit-uint8-uint8-uint256-uint256-)
- [`withdrawAndRemove(address to, contract IERC20 token, uint256 amount, uint256 fee, contract ISwap pool, uint256 swapTokenAmount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline)`](#SynapseBridge-withdrawAndRemove-address-contract-IERC20-uint256-uint256-contract-ISwap-uint256-uint8-uint256-uint256-)

# Events:
- [`TokenDeposit(address from, address to, uint256 chainId, contract IERC20 token, uint256 amount)`](#SynapseBridge-TokenDeposit-address-address-uint256-contract-IERC20-uint256-)
- [`TokenRedeem(address to, uint256 chainId, contract IERC20 token, uint256 amount)`](#SynapseBridge-TokenRedeem-address-uint256-contract-IERC20-uint256-)
- [`TokenWithdraw(address to, contract IERC20 token, uint256 amount, uint256 fee)`](#SynapseBridge-TokenWithdraw-address-contract-IERC20-uint256-uint256-)
- [`TokenMint(address to, contract IERC20Mintable token, uint256 amount, uint256 fee)`](#SynapseBridge-TokenMint-address-contract-IERC20Mintable-uint256-uint256-)
- [`TokenDepositAndSwap(address from, address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)`](#SynapseBridge-TokenDepositAndSwap-address-address-uint256-contract-IERC20-uint256-uint8-uint8-uint256-uint256-)
- [`TokenMintAndSwap(address to, contract IERC20Mintable token, uint256 amount, uint256 fee, bool swapSuccess)`](#SynapseBridge-TokenMintAndSwap-address-contract-IERC20Mintable-uint256-uint256-bool-)
- [`TokenRedeemAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint256 swapTokenAmount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline)`](#SynapseBridge-TokenRedeemAndSwap-address-uint256-contract-IERC20-uint256-uint256-uint8-uint256-uint256-)
- [`TokenWithdrawAndRemove(address to, contract IERC20 token, uint256 amount, uint256 fee, bool swapSuccess)`](#SynapseBridge-TokenWithdrawAndRemove-address-contract-IERC20-uint256-uint256-bool-)

# Function `initialize()` {#SynapseBridge-initialize--}
No description

# Function `getFeeBalance(address tokenAddress) → uint256` {#SynapseBridge-getFeeBalance-address-}
No description

# Function `getETHFeeBalance() → uint256` {#SynapseBridge-getETHFeeBalance--}
No description

# Function `withdrawFees(contract IERC20 token, address to)` {#SynapseBridge-withdrawFees-contract-IERC20-address-}
* @notice withdraw specified ERC20 token fees to a given address
* @param token ERC20 token in which fees acccumulated to transfer
* @param to Address to send the fees to

# Function `withdrawETHFees(address payable to)` {#SynapseBridge-withdrawETHFees-address-payable-}
* @notice withdraw gas token fees to a given address
* @param to Address to send the gas fees to

# Function `depositETH(address to, uint256 chainId, uint256 amount)` {#SynapseBridge-depositETH-address-uint256-uint256-}
Relays to nodes to transfers the underlying chain gas token cross-chain


## Parameters:
- `to`: address on other chain to bridge assets to

- `chainId`: which chain to bridge assets onto

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

# Function `deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount)` {#SynapseBridge-deposit-address-uint256-contract-IERC20-uint256-}
Relays to nodes to transfers an ERC20 token cross-chain


## Parameters:
- `to`: address on other chain to bridge assets to

- `chainId`: which chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

# Function `redeem(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount)` {#SynapseBridge-redeem-address-uint256-contract-ERC20Burnable-uint256-}
Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain


## Parameters:
- `to`: address on other chain to redeem underlying assets to

- `chainId`: which underlying chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

# Function `withdraw(address to, contract IERC20 token, uint256 amount, uint256 fee)` {#SynapseBridge-withdraw-address-contract-IERC20-uint256-uint256-}
Function to be called by the node group to withdraw the underlying assets from the contract


## Parameters:
- `to`: address on chain to send underlying assets to

- `token`: ERC20 compatible token to withdraw from the bridge

- `amount`: Amount in native token decimals to withdraw

- `fee`: Amount in native token decimals to save to the contract as fees

# Function `withdrawETH(address payable to, uint256 amount, uint256 fee)` {#SynapseBridge-withdrawETH-address-payable-uint256-uint256-}
Function to be called by the node group to withdraw the underlying gas asset from the contract


## Parameters:
- `to`: address on chain to send gas asset to

- `amount`: Amount in gas token decimals to withdraw (after subtracting fee already)

- `fee`: Amount in gas token decimals to save to the contract as fees

# Function `mint(address to, contract IERC20Mintable token, uint256 amount, uint256 fee)` {#SynapseBridge-mint-address-contract-IERC20Mintable-uint256-uint256-}
Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to). This is called by the nodes after a TokenDeposit event is emitted.

This means the SynapseBridge.sol contract must have minter access to the token attempting to be minted

## Parameters:
- `to`: address on other chain to redeem underlying assets to

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain post-fees

- `fee`: Amount in native token decimals to save to the contract as fees

# Function `depositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)` {#SynapseBridge-depositAndSwap-address-uint256-contract-IERC20-uint256-uint8-uint8-uint256-uint256-}
Relays to nodes to both transfer an ERC20 token cross-chain, and then have the nodes execute a swap through a liquidity pool on behalf of the user.


## Parameters:
- `to`: address on other chain to bridge assets to

- `chainId`: which chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

- `tokenIndexFrom`: the token the user wants to swap from

- `tokenIndexTo`: the token the user wants to swap to

- `minDy`: the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.

- `deadline`: latest timestamp to accept this transaction

# Function `redeemAndSwap(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount, uint256 swapTokenAmount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline)` {#SynapseBridge-redeemAndSwap-address-uint256-contract-ERC20Burnable-uint256-uint256-uint8-uint256-uint256-}
Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)


## Parameters:
- `to`: address on other chain to redeem underlying assets to

- `chainId`: which underlying chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

- `swapTokenAmount`: Amount of (typically) LP token to pass to the nodes to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token

- `swapTokenIndex`: Specifies which of the underlying LP assets the nodes should attempt to redeem for

- `swapMinAmount`: Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap

- `swapDeadline`: Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token

# Function `mintAndSwap(address to, contract IERC20Mintable token, uint256 amount, uint256 fee, contract IMetaSwapDeposit pool, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)` {#SynapseBridge-mintAndSwap-address-contract-IERC20Mintable-uint256-uint256-contract-IMetaSwapDeposit-uint8-uint8-uint256-uint256-}
Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to), and then attempt to swap the SynERC20 into the desired destination asset. This is called by the nodes after a TokenDepositAndSwap event is emitted.

This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted

## Parameters:
- `to`: address on other chain to redeem underlying assets to

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain post-fees

- `fee`: Amount in native token decimals to save to the contract as fees

- `pool`: Destination chain's pool to use to swap SynERC20 -> Asset. The nodes determine this by using PoolConfig.sol.

- `tokenIndexFrom`: Index of the SynERC20 asset in the pool

- `tokenIndexTo`: Index of the desired final asset

- `minDy`: Minumum amount (in final asset decimals) that must be swapped for, otherwise the user will receive the SynERC20.

- `deadline`: Epoch time of the deadline that the swap is allowed to be executed.

# Function `withdrawAndRemove(address to, contract IERC20 token, uint256 amount, uint256 fee, contract ISwap pool, uint256 swapTokenAmount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline)` {#SynapseBridge-withdrawAndRemove-address-contract-IERC20-uint256-uint256-contract-ISwap-uint256-uint8-uint256-uint256-}
Function to be called by the node group to withdraw the underlying assets from the contract


## Parameters:
- `to`: address on chain to send underlying assets to

- `token`: ERC20 compatible token to withdraw from the bridge

- `amount`: Amount in native token decimals to withdraw

- `fee`: Amount in native token decimals to save to the contract as fees

- `pool`: Destination chain's pool to use to swap SynERC20 -> Asset. The nodes determine this by using PoolConfig.sol.

- `swapTokenAmount`: Amount of (typically) LP token to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token

- `swapTokenIndex`: Specifies which of the underlying LP assets the nodes should attempt to redeem for

- `swapMinAmount`: Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap

- `swapDeadline`: Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token


# Event `TokenDeposit(address from, address to, uint256 chainId, contract IERC20 token, uint256 amount)` {#SynapseBridge-TokenDeposit-address-address-uint256-contract-IERC20-uint256-}
No description

# Event `TokenRedeem(address to, uint256 chainId, contract IERC20 token, uint256 amount)` {#SynapseBridge-TokenRedeem-address-uint256-contract-IERC20-uint256-}
No description

# Event `TokenWithdraw(address to, contract IERC20 token, uint256 amount, uint256 fee)` {#SynapseBridge-TokenWithdraw-address-contract-IERC20-uint256-uint256-}
No description

# Event `TokenMint(address to, contract IERC20Mintable token, uint256 amount, uint256 fee)` {#SynapseBridge-TokenMint-address-contract-IERC20Mintable-uint256-uint256-}
No description

# Event `TokenDepositAndSwap(address from, address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)` {#SynapseBridge-TokenDepositAndSwap-address-address-uint256-contract-IERC20-uint256-uint8-uint8-uint256-uint256-}
No description

# Event `TokenMintAndSwap(address to, contract IERC20Mintable token, uint256 amount, uint256 fee, bool swapSuccess)` {#SynapseBridge-TokenMintAndSwap-address-contract-IERC20Mintable-uint256-uint256-bool-}
No description

# Event `TokenRedeemAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint256 swapTokenAmount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline)` {#SynapseBridge-TokenRedeemAndSwap-address-uint256-contract-IERC20-uint256-uint256-uint8-uint256-uint256-}
No description

# Event `TokenWithdrawAndRemove(address to, contract IERC20 token, uint256 amount, uint256 fee, bool swapSuccess)` {#SynapseBridge-TokenWithdrawAndRemove-address-contract-IERC20-uint256-uint256-bool-}
No description

