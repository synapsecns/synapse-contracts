// import { BigNumber, Signer } from 'ethers'

// import { solidity } from 'ethereum-waffle'
// import { deployments, ethers } from 'hardhat'

// import { SynapseERC20 } from '../build/typechain/SynapseERC20'
// import { SynapseERC20Factory } from '../build/typechain/SynapseERC20Factory'
// import chai from 'chai'

// chai.use(solidity)
// const { expect } = chai

// describe('SynapseERC20Factory', async function() {
//   const { get } = deployments
//   let signers: Array<Signer>
//   let synapseERC20Factory: SynapseERC20Factory
//   let synapseERC20: SynapseERC20
//   let owner: Signer
//   let user1: Signer
//   let user2: Signer
//   let ownerAddress: string
//   let user1Address: string
//   let user2Address: string

//   const setupTest = deployments.createFixture(
//     async ({ deployments, ethers }) => {
//       const { get } = deployments
//       await deployments.fixture() // ensure you start from a fresh deployments

//       signers = await ethers.getSigners()
//       owner = signers[0]
//       user1 = signers[1]
//       user2 = signers[2]
//       ownerAddress = await owner.getAddress()
//       user1Address = await user1.getAddress()
//       user2Address = await user2.getAddress()

//       const synapseERC20FactoryContract = await ethers.getContractFactory(
//         'SynapseERC20Factory'
//       )
//       const synapseERC20Contract = await ethers.getContractFactory(
//         'SynapseERC20'
//       )

//       synapseERC20Factory = await synapseERC20FactoryContract.deploy()
//       synapseERC20 = await synapseERC20Contract.deploy()

//       await synapseERC20.initialize(
//         'Synapse Test Token',
//         'SYNTEST',
//         18,
//         '1',
//         '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
//         await owner.getAddress()
//       )
//     }
//   )

//   beforeEach(async function() {
//     await setupTest()
//   })

//   describe('SynToken', () => {
//     it('Token info', async function() {
//       expect(await synapseERC20.name()).to.be.eq('Synapse Test Token')
//       expect(await synapseERC20.symbol()).to.be.eq('SYNTEST')
//       expect(await synapseERC20.decimals()).to.be.eq(18)
//     })

//     it('Initialize once', async function() {
//       await expect(
//         synapseERC20.initialize(
//           'Synapse Test Token',
//           'SYNTEST',
//           18,
//           await owner.getAddress()
//         )
//       ).to.be.reverted
//     })

//     describe('Mint', () => {
//       it('mint', async function() {
//         await synapseERC20
//           .connect(owner)
//           .grantRole(await synapseERC20.MINTER_ROLE(), await owner.getAddress())
//         await synapseERC20.connect(owner).mint(await user1.getAddress(), '1000')
//         expect(
//           await synapseERC20.connect(owner).balanceOf(user1Address)
//         ).to.be.eq('1000')
//       })

//       it('Mint not allowed without role', async function() {
//         // await synapseERC20.connect(owner).grantRole(await synapseERC20.MINTER_ROLE(), await owner.getAddress());
//         await expect(
//           synapseERC20.connect(owner).mint(await user1.getAddress(), '1000')
//         ).to.be.reverted
//       })
//     })
//   })
// })
