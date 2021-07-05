



# Functions:
- [`getA()`](#ISwap-getA--)
- [`getToken(uint8 index)`](#ISwap-getToken-uint8-)
- [`getTokenIndex(address tokenAddress)`](#ISwap-getTokenIndex-address-)
- [`getTokenBalance(uint8 index)`](#ISwap-getTokenBalance-uint8-)
- [`getVirtualPrice()`](#ISwap-getVirtualPrice--)
- [`calculateSwap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx)`](#ISwap-calculateSwap-uint8-uint8-uint256-)
- [`calculateTokenAmount(uint256[] amounts, bool deposit)`](#ISwap-calculateTokenAmount-uint256---bool-)
- [`calculateRemoveLiquidity(uint256 amount)`](#ISwap-calculateRemoveLiquidity-uint256-)
- [`calculateRemoveLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex)`](#ISwap-calculateRemoveLiquidityOneToken-uint256-uint8-)
- [`initialize(contract IERC20[] pooledTokens, uint8[] decimals, string lpTokenName, string lpTokenSymbol, uint256 a, uint256 fee, uint256 adminFee, address lpTokenTargetAddress)`](#ISwap-initialize-contract-IERC20---uint8---string-string-uint256-uint256-uint256-address-)
- [`swap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline)`](#ISwap-swap-uint8-uint8-uint256-uint256-uint256-)
- [`addLiquidity(uint256[] amounts, uint256 minToMint, uint256 deadline)`](#ISwap-addLiquidity-uint256---uint256-uint256-)
- [`removeLiquidity(uint256 amount, uint256[] minAmounts, uint256 deadline)`](#ISwap-removeLiquidity-uint256-uint256---uint256-)
- [`removeLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex, uint256 minAmount, uint256 deadline)`](#ISwap-removeLiquidityOneToken-uint256-uint8-uint256-uint256-)
- [`removeLiquidityImbalance(uint256[] amounts, uint256 maxBurnAmount, uint256 deadline)`](#ISwap-removeLiquidityImbalance-uint256---uint256-uint256-)


# Function `getA() → uint256` {#ISwap-getA--}
No description

# Function `getToken(uint8 index) → contract IERC20` {#ISwap-getToken-uint8-}
No description

# Function `getTokenIndex(address tokenAddress) → uint8` {#ISwap-getTokenIndex-address-}
No description

# Function `getTokenBalance(uint8 index) → uint256` {#ISwap-getTokenBalance-uint8-}
No description

# Function `getVirtualPrice() → uint256` {#ISwap-getVirtualPrice--}
No description

# Function `calculateSwap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx) → uint256` {#ISwap-calculateSwap-uint8-uint8-uint256-}
No description

# Function `calculateTokenAmount(uint256[] amounts, bool deposit) → uint256` {#ISwap-calculateTokenAmount-uint256---bool-}
No description

# Function `calculateRemoveLiquidity(uint256 amount) → uint256[]` {#ISwap-calculateRemoveLiquidity-uint256-}
No description

# Function `calculateRemoveLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex) → uint256 availableTokenAmount` {#ISwap-calculateRemoveLiquidityOneToken-uint256-uint8-}
No description

# Function `initialize(contract IERC20[] pooledTokens, uint8[] decimals, string lpTokenName, string lpTokenSymbol, uint256 a, uint256 fee, uint256 adminFee, address lpTokenTargetAddress)` {#ISwap-initialize-contract-IERC20---uint8---string-string-uint256-uint256-uint256-address-}
No description

# Function `swap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) → uint256` {#ISwap-swap-uint8-uint8-uint256-uint256-uint256-}
No description

# Function `addLiquidity(uint256[] amounts, uint256 minToMint, uint256 deadline) → uint256` {#ISwap-addLiquidity-uint256---uint256-uint256-}
No description

# Function `removeLiquidity(uint256 amount, uint256[] minAmounts, uint256 deadline) → uint256[]` {#ISwap-removeLiquidity-uint256-uint256---uint256-}
No description

# Function `removeLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex, uint256 minAmount, uint256 deadline) → uint256` {#ISwap-removeLiquidityOneToken-uint256-uint8-uint256-uint256-}
No description

# Function `removeLiquidityImbalance(uint256[] amounts, uint256 maxBurnAmount, uint256 deadline) → uint256` {#ISwap-removeLiquidityImbalance-uint256---uint256-uint256-}
No description


