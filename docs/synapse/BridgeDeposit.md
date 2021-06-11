



  # Functions:
      - [`initialize()`](#BridgeDeposit-initialize--)
      - [`getFeeBalance(address tokenAddress)`](#BridgeDeposit-getFeeBalance-address-)
      - [`getETHFeeBalance()`](#BridgeDeposit-getETHFeeBalance--)
      - [`withdrawFees(contract IERC20 token, address to)`](#BridgeDeposit-withdrawFees-contract-IERC20-address-)
      - [`withdrawETHAdminFees(address payable to)`](#BridgeDeposit-withdrawETHAdminFees-address-payable-)
      - [`depositETH(address to, uint256 chainId, uint256 amount)`](#BridgeDeposit-depositETH-address-uint256-uint256-)
      - [`deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount)`](#BridgeDeposit-deposit-address-uint256-contract-IERC20-uint256-)
      - [`redeem(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount)`](#BridgeDeposit-redeem-address-uint256-contract-ERC20Burnable-uint256-)
      - [`withdraw(address to, contract IERC20 token, uint256 amount, uint256 fee)`](#BridgeDeposit-withdraw-address-contract-IERC20-uint256-uint256-)
      - [`withdrawETH(address payable to, uint256 amount, uint256 fee)`](#BridgeDeposit-withdrawETH-address-payable-uint256-uint256-)
      - [`mint(address to, contract IERC20Mintable token, uint256 amount, uint256 fee)`](#BridgeDeposit-mint-address-contract-IERC20Mintable-uint256-uint256-)

  # Events:
    - [`TokenDeposit(address from, address to, uint256 chainId, contract IERC20 token, uint256 amount)`](#BridgeDeposit-TokenDeposit-address-address-uint256-contract-IERC20-uint256-)
    - [`TokenRedeem(address to, uint256 chainId, contract IERC20 token, uint256 amount)`](#BridgeDeposit-TokenRedeem-address-uint256-contract-IERC20-uint256-)
    - [`TokenWithdraw(address to, contract IERC20 token, uint256 amount, uint256 fee)`](#BridgeDeposit-TokenWithdraw-address-contract-IERC20-uint256-uint256-)
    - [`TokenMint(address to, contract IERC20Mintable token, uint256 amount, uint256 fee)`](#BridgeDeposit-TokenMint-address-contract-IERC20Mintable-uint256-uint256-)

    # Function `initialize()` {#BridgeDeposit-initialize--}
    No description
    
    # Function `getFeeBalance(address tokenAddress) → uint256` {#BridgeDeposit-getFeeBalance-address-}
    No description
    
    # Function `getETHFeeBalance() → uint256` {#BridgeDeposit-getETHFeeBalance--}
    No description
    
    # Function `withdrawFees(contract IERC20 token, address to)` {#BridgeDeposit-withdrawFees-contract-IERC20-address-}
    withdraw specified ERC20 token fees to a given address

    
      ## Parameters:
        - `token`:
        ERC20 token in which fees acccumulated to transfer

        - `to`:
        Address to send the fees to
    # Function `withdrawETHAdminFees(address payable to)` {#BridgeDeposit-withdrawETHAdminFees-address-payable-}
    withdraw gas token fees to a given address

    
      ## Parameters:
        - `to`:
        Address to send the gas fees to
    # Function `depositETH(address to, uint256 chainId, uint256 amount)` {#BridgeDeposit-depositETH-address-uint256-uint256-}
    Relays to nodes to transfers the underlying chain gas token cross-chain
    @param to address on other chain to bridge assets to
    @param chainId which chain to bridge assets onto
    @param amount Amount in native token decimals to transfer cross-chain pre-fees

    
    # Function `deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount)` {#BridgeDeposit-deposit-address-uint256-contract-IERC20-uint256-}
    Relays to nodes to transfers an ERC20 token cross-chain
    @param to address on other chain to bridge assets to
    @param chainId which chain to bridge assets onto
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain pre-fees

    
    # Function `redeem(address to, uint256 chainId, contract ERC20Burnable token, uint256 amount)` {#BridgeDeposit-redeem-address-uint256-contract-ERC20Burnable-uint256-}
    Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
    @param to address on other chain to redeem underlying assets to
    @param chainId which underlying chain to bridge assets onto
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain pre-fees

    
    # Function `withdraw(address to, contract IERC20 token, uint256 amount, uint256 fee)` {#BridgeDeposit-withdraw-address-contract-IERC20-uint256-uint256-}
    Function to be called by the node group to withdraw the underlying assets from the contract
    @param to address on chain to send underlying assets to
    @param token ERC20 compatible token to withdraw from the bridge
    @param amount Amount in native token decimals to withdraw
    @param fee Amount in native token decimals to save to the contract as fees

    
    # Function `withdrawETH(address payable to, uint256 amount, uint256 fee)` {#BridgeDeposit-withdrawETH-address-payable-uint256-uint256-}
    Function to be called by the node group to withdraw the underlying gas asset from the contract
    @param to address on chain to send gas asset to
    @param amount Amount in gas token decimals to withdraw (after subtracting fee already)
    @param fee Amount in gas token decimals to save to the contract as fees

    
    # Function `mint(address to, contract IERC20Mintable token, uint256 amount, uint256 fee)` {#BridgeDeposit-mint-address-contract-IERC20Mintable-uint256-uint256-}
    Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
    @dev This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted
    @param to address on other chain to redeem underlying assets to
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain post-fees
    @param fee Amount in native token decimals to save to the contract as fees

    

  # Event `TokenDeposit(address from, address to, uint256 chainId, contract IERC20 token, uint256 amount)` {#BridgeDeposit-TokenDeposit-address-address-uint256-contract-IERC20-uint256-}
  No description
  
  # Event `TokenRedeem(address to, uint256 chainId, contract IERC20 token, uint256 amount)` {#BridgeDeposit-TokenRedeem-address-uint256-contract-IERC20-uint256-}
  No description
  
  # Event `TokenWithdraw(address to, contract IERC20 token, uint256 amount, uint256 fee)` {#BridgeDeposit-TokenWithdraw-address-contract-IERC20-uint256-uint256-}
  No description
  
  # Event `TokenMint(address to, contract IERC20Mintable token, uint256 amount, uint256 fee)` {#BridgeDeposit-TokenMint-address-contract-IERC20Mintable-uint256-uint256-}
  No description
  
