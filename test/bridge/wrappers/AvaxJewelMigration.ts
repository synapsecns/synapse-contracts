import { Signer } from "ethers"
import { impersonateAccount, asyncForEach, MAX_UINT256 } from "../../utils"
import { solidity } from "ethereum-waffle"
import { ethers, network } from "hardhat"

import chai from "chai"
import { getBigNumber } from "../utilities"
import {
  ERC20,
  SynapseERC20,
  AvaxJewelMigrationV2,
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

  let multiJewel: ERC20
  let synJewel: SynapseERC20

  let migrator: AvaxJewelMigrationV2

  let adminSigner: Signer

  let bridge: SynapseBridge

  const AMOUNT = getBigNumber(100)

  const MULTI_JEWEL = "0x4f60a160D8C2DDdaAfe16FCC57566dB84D674BD6"
  const SYN_JEWEL = "0x997Ddaa07d716995DE90577C123Db411584E5E46"
  const BRIDGE = "0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE"

  const FAT_CAT = "0x9aa76ae9f804e7a70ba3fb8395d0042079238e9c"

  const DFK_CHAIN_ID = 53935
  const HARMONY_ID = 1666600000

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

    multiJewel = (await ethers.getContractAt("ERC20", MULTI_JEWEL)) as ERC20
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

    let migratorFactory = await ethers.getContractFactory("AvaxJewelMigrationV2")
    migrator = (await migratorFactory.deploy()) as AvaxJewelMigrationV2

    let fatCat = await impersonateAccount(FAT_CAT)

    let adminRole = await synJewel.DEFAULT_ADMIN_ROLE()
    let minterRole = await synJewel.MINTER_ROLE()
    let admin = await synJewel.getRoleMember(adminRole, 0)
    adminSigner = await impersonateAccount(admin)

    await asyncForEach([FAT_CAT, admin], async (address) => {
      await network.provider.send("hardhat_setBalance", [
        address,
        "0xFFFFFFFFFFFFFFFFFFFF",
      ])
    })

    // It's time the fat cats had a heart attack
    await multiJewel.connect(fatCat).transfer(ownerAddress, AMOUNT)
    await multiJewel.connect(fatCat).transfer(dudeAddress, AMOUNT)
    await synJewel.connect(adminSigner).grantRole(minterRole, migrator.address)
  })

  describe("Sanity checks", function () {
    it("Migration contract is deployed correctly", async function () {
      expect(await migrator.LEGACY_TOKEN()).to.eq(MULTI_JEWEL)
      expect(await migrator.NEW_TOKEN()).to.eq(SYN_JEWEL)
      expect(await migrator.SYNAPSE_BRIDGE()).to.eq(BRIDGE)
    })

    it("Migration reverts when minting rights are revoked", async function () {
      let minterRole = await synJewel.MINTER_ROLE()
      await synJewel
        .connect(adminSigner)
        .revokeRole(minterRole, migrator.address)

      let ownerBalance = await multiJewel.balanceOf(ownerAddress)
      await multiJewel.approve(migrator.address, ownerBalance)
      let ownerAmount = getBigNumber(42)
      await expect(migrator.migrate(ownerAmount)).to.be.reverted
    })

    it("Migrating zero tokens reverts", async function () {
      let ownerBalance = await multiJewel.balanceOf(ownerAddress)
      await multiJewel.approve(migrator.address, ownerBalance)
      await expect(migrator.migrate(0)).to.be.reverted
    })

    it("Only owner can withdraw legacy tokens", async function () {
      let ownerBalance = await multiJewel.balanceOf(ownerAddress)
      let dudeBalance = await multiJewel.balanceOf(dudeAddress)
      let ownerAmount = getBigNumber(42)
      let dudeAmount = getBigNumber(13)

      await multiJewel.approve(migrator.address, ownerBalance)
      await multiJewel.connect(dude).approve(migrator.address, dudeBalance)

      await migrator.migrate(ownerAmount)
      await migrator
        .connect(dude)
        .migrateAndBridge(dudeAmount, dudeAddress, DFK_CHAIN_ID)

      await expect(migrator.connect(dude).redeemLegacy()).to.be.reverted

      await expect(() => migrator.redeemLegacy()).to.changeTokenBalance(
        multiJewel,
        owner,
        ownerAmount.add(dudeAmount),
      )
    })
  })

  describe("Migration", function () {
    it("Single-chain migration", async function () {
      let ownerBalance = await multiJewel.balanceOf(ownerAddress)
      let dudeBalance = await multiJewel.balanceOf(dudeAddress)
      let ownerAmount = getBigNumber(42)
      let dudeAmount = getBigNumber(13)

      await multiJewel.approve(migrator.address, ownerBalance)
      await multiJewel.connect(dude).approve(migrator.address, dudeBalance)

      await expect(() => migrator.migrate(ownerAmount)).to.changeTokenBalance(
        synJewel,
        owner,
        ownerAmount,
      )
      expect(await multiJewel.balanceOf(ownerAddress)).to.eq(
        ownerBalance.sub(ownerAmount),
      )

      await expect(() =>
        migrator.connect(dude).migrate(dudeAmount),
      ).to.changeTokenBalance(synJewel, dude, dudeAmount)
      expect(await multiJewel.balanceOf(dudeAddress)).to.eq(
        dudeBalance.sub(dudeAmount),
      )
    })

    it("Cross-chain migration to DFK (Bridge event emitted)", async function () {
      let ownerBalance = await multiJewel.balanceOf(ownerAddress)
      let dudeBalance = await multiJewel.balanceOf(dudeAddress)
      let ownerAmount = getBigNumber(42)
      let dudeAmount = getBigNumber(13)

      await multiJewel.approve(migrator.address, ownerBalance)
      await multiJewel.connect(dude).approve(migrator.address, dudeBalance)

      await expect(
        migrator.migrateAndBridge(ownerAmount, ownerAddress, DFK_CHAIN_ID),
      )
        .to.emit(bridge, "TokenRedeem")
        .withArgs(ownerAddress, DFK_CHAIN_ID, synJewel.address, ownerAmount)

      expect(await multiJewel.balanceOf(ownerAddress)).to.eq(
        ownerBalance.sub(ownerAmount),
      )

      await expect(
        migrator
          .connect(dude)
          .migrateAndBridge(dudeAmount, dudeAddress, DFK_CHAIN_ID),
      )
        .to.emit(bridge, "TokenRedeem")
        .withArgs(dudeAddress, DFK_CHAIN_ID, synJewel.address, dudeAmount)
      expect(await multiJewel.balanceOf(dudeAddress)).to.eq(
        dudeBalance.sub(dudeAmount),
      )
    })

    it("Cross-chain migration to Harmony (Bridge event emitted)", async function () {
      let ownerBalance = await multiJewel.balanceOf(ownerAddress)
      let dudeBalance = await multiJewel.balanceOf(dudeAddress)
      let ownerAmount = getBigNumber(42)
      let dudeAmount = getBigNumber(13)

      await multiJewel.approve(migrator.address, ownerBalance)
      await multiJewel.connect(dude).approve(migrator.address, dudeBalance)

      await expect(
        migrator.migrateAndBridge(ownerAmount, ownerAddress, HARMONY_ID),
      )
        .to.emit(bridge, "TokenRedeemAndSwap")
        .withArgs(
          ownerAddress,
          HARMONY_ID,
          synJewel.address,
          ownerAmount,
          1,
          0,
          0,
          MAX_UINT256,
        )

      expect(await multiJewel.balanceOf(ownerAddress)).to.eq(
        ownerBalance.sub(ownerAmount),
      )

      await expect(
        migrator
          .connect(dude)
          .migrateAndBridge(dudeAmount, dudeAddress, HARMONY_ID),
      )
        .to.emit(bridge, "TokenRedeemAndSwap")
        .withArgs(
          dudeAddress,
          HARMONY_ID,
          synJewel.address,
          dudeAmount,
          1,
          0,
          0,
          MAX_UINT256,
        )
      expect(await multiJewel.balanceOf(dudeAddress)).to.eq(
        dudeBalance.sub(dudeAmount),
      )
    })
  })
})
