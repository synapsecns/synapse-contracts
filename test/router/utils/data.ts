export const synUSD = 0
export const synETH = 1
export const uniAAA = 2
export const uniBBB = 3
export const uniCCC = 4

export const adapterNames = [
  "Synapse USD",
  "Synapse ETH",
  "UniSwap AAA",
  "UniSwap BBB",
  "UniSwap CCC",
]

export const decimals = {
  syn: 18,
  neth: 18,
  weth: 18,
  dai: 18,
  usdc: 6,
  usdt: 6,
  gmx: 18,
  ohm: 9,
  wbtc: 8,
}

export const seededLiquidity = {
  aaaSwapFactory: [
    {
      tokenA: "weth",
      tokenB: "wbtc",
      amountA: 50,
      amountB: 5,
    },
    {
      tokenA: "weth",
      tokenB: "usdt",
      amountA: 1,
      amountB: 10,
    },
    {
      tokenA: "gmx",
      tokenB: "usdc",
      amountA: 40,
      amountB: 60,
    },
    {
      tokenA: "neth",
      tokenB: "ohm",
      amountA: 20,
      amountB: 420,
    },
  ],
  bbbSwapFactory: [
    {
      tokenA: "wbtc",
      tokenB: "usdc",
      amountA: 1,
      amountB: 100,
    },
    {
      tokenA: "weth",
      tokenB: "dai",
      amountA: 10,
      amountB: 90,
    },
    {
      tokenA: "neth",
      tokenB: "usdt",
      amountA: 2,
      amountB: 15,
    },
    {
      tokenA: "wbtc",
      tokenB: "usdt",
      amountA: 2,
      amountB: 180,
    },
    {
      tokenA: "gmx",
      tokenB: "usdc",
      amountA: 20,
      amountB: 60,
    },
  ],
  cccSwapFactory: [
    {
      tokenA: "dai",
      tokenB: "usdc",
      amountA: 100,
      amountB: 120,
    },
    {
      tokenA: "wbtc",
      tokenB: "weth",
      amountA: 10,
      amountB: 80,
    },
    {
      tokenA: "neth",
      tokenB: "syn",
      amountA: 10,
      amountB: 13,
    },
  ],
}
