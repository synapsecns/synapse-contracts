import { Signer } from "ethers"
import { impersonateAccount, MAX_UINT256 } from "../../utils"
import { solidity } from "ethereum-waffle"
import { ethers, network, web3 } from "hardhat"

import chai from "chai"
import { getBigNumber } from "../utilities"
import {
  SynapseERC20,
  AvaxJewelSwap,
  SynapseBridge,
} from "../../../build/typechain"

chai.use(solidity)
const { expect } = chai

describe("Avax Jewel Migration", async function () {
  let signers: Array<Signer>

  let owner: Signer
  let ownerAddress: string
  let dude: Signer
  let dudeAddress: string

  let synJewel: SynapseERC20

  let swap: AvaxJewelSwap

  let validatorSigner: Signer

  let bridge: SynapseBridge

  const AMOUNT = getBigNumber(420)
  const FEE = getBigNumber(69)

  const SYN_JEWEL = "0x997Ddaa07d716995DE90577C123Db411584E5E46"

  const BRIDGE = "0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE"

  const VALIDATOR = "0x230A1AC45690B9Ae1176389434610B9526d2f21b"

  const DFK_CHAIN_ID = 53935

  before(async function () {
    // 2022-03-26
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.AVAX_API,
            blockNumber: 12600000,
          },
        },
      ],
    })

    synJewel = (await ethers.getContractAt(
      "SynapseERC20",
      SYN_JEWEL,
    )) as SynapseERC20
    bridge = (await ethers.getContractAt(
      "SynapseBridge",
      BRIDGE,
    )) as SynapseBridge
  })

  beforeEach(async function () {
    signers = await ethers.getSigners()
    owner = signers[0]
    ownerAddress = await owner.getAddress()
    dude = signers[1]
    dudeAddress = await dude.getAddress()

    let swapFactory = await ethers.getContractFactory("AvaxJewelSwap")
    swap = (await swapFactory.deploy()) as AvaxJewelSwap

    validatorSigner = await impersonateAccount(VALIDATOR)

    await network.provider.send("hardhat_setBalance", [
      VALIDATOR,
      "0xFFFFFFFFFFFFFFFFFFFF",
    ])
  })

  it("Swap reverts", async function () {
    await expect(swap.swap(0, 1, 1, 0, MAX_UINT256)).to.be.revertedWith(
      "There is no swap",
    )
  })

  it("Bridging completes with minDy > 0", async function () {
    await expect(() =>
      bridge
        .connect(validatorSigner)
        .mintAndSwap(
          dudeAddress,
          SYN_JEWEL,
          AMOUNT,
          FEE,
          swap.address,
          1,
          0,
          420,
          0,
          web3.utils.keccak256("I am unique"),
        ),
    ).to.changeTokenBalance(synJewel, dude, AMOUNT.sub(FEE))
  })

  it("Bridging completes with minDy = 0", async function () {
    await expect(() =>
      bridge
        .connect(validatorSigner)
        .mintAndSwap(
          dudeAddress,
          SYN_JEWEL,
          AMOUNT,
          FEE,
          swap.address,
          1,
          0,
          0,
          0,
          web3.utils.keccak256("I am also unique"),
        ),
    ).to.changeTokenBalance(synJewel, dude, AMOUNT.sub(FEE))
  })
})
