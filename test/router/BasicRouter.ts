import { expect } from "chai"
import { web3 } from "hardhat"
import { solidity } from "ethereum-waffle"
import { prepare, deploy, getBigNumber } from "./utils"
import { BasicRouter } from "../../build/typechain/BasicRouter"
import { BasicQuoter } from "../../build/typechain/BasicQuoter"
import { ERC20Mock } from "../../build/typechain/ERC20Mock"

import chai from "chai"
import { Signer } from "ethers"

chai.use(solidity)

describe("Basic Router + Quoter", function () {
  let router: BasicRouter
  let quoter: BasicQuoter

  let owner: Signer
  let ownerAddress: string

  let dude: Signer
  let dudeAddress: string

  let signers: Array<Signer>

  let token: ERC20Mock

  const GOVERNANCE_ROLE = web3.utils.keccak256("GOVERNANCE_ROLE")
  const ADAPTERS_STORAGE_ROLE = web3.utils.keccak256("ADAPTERS_STORAGE_ROLE")

  before(async function () {
    await prepare(this, ["BasicQuoter", "BasicRouter", "ERC20Mock", "WETH9"])

    owner = this.owner
    ownerAddress = await owner.getAddress()

    dude = this.dude
    dudeAddress = await dude.getAddress()

    signers = this.signers
  })

  beforeEach(async function () {
    await deploy(this, [
      ["syn", this.ERC20Mock, ["SYN", "Synapse Token", getBigNumber(1000)]],
      ["weth", this.WETH9, []],
    ])

    token = this.syn

    await deploy(this, [["router", this.BasicRouter, [this.weth.address]]])

    await deploy(this, [["quoter", this.BasicQuoter, [this.router.address, 4]]])

    router = this.router
    quoter = this.quoter

    await router.grantRole(ADAPTERS_STORAGE_ROLE, this.quoter.address)
  })

  describe("Router: Access Checks", function () {
    it("Only admin can modify AdaptersStorage", async function () {
      await router.renounceRole(GOVERNANCE_ROLE, ownerAddress)
      await router.grantRole(GOVERNANCE_ROLE, dudeAddress)

      // Owner is still admin and should be able to set AdaptersStorage
      await router.revokeRole(ADAPTERS_STORAGE_ROLE, quoter.address)
      await router.grantRole(ADAPTERS_STORAGE_ROLE, quoter.address)

      // Dude is governance, which should NOT be able to set AdaptersStorage
      await expect(
        router.connect(dude).revokeRole(ADAPTERS_STORAGE_ROLE, quoter.address),
      ).to.be.reverted

      await expect(
        router.connect(dude).grantRole(ADAPTERS_STORAGE_ROLE, dudeAddress),
      ).to.be.reverted
    })

    it("Only governance can rescue tokens", async function () {
      let amount = 42690
      await token.transfer(router.address, amount)

      await expect(router.connect(dude).recoverERC20(token.address)).to.be
        .reverted

      await expect(() =>
        router.recoverERC20(token.address),
      ).to.changeTokenBalances(token, [owner, router], [amount, -amount])

      await router.renounceRole(GOVERNANCE_ROLE, ownerAddress)
      await router.grantRole(GOVERNANCE_ROLE, dudeAddress)

      await token.transfer(router.address, amount)
      await expect(router.recoverERC20(token.address)).to.be.reverted

      await expect(() =>
        router.connect(dude).recoverERC20(token.address),
      ).to.changeTokenBalances(token, [dude, router], [amount, -amount])
    })

    it("Only governance can rescue GAS", async function () {
      let amount = 42690
      await owner.sendTransaction({
        to: router.address,
        value: amount,
      })

      await expect(router.connect(dude).recoverGAS()).to.be.reverted

      await expect(() => router.recoverGAS()).to.changeEtherBalances(
        [router, owner],
        [-amount, amount],
      )

      await router.renounceRole(GOVERNANCE_ROLE, ownerAddress)
      await router.grantRole(GOVERNANCE_ROLE, dudeAddress)

      await owner.sendTransaction({
        to: router.address,
        value: amount,
      })
      await expect(router.recoverGAS()).to.be.reverted

      await expect(() =>
        router.connect(dude).recoverGAS(),
      ).to.changeEtherBalances([router, dude], [-amount, amount])
    })

    it("Governance / admin can not modify Adapters", async function () {
      await router.renounceRole(GOVERNANCE_ROLE, ownerAddress)
      await router.grantRole(GOVERNANCE_ROLE, dudeAddress)

      let fakeAdapter = await signers[2].getAddress()

      for (let signer of [owner, dude]) {
        await expect(router.connect(signer).addTrustedAdapter(fakeAdapter)).to
          .be.reverted

        await expect(router.connect(signer).removeAdapter(fakeAdapter)).to.be
          .reverted

        await expect(router.connect(signer).setAdapters([fakeAdapter], true)).to
          .be.reverted
      }
    })
  })

  describe("Quoter: Access Checks", function () {
    it("Only owner can add/remove Adapters", async function () {
      let fakeAdapter = await signers[2].getAddress()

      await expect(quoter.connect(dude).addTrustedAdapter(fakeAdapter)).to.be
        .reverted
      await quoter.addTrustedAdapter(fakeAdapter)
      expect(await quoter.trustedAdaptersCount()).to.eq(1)

      await expect(quoter.connect(dude).removeAdapter(fakeAdapter)).to.be
        .reverted
      await quoter.removeAdapter(fakeAdapter)
      expect(await quoter.trustedAdaptersCount()).to.eq(0)

      await quoter.addTrustedAdapter(fakeAdapter)
      expect(await quoter.trustedAdaptersCount()).to.eq(1)

      await expect(quoter.connect(dude).removeAdapterByIndex(0)).to.be.reverted
      await quoter.removeAdapterByIndex(0)
      expect(await quoter.trustedAdaptersCount()).to.eq(0)
    })

    it("Only owner can set Adapters", async function () {
      let fakeAdapters = [
        await signers[2].getAddress(),
        await signers[3].getAddress(),
        await signers[4].getAddress(),
      ]

      await quoter.addTrustedAdapter(fakeAdapters[0])

      await expect(quoter.connect(dude).setAdapters(fakeAdapters)).to.be
        .reverted

      await quoter.setAdapters(fakeAdapters)
      expect(await quoter.trustedAdaptersCount()).to.eq(fakeAdapters.length)
    })

    it("Only owner can add/remove Tokens", async function () {
      let fakeToken = token.address

      await expect(quoter.connect(dude).addTrustedToken(fakeToken)).to.be
        .reverted
      await quoter.addTrustedToken(fakeToken)
      expect(await quoter.trustedTokensCount()).to.eq(1)

      await expect(quoter.connect(dude).removeToken(fakeToken)).to.be.reverted
      await quoter.removeToken(fakeToken)
      expect(await quoter.trustedTokensCount()).to.eq(0)

      await quoter.addTrustedToken(fakeToken)
      expect(await quoter.trustedTokensCount()).to.eq(1)

      await expect(quoter.connect(dude).removeTokenByIndex(0)).to.be.reverted
      await quoter.removeTokenByIndex(0)
      expect(await quoter.trustedTokensCount()).to.eq(0)
    })

    it("Only owner can set Tokens", async function () {
      let fakeTokens = [
        await signers[2].getAddress(),
        await signers[3].getAddress(),
        await signers[4].getAddress(),
      ]

      await quoter.addTrustedToken(fakeTokens[0])

      await expect(quoter.connect(dude).setTokens(fakeTokens)).to.be.reverted

      await quoter.setTokens(fakeTokens)
      expect(await quoter.trustedTokensCount()).to.eq(fakeTokens.length)
    })
  })

  describe("Adapters interaction between Router and Quoter", function () {
    it("Adapters are added/removed from Router after being added/removed from Quoter", async function () {
      let fakeAdapters = [
        await signers[2].getAddress(),
        await signers[3].getAddress(),
        await signers[4].getAddress(),
      ]

      for (let adapter of fakeAdapters) {
        await quoter.addTrustedAdapter(adapter)
        expect(await router.isTrustedAdapter(adapter))
      }

      await quoter.removeAdapter(fakeAdapters[0])
      expect(!(await router.isTrustedAdapter(fakeAdapters[0])))
      // now order of adapters is [fakeAdapter[2], fakeAdapter[1]]

      await quoter.removeAdapterByIndex(0)
      expect(!(await router.isTrustedAdapter(fakeAdapters[2])))

      await quoter.removeAdapter(fakeAdapters[1])
      expect(!(await router.isTrustedAdapter(fakeAdapters[1])))
      expect(await quoter.trustedAdaptersCount()).to.eq(0)
    })

    it("Adapters are correctly added/removed from Router, when Quoter.setAdapters() is called", async function () {
      let fakeAdapters = [
        await signers[2].getAddress(),
        await signers[3].getAddress(),
        await signers[4].getAddress(),
      ]

      let newAdapters = [
        await signers[5].getAddress(),
        await signers[6].getAddress(),
      ]

      let updAdapters = [
        await signers[6].getAddress(),
        await signers[7].getAddress(),
      ]

      for (let adapter of fakeAdapters) {
        await quoter.addTrustedAdapter(adapter)
        expect(await router.isTrustedAdapter(adapter))
      }

      await quoter.setAdapters(newAdapters)
      expect(await quoter.trustedAdaptersCount()).to.eq(newAdapters.length)

      for (let adapter of fakeAdapters) {
        expect(!(await router.isTrustedAdapter(adapter)))
      }
      for (let adapter of newAdapters) {
        expect(await router.isTrustedAdapter(adapter))
      }

      await quoter.setAdapters(updAdapters)
      expect(await quoter.trustedAdaptersCount()).to.eq(updAdapters.length)

      expect(!(await router.isTrustedAdapter(newAdapters[0])))
      expect(await router.isTrustedAdapter(updAdapters[0]))
      expect(await router.isTrustedAdapter(updAdapters[1]))
    })
  })
})
