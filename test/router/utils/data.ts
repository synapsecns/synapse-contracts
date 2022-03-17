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
      amountA: 500,
      amountB: 50,
    },
    {
      tokenA: "weth",
      tokenB: "usdt",
      amountA: 100,
      amountB: 1000,
    },
    {
      tokenA: "gmx",
      tokenB: "usdc",
      amountA: 400,
      amountB: 600,
    },
    {
      tokenA: "neth",
      tokenB: "ohm",
      amountA: 200,
      amountB: 4200,
    },
  ],
  bbbSwapFactory: [
    {
      tokenA: "wbtc",
      tokenB: "usdc",
      amountA: 10,
      amountB: 1050,
    },
    {
      tokenA: "weth",
      tokenB: "dai",
      amountA: 100,
      amountB: 970,
    },
    {
      tokenA: "neth",
      tokenB: "usdt",
      amountA: 200,
      amountB: 2010,
    },
    {
      tokenA: "wbtc",
      tokenB: "usdt",
      amountA: 20,
      amountB: 1980,
    },
    {
      tokenA: "gmx",
      tokenB: "usdc",
      amountA: 200,
      amountB: 320,
    },
  ],
  cccSwapFactory: [
    {
      tokenA: "dai",
      tokenB: "usdc",
      amountA: 1000,
      amountB: 1075,
    },
    {
      tokenA: "wbtc",
      tokenB: "weth",
      amountA: 100,
      amountB: 970,
    },
    {
      tokenA: "neth",
      tokenB: "syn",
      amountA: 100,
      amountB: 130,
    },
  ],
}
