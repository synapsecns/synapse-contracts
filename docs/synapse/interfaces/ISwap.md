


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


# <a id="ISwap-getA--"></a> Function `getA() → uint256`
No description
# <a id="ISwap-getToken-uint8-"></a> Function `getToken(uint8 index) → contract IERC20`
No description
# <a id="ISwap-getTokenIndex-address-"></a> Function `getTokenIndex(address tokenAddress) → uint8`
No description
# <a id="ISwap-getTokenBalance-uint8-"></a> Function `getTokenBalance(uint8 index) → uint256`
No description
# <a id="ISwap-getVirtualPrice--"></a> Function `getVirtualPrice() → uint256`
No description
# <a id="ISwap-calculateSwap-uint8-uint8-uint256-"></a> Function `calculateSwap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx) → uint256`
No description
# <a id="ISwap-calculateTokenAmount-uint256---bool-"></a> Function `calculateTokenAmount(uint256[] amounts, bool deposit) → uint256`
No description
# <a id="ISwap-calculateRemoveLiquidity-uint256-"></a> Function `calculateRemoveLiquidity(uint256 amount) → uint256[]`
No description
# <a id="ISwap-calculateRemoveLiquidityOneToken-uint256-uint8-"></a> Function `calculateRemoveLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex) → uint256 availableTokenAmount`
No description
# <a id="ISwap-initialize-contract-IERC20---uint8---string-string-uint256-uint256-uint256-address-"></a> Function `initialize(contract IERC20[] pooledTokens, uint8[] decimals, string lpTokenName, string lpTokenSymbol, uint256 a, uint256 fee, uint256 adminFee, address lpTokenTargetAddress)`
No description
# <a id="ISwap-swap-uint8-uint8-uint256-uint256-uint256-"></a> Function `swap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) → uint256`
No description
# <a id="ISwap-addLiquidity-uint256---uint256-uint256-"></a> Function `addLiquidity(uint256[] amounts, uint256 minToMint, uint256 deadline) → uint256`
No description
# <a id="ISwap-removeLiquidity-uint256-uint256---uint256-"></a> Function `removeLiquidity(uint256 amount, uint256[] minAmounts, uint256 deadline) → uint256[]`
No description
# <a id="ISwap-removeLiquidityOneToken-uint256-uint8-uint256-uint256-"></a> Function `removeLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex, uint256 minAmount, uint256 deadline) → uint256`
No description
# <a id="ISwap-removeLiquidityImbalance-uint256---uint256-uint256-"></a> Function `removeLiquidityImbalance(uint256[] amounts, uint256 maxBurnAmount, uint256 deadline) → uint256`
No description

