// import { BigNumber, Signer } from "ethers"
// import {
//     MAX_UINT256,
//     TIME,
//     ZERO_ADDRESS,
//     asyncForEach,
//     getCurrentBlockTimestamp,
//     setNextTimestamp,
//     setTimestamp,
//     forceAdvanceOneBlock,
// } from "./testUtils"

// import { solidity } from "ethereum-waffle"
// import { deployments, ethers } from "hardhat"

// import { ERC20Migrator } from "../build/typechain/ERC20Migrator"
// import { SynapseERC20 } from "../build/typechain/SynapseERC20"

// import chai from "chai"

// chai.use(solidity)

// const { expect } = chai

// describe("ERC20Migrator", async() => {
//     const { get } = deployments
//     let signers: Array<Signer>
//     let erc20Migrator: ERC20Migrator
//     let legacyERC20: SynapseERC20
//     let newERC20: SynapseERC20
//     let owner: Signer
//     let user1: Signer
//     let user2: Signer
//     let ownerAddress: string
//     let user1Address: string
//     let user2Address: string

//     const setupTest = deployments.createFixture(
//         async ({ deployments, ethers }) => {
//             const { get } = deployments;
//             await deployments.fixture()

//             signers = await ethers.getSigners()
//             owner = signers[0]
//             user1 = signers[1]
//             user2 = signers[2]
//             ownerAddress = await owner.getAddress()
//             user1Address = await user1.getAddress()
//             user2Address = await user2.getAddress()

//             const ERC20MigratorContract = await ethers.getContractFactory("ERC20Migrator")
//             const synapseERC20Contract = await ethers.getContractFactory("SynapseERC20")

//             legacyERC20 = (await synapseERC20Contract.deploy())
//             newERC20 = (await synapseERC20Contract.deploy())
//             erc20Migrator = (await ERC20MigratorContract.deploy((await legacyERC20.address), (await newERC20.address)))

//             await legacyERC20.initialize(
//                 "Nerve",
//                 "NRV",
//                 18,
//                 await owner.getAddress()
//             )

//             await newERC20.initialize(
//                 "Synapse",
//                 "SYN",
//                 18,
//                 await owner.getAddress()
//             )

//             // Set approvals
//             await asyncForEach([owner, user1, user2], async (signer) => {
//                 await legacyERC20.connect(signer).approve(erc20Migrator.address, MAX_UINT256)
//                 await legacyERC20.connect(owner).grantRole(await legacyERC20.MINTER_ROLE(), ownerAddress);
//                 await legacyERC20.connect(owner).mint(await signer.getAddress(), BigNumber.from(10).pow(18).mul(100000))
//             })
//         })

//         beforeEach(async function() {
//             await setupTest()
//         })

//         describe("Migrator", () => {

//             it("Mints correct amount of new token", async() => {
//                 await newERC20.connect(owner).grantRole(await newERC20.MINTER_ROLE(), await erc20Migrator.address);
//                 let preMint = await newERC20.balanceOf(user1Address)
//                 await erc20Migrator.connect(user1).migrate(String(1e18))
//                 await expect((await newERC20.balanceOf(user1Address)).sub(preMint)).to.be.eq(String(25e17))
//             });

//             it("Mints correct amount of tokens", async() => {
//                 await newERC20.connect(owner).grantRole(await newERC20.MINTER_ROLE(), await erc20Migrator.address);
//                 let preMint = await newERC20.balanceOf(user1Address)
//                 await erc20Migrator.connect(user1).migrate(String(1000))
//                 await expect((await newERC20.balanceOf(user1Address)).sub(preMint)).to.be.eq(String(2500))
//             });

//              it("Migrator can't mint tokens without minter role", async() => {
//                 await expect(erc20Migrator.connect(user1).migrate(String(1e18))).to.be.reverted
//             });
//         });
//     })
