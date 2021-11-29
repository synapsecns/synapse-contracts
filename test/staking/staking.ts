import { BigNumber, Signer } from "ethers"
import {
    MAX_UINT256,
    TIME,
    ZERO_ADDRESS,
    asyncForEach,
    getCurrentBlockTimestamp,
    setNextTimestamp,
    setTimestamp,
    forceAdvanceOneBlock,
    increaseTimestamp,
} from "../bridge/testUtils"

import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"

import { StakedSYN } from "../../build/typechain/StakedSYN"
import { StakingMinter } from "../../build/typechain/StakingMinter"
import { SynapseERC20 } from "../../build/typechain/SynapseERC20"

import chai from "chai"

chai.use(solidity)
const { expect } = chai

describe("StakedSYN", async () => {
    const { get } = deployments
    let signers: Array<Signer>
    let stakedSYN: StakedSYN
    let SYN: SynapseERC20
    let stakingMinter: StakingMinter
    let testERC20: SynapseERC20
    let owner: Signer
    let user1: Signer
    let user2: Signer
    let user3: Signer
    let ownerAddress: string
    let user1Address: string
    let user2Address: string
    let user3Address: string


    const setupTest = deployments.createFixture(
        async ({ deployments, ethers }) => {
            const { get } = deployments
            // await deployments.fixture() // ensure you start from a fresh deployments

            signers = await ethers.getSigners()
            owner = signers[0]
            user1 = signers[1]
            user2 = signers[2]
            user3 = signers[3]
            ownerAddress = await owner.getAddress()
            user1Address = await user1.getAddress()
            user2Address = await user2.getAddress()
            user3Address = await user3.getAddress()
            const synapseERC20Contract = await ethers.getContractFactory("SynapseERC20")
            const stakedSYNContract = await ethers.getContractFactory("StakedSYN")
            const stakingMinterContract = await ethers.getContractFactory("StakingMinter")

            SYN = (await synapseERC20Contract.deploy()) as SynapseERC20
            stakedSYN = await stakedSYNContract.deploy(SYN.address, await getCurrentBlockTimestamp()) as StakedSYN
            stakingMinter = await stakingMinterContract.deploy(SYN.address, stakedSYN.address) as StakingMinter

            await SYN.initialize(
                "Synapse",
                "SYN",
                18,
                await owner.getAddress()
            )

            await stakedSYN.connect(owner).setStakingMinter(stakingMinter.address);

            // Set approvals
            await asyncForEach([owner, user1, user2, user3], async (signer) => {
                await SYN.connect(signer).approve(stakedSYN.address, MAX_UINT256)
                // await testERC20.connect(signer).approve(synapseBridge.address, MAX_UINT256)
                // await testERC20.connect(signer).approve(synapseBridge.address, MAX_UINT256)
                await SYN.connect(owner).grantRole(await SYN.MINTER_ROLE(), await owner.getAddress());
                await SYN.connect(owner).grantRole(await SYN.MINTER_ROLE(), stakingMinter.address);
                await SYN.connect(owner).mint(await signer.getAddress(), BigNumber.from(10).pow(18).mul(100000))
                await stakedSYN.connect(signer).stake(BigNumber.from(10).pow(18).mul(100))
                
                // await SYN.connect(owner).mint(await owner.getAddress(), BigNumber.from(10).pow(18).mul(100000))
            })

        })

    beforeEach(async () => {
        await setupTest()
    })

    describe('Stake', () => {
        it("SYN -> sSYN", async() => {
            await asyncForEach([owner, user1, user2], async (signer) => {
                expect((await stakedSYN.balanceOf((await signer.getAddress())))).to.eq(BigNumber.from(10).pow(18).mul(100))
            })
        })
    })

    describe('Undelegate without incoming SYN', () => {
        it("sSYN Undelegation State Changes", async() => {
            await stakedSYN.connect(owner).undelegate(BigNumber.from(10).pow(18).mul(100))
            let currentBlockTimestamp = await getCurrentBlockTimestamp()
            expect((await stakedSYN.balanceOf(ownerAddress))).to.eq(0)
            expect((await stakedSYN.undelegatedSynapse(ownerAddress))[0]).to.eq(BigNumber.from(10).pow(18).mul(100))
            expect((await stakedSYN.undelegatedSynapse(ownerAddress))[1]).to.eq(BigNumber.from(currentBlockTimestamp + 604800))
        })

        it("sSYN Undelegation State Changes Reset by 2nd undelegation", async() => {
            await stakedSYN.connect(owner).undelegate(BigNumber.from(10).pow(18).mul(50))
            let originalBlockTimestamp = await getCurrentBlockTimestamp()
            await increaseTimestamp(302400)
            expect((await stakedSYN.balanceOf(ownerAddress))).to.eq(BigNumber.from(10).pow(18).mul(50))
            expect((await stakedSYN.undelegatedSynapse(ownerAddress))[0]).to.eq(BigNumber.from(10).pow(18).mul(50))
            expect((await stakedSYN.undelegatedSynapse(ownerAddress))[1]).to.eq(BigNumber.from(originalBlockTimestamp + 604800))
            await stakedSYN.connect(owner).undelegate(BigNumber.from(10).pow(18).mul(50))
            let secondBlockTimestamp = await getCurrentBlockTimestamp()
            expect((await stakedSYN.undelegatedSynapse(ownerAddress))[0]).to.eq(BigNumber.from(10).pow(18).mul(100))
            expect((await stakedSYN.undelegatedSynapse(ownerAddress))[1]).to.eq(BigNumber.from(secondBlockTimestamp + 604800))
        })

        it('sSYN Redeem Full Amount', async() => {
            await stakedSYN.connect(owner).undelegate(BigNumber.from(10).pow(18).mul(100))
            let currentBlockTimestamp = await getCurrentBlockTimestamp()
            await increaseTimestamp(604800)
            await stakedSYN.connect(owner).unstake()
            await expect((await SYN.balanceOf(ownerAddress))).to.eq(BigNumber.from(10).pow(18).mul(100000))
        })

        it('sSYN Redeem Partial Amount', async() => {
            await stakedSYN.connect(owner).undelegate(BigNumber.from(10).pow(18).mul(50))
            await increaseTimestamp(604800)
            await stakedSYN.connect(owner).unstake()
            await expect((await SYN.balanceOf(ownerAddress))).to.eq(BigNumber.from(10).pow(18).mul(99950))
            await expect((await stakedSYN.balanceOf(ownerAddress))).to.eq(BigNumber.from(10).pow(18).mul(50))
        })

        it('sSYN Redeem Revert', async() => {
            await stakedSYN.connect(owner).undelegate(BigNumber.from(10).pow(18).mul(100))
            let currentBlockTimestamp = await getCurrentBlockTimestamp()
            await increaseTimestamp(604000)
            await (expect(stakedSYN.connect(owner).unstake())).to.be.revertedWith("Undelegate period not reached")
        })
    })

    describe('Stake with SYN being minted', () => {
        it("SYN -> sSYN Full Flow with staking", async() => {
            await stakingMinter.connect(owner).setSynapsePerSecond(BigNumber.from(10).pow(18))
            await asyncForEach([owner, user1, user2], async (signer) => {
                expect((await stakedSYN.balanceOf((await signer.getAddress())))).to.eq(BigNumber.from(10).pow(18).mul(100))
            })
            // wait an hour
            await increaseTimestamp(3600)
            await stakedSYN.distribute()
            await asyncForEach([owner, user1, user2, user3], async (signer) => {
                expect((await stakedSYN.underlyingBalanceOf((await signer.getAddress())))).to.eq("1006500000000000000000")
            })
            await increaseTimestamp(3600)
            await stakedSYN.distribute()
            await asyncForEach([owner, user1, user2, user3], async (signer) => {
                expect((await stakedSYN.underlyingBalanceOf((await signer.getAddress())))).to.eq("1906750000000000000000")
            })
            await increaseTimestamp(3600)
            await stakedSYN.connect(owner).stake(BigNumber.from(10).pow(18).mul(100))
            await asyncForEach([user1, user2, user3], async (signer) => {
                expect((await stakedSYN.underlyingBalanceOf((await signer.getAddress())))).to.eq("2807000000000000000000")
            })
            expect((await stakedSYN.underlyingBalanceOf((await owner.getAddress())))).to.eq("2906999999999999999999")
            await increaseTimestamp(3599)
            await stakedSYN.connect(user3).undelegate(BigNumber.from(10).pow(18).mul(100))
            await asyncForEach([user1, user2, user3], async (signer) => {
                expect((await stakedSYN.underlyingBalanceOf((await signer.getAddress())))).to.eq("3699055084745762711864")
            })
            expect((await stakedSYN.underlyingBalanceOf((await owner.getAddress())))).to.eq("3830834745762711864406")

            await increaseTimestamp(3600)
            await stakedSYN.distribute()
            expect((await stakedSYN.underlyingBalanceOf((await user3.getAddress())))).to.eq("3699055084745762711864")
            await asyncForEach([user1, user2], async (signer) => {
                expect((await stakedSYN.underlyingBalanceOf((await signer.getAddress())))).to.eq("4885301652050069718084")
            })
            expect((await stakedSYN.underlyingBalanceOf((await owner.getAddress())))).to.eq("5059341611154097851966")
            await stakedSYN.connect(owner).stake(BigNumber.from(10).pow(18).mul(4711))

            await increaseTimestamp(3600)
            await stakedSYN.distribute()

            await asyncForEach([user1, user2], async (signer) => {
                expect((await stakedSYN.underlyingBalanceOf((await signer.getAddress())))).to.eq("5785813711574260203257")
            })
            expect((await stakedSYN.underlyingBalanceOf((await owner.getAddress())))).to.eq("11571317492105716881621")

            // user3 can now unstake
            await increaseTimestamp(604800)

            await stakedSYN.connect(user3).unstake()
            await expect((await SYN.balanceOf(user3Address))).to.eq("103599055084745762711864")

        })
    })

});