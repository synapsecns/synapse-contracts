import chai from "chai"
import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"
import { BigNumber, BigNumberish, Signer } from "ethers"
import Wallet from "ethereumjs-wallet"

import { BridgeConfigV3 } from "../../build/typechain/BridgeConfigV3"
import { CHAIN_ID } from "../../utils/network"
import { Address } from "hardhat-deploy/dist/types"
import { faker } from "@faker-js/faker"
import { includes } from "lodash"

chai.use(solidity)
const { expect, assert } = chai

// deterministic tests
faker.seed(123)

describe("Bridge Config V3", () => {
  let signers: Array<Signer>
  let deployer: Signer
  let owner: Signer
  let attacker: Signer
  let bridgeConfigV3: BridgeConfigV3

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture() // ensure you start from a fresh deployments
      signers = await ethers.getSigners()
      deployer = signers[0]
      owner = signers[1]
      attacker = signers[10]

      const bridgeConfigV3Factory = await ethers.getContractFactory(
        "BridgeConfigV3",
      )
      bridgeConfigV3 = (await bridgeConfigV3Factory.deploy()) as BridgeConfigV3

      const bridgeManagerRole = await bridgeConfigV3.BRIDGEMANAGER_ROLE()
      await bridgeConfigV3
        .connect(deployer)
        .grantRole(bridgeManagerRole, await owner.getAddress())

      // connect the bridge config v3 with the owner. For unauthorized tests, this can be overriden
      bridgeConfigV3 = bridgeConfigV3.connect(owner)
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe("max gas", () => {
    const bscGasPrice = BigNumber.from(10 ** 8)

    it("should set max gas price for multiple chains", async () => {
      const mainnetGasPrice = BigNumber.from(10 ** 9)

      await expect(bridgeConfigV3.setMaxGasPrice(CHAIN_ID.BSC, bscGasPrice)).to
        .be.not.reverted

      await expect(
        bridgeConfigV3.setMaxGasPrice(CHAIN_ID.MAINNET, mainnetGasPrice),
      ).to.be.not.reverted

      expect(await bridgeConfigV3.getMaxGasPrice(CHAIN_ID.BSC)).to.be.eq(
        bscGasPrice,
      )
      expect(await bridgeConfigV3.getMaxGasPrice(CHAIN_ID.MAINNET)).to.be.eq(
        mainnetGasPrice,
      )
    })

    it("reverts when called by non-bridge managers", function () {
      expect(
        bridgeConfigV3
          .connect(attacker)
          .setMaxGasPrice(CHAIN_ID.BSC, bscGasPrice),
      ).to.be.reverted
    })
  })

  describe("token config", () => {
    interface TokenConfigTest {
      tokenID: string
      chainID: BigNumber
      tokenAddress: string
      tokenDecimals: BigNumberish
      maxSwap: BigNumberish
      minSwap: BigNumberish
      swapFee: BigNumberish
      maxSwapFee: BigNumberish
      minSwapFee: BigNumberish
      hasUnderlying: boolean
      isUnderlying: boolean
      evmAddress: boolean
    }

    // use string here because CHAIN_IDS was a chainid
    function getTokenConfigTest(
      chainID: string,
      evmAddress: boolean,
    ): TokenConfigTest {
      const maxSwapFee = faker.datatype.number({
        min: 10000,
        max: 10000000,
      })

      let tokenAddress = Wallet.generate().getAddressString()

      if (!evmAddress) {
        tokenAddress = faker.finance.currencySymbol().toLowerCase()
      }

      return {
        tokenID: faker.name.firstName(),
        chainID: BigNumber.from(chainID),
        tokenAddress,
        tokenDecimals: BigNumber.from(
          faker.datatype.number({
            min: 6,
            max: 20,
          }),
        ),
        // these are included for historical reasons
        maxSwap: ethers.constants.MaxUint256,
        minSwap: ethers.constants.One,
        maxSwapFee: BigNumber.from(maxSwapFee),
        minSwapFee: BigNumber.from(
          faker.datatype.number({
            min: 100,
            max: maxSwapFee,
          }),
        ),
        hasUnderlying: faker.datatype.boolean(),
        isUnderlying: faker.datatype.boolean(),
        swapFee: BigNumber.from(
          faker.datatype.number({
            min: 100,
            max: 1000,
          }),
        ),
        evmAddress,
      }
    }

    // getTokenConfigTests sets a number of token configs we can test against
    function getTokenConfigTests(): Array<TokenConfigTest> {
      return [
        getTokenConfigTest(CHAIN_ID.BSC, true),
        getTokenConfigTest(CHAIN_ID.AVALANCHE, true),
        getTokenConfigTest(CHAIN_ID.MAINNET, true),
        getTokenConfigTest(CHAIN_ID.BOBA, true),
        getTokenConfigTest(CHAIN_ID.CRONOS, true),
        getTokenConfigTest("99999999", false),
      ]
    }

    // compareResultToTest compares the result of a token config fetch to the test interface using chai
    function compareResultToTest(
      result: [
        BigNumber,
        string,
        number,
        BigNumber,
        BigNumber,
        BigNumber,
        BigNumber,
        BigNumber,
        boolean,
        boolean,
      ] & {
        chainId: BigNumber
        tokenAddress: string
        tokenDecimals: number
        maxSwap: BigNumber
        minSwap: BigNumber
        swapFee: BigNumber
        maxSwapFee: BigNumber
        minSwapFee: BigNumber
        hasUnderlying: boolean
        isUnderlying: boolean
      },
      test: TokenConfigTest,
    ) {
      expect(result.chainId).to.be.eq(test.chainID)
      expect(result.tokenAddress).to.be.eq(test.tokenAddress.toLowerCase())
      expect(result.tokenDecimals).to.be.eq(test.tokenDecimals)
      expect(result.maxSwap).to.be.eq(test.maxSwap)
      expect(result.minSwap).to.be.eq(test.minSwap)
      expect(result.swapFee).to.be.eq(test.swapFee)
      expect(result.maxSwapFee).to.be.eq(test.maxSwapFee)
      expect(result.minSwapFee).to.be.eq(test.minSwapFee)
      expect(result.hasUnderlying).to.be.eq(test.hasUnderlying)
      expect(result.isUnderlying).to.be.eq(test.isUnderlying)
    }

    // verifyTokenConfig verifies a token config against the contract
    async function veriyTokenConfig(config: TokenConfigTest) {
      // make sure all get token methods return the token correctly
      let tokenConfig = await bridgeConfigV3.getToken(
        config.tokenID,
        config.chainID,
      )
      compareResultToTest(tokenConfig, config)

      let tokenConfigByID = await bridgeConfigV3.getTokenByID(
        config.tokenID,
        config.chainID,
      )
      compareResultToTest(tokenConfigByID, config)

      let tokenConfigByAddress = await bridgeConfigV3.getTokenByAddress(
        config.tokenAddress,
        config.chainID,
      )
      compareResultToTest(tokenConfigByAddress, config)

      let tokenID = await bridgeConfigV3["getTokenID(string,uint256)"](
        config.tokenAddress,
        config.chainID,
      )
      expect(tokenID).to.be.eq(config.tokenID)

      // test the has underlying
      if (config.hasUnderlying) {
        const hasUnderlying = await bridgeConfigV3.hasUnderlyingToken(
          config.tokenID,
        )
        expect(hasUnderlying).to.be.eq(config.hasUnderlying)
      }

      // make sure token id is in get all token ids
      const allTokenIds = await bridgeConfigV3.getAllTokenIDs()
      expect(includes(allTokenIds, config.tokenID)).to.be.true

      // make sure the token id still exists
      expect(await bridgeConfigV3.isTokenIDExist(config.tokenID)).to.be.true

      if (config.evmAddress) {
        let tokenConfigByEvmAddress = await bridgeConfigV3.getTokenByEVMAddress(
          config.tokenAddress,
          config.chainID,
        )
        compareResultToTest(tokenConfigByEvmAddress, config)

        let tokenIDByEvmAddress = await bridgeConfigV3[
          "getTokenID(address,uint256)"
        ](config.tokenAddress, config.chainID)
        expect(tokenIDByEvmAddress).to.be.eq(config.tokenID)
      }
    }

    // this method merely tests set/get token config. We may set isUnderlying/hasUnderlying in places where it doesn't exist
    // so we can't test getUnderlyingToken here
    it("should set token configs correctly", async function () {
      for (let i = 0; i < 3; i++) {
        const tokenConfigs = getTokenConfigTests()

        await Promise.all(
          tokenConfigs.map(
            (config) =>
              expect(
                bridgeConfigV3[
                  "setTokenConfig(string,uint256,string,uint8,uint256,uint256,uint256,uint256,uint256,bool,bool)"
                ](
                  config.tokenID,
                  config.chainID,
                  config.tokenAddress,
                  config.tokenDecimals,
                  config.maxSwap,
                  config.minSwap,
                  config.swapFee,
                  config.maxSwapFee,
                  config.minSwapFee,
                  config.hasUnderlying,
                  config.isUnderlying,
                ),
              ).to.be.not.reverted,
          ),
        )

        // on the second pass, we use set by evm address where possible to test the method
        if (i == 2) {
          await Promise.all(
            tokenConfigs
              .filter((config) => config.evmAddress)
              .map(
                (config) =>
                  expect(
                    bridgeConfigV3[
                      "setTokenConfig(string,uint256,address,uint8,uint256,uint256,uint256,uint256,uint256,bool,bool)"
                    ](
                      config.tokenID,
                      config.chainID,
                      config.tokenAddress,
                      config.tokenDecimals,
                      config.maxSwap,
                      config.minSwap,
                      config.swapFee,
                      config.maxSwapFee,
                      config.minSwapFee,
                      config.hasUnderlying,
                      config.isUnderlying,
                    ),
                  ).to.be.not.reverted,
              ),
          )
        }

        for (let config of tokenConfigs) {
          await veriyTokenConfig(config)
        }
      }
    })

    it("should revert on non-bridge manager setting token config", async function () {
      const config = getTokenConfigTests()[0]

      expect(
        bridgeConfigV3
          .connect(attacker)
          [
            "setTokenConfig(string,uint256,address,uint8,uint256,uint256,uint256,uint256,uint256,bool,bool)"
          ](
            config.tokenID,
            config.chainID,
            config.tokenAddress,
            config.tokenDecimals,
            config.maxSwap,
            config.minSwap,
            config.swapFee,
            config.maxSwapFee,
            config.minSwapFee,
            config.hasUnderlying,
            config.isUnderlying,
          ),
      ).to.be.reverted

      expect(
        bridgeConfigV3
          .connect(attacker)
          [
            "setTokenConfig(string,uint256,string,uint8,uint256,uint256,uint256,uint256,uint256,bool,bool)"
          ](
            config.tokenID,
            config.chainID,
            config.tokenAddress,
            config.tokenDecimals,
            config.maxSwap,
            config.minSwap,
            config.swapFee,
            config.maxSwapFee,
            config.minSwapFee,
            config.hasUnderlying,
            config.isUnderlying,
          ),
      ).to.be.reverted
    })

    it("should correctly calculate swap fees", async function () {
      const testToken = getTokenConfigTest(CHAIN_ID.BSC, true)
      testToken.swapFee = BigNumber.from(8000000)
      testToken.minSwapFee = BigNumber.from("1000000000000000000")
      testToken.maxSwapFee = BigNumber.from("10000000000000000000")

      await expect(
        bridgeConfigV3[
          "setTokenConfig(string,uint256,string,uint8,uint256,uint256,uint256,uint256,uint256,bool,bool)"
        ](
          testToken.tokenID,
          testToken.chainID,
          testToken.tokenAddress,
          testToken.tokenDecimals,
          testToken.maxSwap,
          testToken.minSwap,
          testToken.swapFee,
          testToken.maxSwapFee,
          testToken.minSwapFee,
          testToken.hasUnderlying,
          testToken.isUnderlying,
        ),
      ).to.be.not.reverted

      const minFee = await bridgeConfigV3[
        "calculateSwapFee(string,uint256,uint256)"
      ](testToken.tokenAddress, testToken.chainID, BigNumber.from(4))
      expect(minFee).to.eq(testToken.minSwapFee)

      const testFee = await bridgeConfigV3[
        "calculateSwapFee(address,uint256,uint256)"
      ](
        testToken.tokenAddress,
        testToken.chainID,
        BigNumber.from("9000000000000000000000"),
      )
      expect(testFee).to.eq(BigNumber.from("7200000000000000000"))

      const maxFee = await bridgeConfigV3[
        "calculateSwapFee(string,uint256,uint256)"
      ](
        testToken.tokenAddress,
        testToken.chainID,
        BigNumber.from("100000000000000000000000000000"),
      )
      expect(maxFee).to.be.eq(testToken.maxSwapFee)
    })

    it("should get underlying token config", async function () {
      // create the underlying token
      const testUnderlying = getTokenConfigTest(CHAIN_ID.BSC, true)
      testUnderlying.isUnderlying = true
      testUnderlying.hasUnderlying = true

      // create the has underlying token
      const testHasUnderlying = Object.assign({}, testUnderlying)
      testHasUnderlying.isUnderlying = false
      testUnderlying.chainID = BigNumber.from(CHAIN_ID.MAINNET)

      // set the token
      const tokenConfigs: Array<TokenConfigTest> = [
        testUnderlying,
        testHasUnderlying,
      ]
      await Promise.all(
        tokenConfigs.map(
          (config) =>
            expect(
              bridgeConfigV3[
                "setTokenConfig(string,uint256,string,uint8,uint256,uint256,uint256,uint256,uint256,bool,bool)"
              ](
                config.tokenID,
                config.chainID,
                config.tokenAddress,
                config.tokenDecimals,
                config.maxSwap,
                config.minSwap,
                config.swapFee,
                config.maxSwapFee,
                config.minSwapFee,
                config.hasUnderlying,
                config.isUnderlying,
              ),
            ).to.be.not.reverted,
        ),
      )

      const testToken = await bridgeConfigV3.getUnderlyingToken(
        testHasUnderlying.tokenID,
      )
      compareResultToTest(testToken, testUnderlying)
    })
  })

  describe("pool config", () => {
    interface PoolConfigTest {
      tokenAddress: string
      chainID: BigNumber
      poolAddress: Address
      metaSwap: boolean
    }

    function getPoolConfigTests(): Array<PoolConfigTest> {
      return [
        {
          tokenAddress: Wallet.generate().getChecksumAddressString(),
          chainID: BigNumber.from(CHAIN_ID.HARDHAT),
          poolAddress: Wallet.generate().getChecksumAddressString(),
          metaSwap: false,
        },
        {
          tokenAddress: Wallet.generate().getChecksumAddressString(),
          chainID: BigNumber.from(CHAIN_ID.BSC),
          poolAddress: Wallet.generate().getChecksumAddressString(),
          metaSwap: true,
        },
        {
          tokenAddress: Wallet.generate().getChecksumAddressString(),
          chainID: BigNumber.from(CHAIN_ID.MAINNET),
          poolAddress: Wallet.generate().getChecksumAddressString(),
          metaSwap: true,
        },
      ]
    }

    it("should set pool config", async () => {
      // three pool configs, different chain ids to make sure they don't override eachother. Write/check twice
      for (let i = 0; i < 2; i++) {
        const poolConfigs = getPoolConfigTests()

        // set all configs
        await Promise.all(
          poolConfigs.map(
            (config) =>
              expect(
                bridgeConfigV3.setPoolConfig(
                  config.tokenAddress,
                  config.chainID,
                  config.poolAddress,
                  config.metaSwap,
                ),
              ).to.be.not.reverted,
          ),
        )
        // check all configs
        for (let config of poolConfigs) {
          let poolConfig = await bridgeConfigV3.getPoolConfig(
            config.tokenAddress,
            config.chainID,
          )
          expect(poolConfig.tokenAddress).to.be.eq(config.tokenAddress)
          expect(poolConfig.poolAddress).to.be.eq(config.poolAddress)
          expect(poolConfig.chainId).to.be.eq(config.chainID)
        }
      }
    })

    it("reverts when called by non-bridge managers", function () {
      const config = getPoolConfigTests()[0]

      expect(
        bridgeConfigV3
          .connect(attacker)
          .setPoolConfig(
            config.tokenAddress,
            config.chainID,
            config.poolAddress,
            config.metaSwap,
          ),
      ).to.be.reverted
    })
  })
})
