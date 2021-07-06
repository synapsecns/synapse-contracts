


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

# <a id="SynapseBridge-initialize--"></a> Function `initialize()`
No description
# <a id="SynapseBridge-getFeeBalance-address-"></a> Function `getFeeBalance(address tokenAddress) → uint256`
No description
# <a id="SynapseBridge-getETHFeeBalance--"></a> Function `getETHFeeBalance() → uint256`
No description
# <a id="SynapseBridge-withdrawFees-contract-IERC20-address-"></a> Function `withdrawFees(contract IERC20 token, address to)`
No description
# <a id="SynapseBridge-withdrawETHFees-address-payable-"></a> Function `withdrawETHFees(address payable to)`
No description
# <a id="SynapseBridge-depositETH-address-uint256-uint256-"></a> Function `depositETH(address to, uint256 chainId, uint256 amount)`
No description
## Parameters:
- `to`: address on other chain to bridge assets to

- `chainId`: which chain to bridge assets onto

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

# <a id="SynapseBridge-deposit-address-uint256-contract-IERC20-uint256-"></a> Function `deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount)`
No description
## Parameters:
- `to`: address on other chain to bridge assets to

- `chainId`: which chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

# <a id="SynapseBridge-redeem-address-uint256-contract-ERC20Burnable-uint256-"></a> Function `redeem(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount)`
No description
## Parameters:
- `to`: address on other chain to redeem underlying assets to

- `chainId`: which underlying chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

# <a id="SynapseBridge-withdraw-address-contract-IERC20-uint256-uint256-"></a> Function `withdraw(address to, contract IERC20 token, uint256 amount, uint256 fee)`
No description
## Parameters:
- `to`: address on chain to send underlying assets to

- `token`: ERC20 compatible token to withdraw from the bridge

- `amount`: Amount in native token decimals to withdraw

- `fee`: Amount in native token decimals to save to the contract as fees

# <a id="SynapseBridge-withdrawETH-address-payable-uint256-uint256-"></a> Function `withdrawETH(address payable to, uint256 amount, uint256 fee)`
No description
## Parameters:
- `to`: address on chain to send gas asset to

- `amount`: Amount in gas token decimals to withdraw (after subtracting fee already)

- `fee`: Amount in gas token decimals to save to the contract as fees

# <a id="SynapseBridge-mint-address-contract-IERC20Mintable-uint256-uint256-"></a> Function `mint(address to, contract IERC20Mintable token, uint256 amount, uint256 fee)`
This means the SynapseBridge.sol contract must have minter access to the token attempting to be minted

## Parameters:
- `to`: address on other chain to redeem underlying assets to

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain post-fees

- `fee`: Amount in native token decimals to save to the contract as fees

# <a id="SynapseBridge-depositAndSwap-address-uint256-contract-IERC20-uint256-uint8-uint8-uint256-uint256-"></a> Function `depositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)`
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

# <a id="SynapseBridge-redeemAndSwap-address-uint256-contract-ERC20Burnable-uint256-uint256-uint8-uint256-uint256-"></a> Function `redeemAndSwap(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount, uint256 swapTokenAmount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline)`
No description
## Parameters:
- `to`: address on other chain to redeem underlying assets to

- `chainId`: which underlying chain to bridge assets onto

- `token`: ERC20 compatible token to deposit into the bridge

- `amount`: Amount in native token decimals to transfer cross-chain pre-fees

- `swapTokenAmount`: Amount of (typically) LP token to pass to the nodes to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token

- `swapTokenIndex`: Specifies which of the underlying LP assets the nodes should attempt to redeem for

- `swapMinAmount`: Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap

- `swapDeadline`: Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token

# <a id="SynapseBridge-mintAndSwap-address-contract-IERC20Mintable-uint256-uint256-contract-IMetaSwapDeposit-uint8-uint8-uint256-uint256-"></a> Function `mintAndSwap(address to, contract IERC20Mintable token, uint256 amount, uint256 fee, contract IMetaSwapDeposit pool, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)`
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

# <a id="SynapseBridge-withdrawAndRemove-address-contract-IERC20-uint256-uint256-contract-ISwap-uint256-uint8-uint256-uint256-"></a> Function `withdrawAndRemove(address to, contract IERC20 token, uint256 amount, uint256 fee, contract ISwap pool, uint256 swapTokenAmount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline)`
No description
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


# <a id="SynapseBridge-TokenDeposit-address-address-uint256-contract-IERC20-uint256-"></a> Event `TokenDeposit(address from, address to, uint256 chainId, contract IERC20 token, uint256 amount)` 
No description
# <a id="SynapseBridge-TokenRedeem-address-uint256-contract-IERC20-uint256-"></a> Event `TokenRedeem(address to, uint256 chainId, contract IERC20 token, uint256 amount)` 
No description
# <a id="SynapseBridge-TokenWithdraw-address-contract-IERC20-uint256-uint256-"></a> Event `TokenWithdraw(address to, contract IERC20 token, uint256 amount, uint256 fee)` 
No description
# <a id="SynapseBridge-TokenMint-address-contract-IERC20Mintable-uint256-uint256-"></a> Event `TokenMint(address to, contract IERC20Mintable token, uint256 amount, uint256 fee)` 
No description
# <a id="SynapseBridge-TokenDepositAndSwap-address-address-uint256-contract-IERC20-uint256-uint8-uint8-uint256-uint256-"></a> Event `TokenDepositAndSwap(address from, address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline)` 
No description
# <a id="SynapseBridge-TokenMintAndSwap-address-contract-IERC20Mintable-uint256-uint256-bool-"></a> Event `TokenMintAndSwap(address to, contract IERC20Mintable token, uint256 amount, uint256 fee, bool swapSuccess)` 
No description
# <a id="SynapseBridge-TokenRedeemAndSwap-address-uint256-contract-IERC20-uint256-uint256-uint8-uint256-uint256-"></a> Event `TokenRedeemAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint256 swapTokenAmount, uint8 swapTokenIndex, uint256 swapMinAmount, uint256 swapDeadline)` 
No description
# <a id="SynapseBridge-TokenWithdrawAndRemove-address-contract-IERC20-uint256-uint256-bool-"></a> Event `TokenWithdrawAndRemove(address to, contract IERC20 token, uint256 amount, uint256 fee, bool swapSuccess)` 
No description
