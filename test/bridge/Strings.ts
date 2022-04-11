import chai from "chai"
import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"
import { faker } from "@faker-js/faker"
import { StringsMock } from "../../build/typechain"
import { keccak256 } from "ethers/lib/utils"
import { randomBytes } from "crypto"

chai.use(solidity)
const { expect } = chai

// deterministic tests
faker.seed(123)

describe("Strings Test", () => {
  let stringsMock: StringsMock

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture()

      const stringsMockFactory = await ethers.getContractFactory("StringsMock")
      stringsMock = (await stringsMockFactory.deploy()) as StringsMock
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe("append tests", () => {
    it("should append a + b", async () => {
      const a = faker.lorem.paragraph(1)
      const b = faker.lorem.paragraph(2)

      expect(await stringsMock["append(string,string)"](a, b)).to.be.eq(a + b)
    })

    it("should append a + b + c", async () => {
      const a = faker.lorem.paragraph(1)
      const b = faker.lorem.paragraph(2)
      const c = faker.lorem.paragraph(2)

      expect(
        await stringsMock["append(string,string,string)"](a, b, c),
      ).to.be.eq(a + b + c)
    })

    it("should append a + b + c", async () => {
      const a = faker.lorem.paragraph(1)
      const b = faker.lorem.paragraph(2)
      const c = faker.lorem.paragraph(2)
      const d = faker.lorem.paragraph(2)

      expect(
        await stringsMock["append(string,string,string,string)"](a, b, c, d),
      ).to.be.eq(a + b + c + d)
    })
  })

  describe("conversion tests", () => {
    it("should convert bytes32 to string", async () => {
      const bytes32 = keccak256(randomBytes(32))
      expect(await stringsMock.toHex(bytes32)).to.be.eq(bytes32)
    })
  })
})
