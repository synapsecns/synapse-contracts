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
} from "./testUtils"

import { solidity } from "ethereum-waffle"
import { deployments, ethers } from "hardhat"

import { SynapseBridge } from "../build/typechain/SynapseBridge"
import { SynapseERC20 } from "../build/typechain/SynapseERC20"

import chai from "chai"

chai.use(solidity)
const { expect } = chai

describe("SynapseBridge", async () => {
    const { get } = deployments
    let signers: Array<Signer>
    let synapseBridge: SynapseBridge
    let syntestERC20: SynapseERC20
    let testERC20: SynapseERC20
    let owner: Signer
    let user1: Signer
    let user2: Signer
    let nodeGroup: Signer
    let ownerAddress: string
    let user1Address: string
    let user2Address: string
    let nodeGroupAddress: string


    const setupTest = deployments.createFixture(
        async ({ deployments, ethers }) => {
            const { get } = deployments
            await deployments.fixture() // ensure you start from a fresh deployments

            signers = await ethers.getSigners()
            owner = signers[0]
            user1 = signers[1]
            user2 = signers[2]
            nodeGroup = signers[3]
            ownerAddress = await owner.getAddress()
            user1Address = await user1.getAddress()
            user2Address = await user2.getAddress()
            nodeGroupAddress = await nodeGroup.getAddress()
            const SynapseBridgeContract = await ethers.getContractFactory("SynapseBridge")
            const synapseERC20Contract = await ethers.getContractFactory("SynapseERC20")

            synapseBridge = await SynapseBridgeContract.deploy()
            syntestERC20 = (await synapseERC20Contract.deploy())
            testERC20 = (await synapseERC20Contract.deploy())


            await synapseBridge.initialize()
            await syntestERC20.initialize(
                "Synapse Test Token",
                "SYNTEST",
                18,
                "1",
                "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                await owner.getAddress()
            )

            await testERC20.initialize(
                "Test Token",
                "Test",
                18,
                "1",
                "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                await owner.getAddress()
            )

            // Set approvals
            await asyncForEach([owner, user1, user2], async (signer) => {
                await syntestERC20.connect(signer).approve(synapseBridge.address, MAX_UINT256)
                await testERC20.connect(signer).approve(synapseBridge.address, MAX_UINT256)
                await testERC20.connect(signer).approve(synapseBridge.address, MAX_UINT256)
                await syntestERC20.connect(owner).grantRole(await syntestERC20.MINTER_ROLE(), await owner.getAddress());
                await syntestERC20.connect(owner).grantRole(await syntestERC20.MINTER_ROLE(), await synapseBridge.address);
                await synapseBridge.connect(owner).grantRole(await synapseBridge.NODEGROUP_ROLE(), nodeGroupAddress);
                await testERC20.connect(owner).grantRole(await testERC20.MINTER_ROLE(), await owner.getAddress());
                await syntestERC20.connect(owner).mint(await signer.getAddress(), BigNumber.from(10).pow(18).mul(100000))
                await testERC20.connect(owner).mint(await signer.getAddress(), BigNumber.from(10).pow(18).mul(100000))
            })

        })

    beforeEach(async () => {
        await setupTest()
    })

    describe("Bridge", () => {
        describe("ERC20", () => {
            it("Deposit - return correct balance in bridge contract", async () => {
                await synapseBridge.deposit(user1Address, 56, testERC20.address, String(1e18))
                await expect(await testERC20.balanceOf(synapseBridge.address)).to.be.eq(String(1e18))
            })

            it("Withdraw - correct balance to user and keep correct fee", async () => {
                //user deposits 1 token 
                await synapseBridge.deposit(user1Address, 56, testERC20.address, String(1e18))
                let preWithdraw = await testERC20.balanceOf(user1Address)

                // later, redeems it on a different chain. Node group withdraws w/ a selected fee
                await synapseBridge.connect(nodeGroup).withdraw(user1Address, testERC20.address, String(9e17), String(1e17))
                await expect((await testERC20.balanceOf(user1Address)).sub(preWithdraw)).to.be.eq(String(9e17))
                await expect(await testERC20.balanceOf(synapseBridge.address)).to.be.eq(String(1e17))
                await expect(await synapseBridge.getFeeBalance(testERC20.address)).to.be.eq(String(1e17))

            })

            it("Mint - correct balance to user and keep correct fee", async () => {
                // nodegroup mints after receiving TokenDeposit Event
                let preMint = await syntestERC20.balanceOf(user1Address)

                await synapseBridge.connect(nodeGroup).mint(user1Address, syntestERC20.address, String(9e17), String(1e17))

                // checks for mint and fee amounts

                await expect((await syntestERC20.balanceOf(user1Address)).sub(preMint)).to.be.eq(String(9e17))
                await expect(await syntestERC20.balanceOf(synapseBridge.address)).to.be.eq(String(1e17))
                await expect(await synapseBridge.getFeeBalance(syntestERC20.address)).to.be.eq(String(1e17))

            })


            it("Redeem - correct balance to user and keep correct fee", async () => {
                // user decides to redeem back to base chainId
                let preRedeem = await syntestERC20.balanceOf(user1Address)

                await synapseBridge.redeem(user1Address, 1, syntestERC20.address, String(9e17))
                await expect((await syntestERC20.balanceOf(user1Address)).sub(preRedeem)).to.be.eq(String(0))
            })

            it("Withdraw fees", async () => {
                let preWithdrawFees = await syntestERC20.balanceOf(ownerAddress)
                let synTestFees = await synapseBridge.getFeeBalance(syntestERC20.address)
                await synapseBridge.withdrawFees(syntestERC20.address, ownerAddress)
                await expect((await syntestERC20.balanceOf(ownerAddress)).sub(preWithdrawFees)).to.be.eq(synTestFees)
            })
        })

        describe("ETH", () => {
            it("Deposit ETH", async () => {
                await synapseBridge.depositETH(user1Address, 56, String(1e18), {
                    value: String(1e18)
                })
                expect(await ethers.provider.getBalance(synapseBridge.address)).to.be.eq(String(1e18))
            })

            it("Withdraw ETH with correct fees", async () => {
                // someone deposits eth
                await synapseBridge.depositETH(ownerAddress, 56, String(1e18), {
                    value: String(1e18)
                })
                expect(await ethers.provider.getBalance(synapseBridge.address)).to.be.eq(String(1e18))

                // øn a redeem, node group withdraws eth
                let preWithdrawOwner = await ethers.provider.getBalance(ownerAddress)
                expect(await ethers.provider.getBalance(synapseBridge.address)).to.be.eq(String(1e18))
                await synapseBridge.connect(nodeGroup).withdrawETH(ownerAddress, String(9e17), String(1e17))
                expect(await ethers.provider.getBalance(synapseBridge.address)).to.be.eq(String(1e17))
                let postWithdrawOwner = await ethers.provider.getBalance(ownerAddress)
                expect(postWithdrawOwner.sub(preWithdrawOwner)).to.be.eq(String(9e17))
            })

            it("Withdraw ETH fees", async() => {
                // someone deposits eth
                await synapseBridge.depositETH(ownerAddress, 56, String(1e18), {
                    value: String(1e18)
                })
                
                // øn a redeem, node group withdraws eth
                let preWithdrawOwner = await ethers.provider.getBalance(ownerAddress)
                
                await synapseBridge.connect(nodeGroup).withdrawETH(ownerAddress, String(9e17), String(1e17))
                
                let preuser1Address = await ethers.provider.getBalance(user1Address)
                
                await synapseBridge.connect(owner).withdrawETHFees(user1Address)
                expect((await ethers.provider.getBalance(user1Address)).sub(preuser1Address)).to.be.eq(String(1e17))
            });
        })

    })



});