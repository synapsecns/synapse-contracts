//@ts-nocheck
// import { ADDRESS_ZERO, advanceBlock, advanceBlockTo, advanceTime, advanceTimeAndBlock, deploy, getBigNumber, prepare } from "../util"
import {TestUtils, advanceTime, advanceBlock, advanceTimeAndBlock, advanceBlockTo, deploy, prepare, getBigNumber} from "../util";
import { assert, expect } from "chai"

import { ethers } from "hardhat"

const { BigNumber } = require("ethers")

describe("MiniChefV2", function () {
    before(async function () {
        await prepare(this, ["MiniChefV2", "SynapseERC20", "ERC20Mock", "RewarderMock", "RewarderBrokenMock", "BonusChef"])
        await deploy(this, [["brokenRewarder", this.RewarderBrokenMock]])
    })

    beforeEach(async function () {
        await deploy(this, [
            ["syn", this.ERC20Mock, ["SYN", "SYN", getBigNumber(0)]]
        ])

        await deploy(this, [
            ["lp", this.ERC20Mock, ["LP Token", "LPT", getBigNumber(10)]],
            ["dummy", this.ERC20Mock, ["Dummy", "DummyT", getBigNumber(10)]],
            ["chef", this.MiniChefV2, [this.syn.address]],
            ["rlp", this.ERC20Mock, ["LP", "rLPT", getBigNumber(10)]],
            ["r", this.ERC20Mock, ["Reward", "RewardT", getBigNumber(100000)]],
        ])

        await deploy(this, [["rewarder", this.RewarderMock, [getBigNumber(1), this.r.address, this.chef.address]]])
        await deploy(this, [["bonusChef", this.BonusChef, [this.chef.address, this.alice.address]]])

        await this.syn.mint(this.chef.address, getBigNumber(10000))
        await this.lp.approve(this.chef.address, getBigNumber(10))
        await this.rlp.approve(this.chef.address, getBigNumber(100))
        await this.chef.setSynapsePerSecond("10000000000000000")
        // await this.r.mint(this.bob.address, getBigNumber(10))
        await this.rlp.transfer(this.bob.address, getBigNumber(1))
    })

    describe("BonusChef", function () {
        beforeEach(async function () {
            await this.chef.add(10, this.rlp.address, this.bonusChef.address)
        })

        // it("Unlinked BonusChef", async function () {
        //     let err
        //     try {
        //         await this.bonusChef.totalSupply()
        //     } catch (e) {
        //         err = e
        //     }

        //     assert.equal(err.toString(), "Error: Transaction reverted: function call to a non-contract account")
            
        //     await this.rlp.approve(this.chef.address, getBigNumber(10))
        //     await this.chef.deposit(0, getBigNumber(1), this.alice.address)
        //     await advanceTime(1000)
        //     await this.chef.withdraw(0, getBigNumber(1), this.alice.address)
        //     await this.chef.harvest(0, this.alice.address)
        // })

        // it("Reverts on unauthorised access", async function () {
        //     await this.bonusChef.linkToPool(0)
        //     // Bob should not be able to add new Reward pool, but Alice should
        //     await expect(this.bonusChef.connect(this.bob).addRewardPool(this.r.address, 1000)).to.be.revertedWith("!governance")

        //     await this.bonusChef.addRewardPool(this.r.address, 1000)
        //     await this.r.connect(this.bob).approve(this.bonusChef.address, getBigNumber(10))
        //     await this.r.approve(this.bonusChef.address, getBigNumber(10))

        //     // Bob should not be able to provide rewards, but Alice should
        //     await expect(this.bonusChef.connect(this.bob).notifyRewardAmount(this.r.address, getBigNumber(10))).to.be.revertedWith("!rewardsDistribution")
        //     await this.bonusChef.notifyRewardAmount(this.r.address, getBigNumber(10))

        //     await advanceTime(1000)

        //     // Bob should not be able to inactivate pool, but Alice should
        //     await expect(this.bonusChef.connect(this.bob).inactivateRewardPool(this.r.address)).to.be.revertedWith("!governance")
        //     await this.bonusChef.inactivateRewardPool(this.r.address)

        //     // Bob should not be able to rescue tokens, but Alice should
        //     await expect(this.bonusChef.connect(this.bob).rescue(this.r.address)).to.be.revertedWith("!governance")
        //     await this.bonusChef.rescue(this.r.address)
        // })

        // it("Reverts on incorrectly added pool", async function () {
        //     await expect(this.bonusChef.addRewardPool(this.r.address, 1000)).to.be.revertedWith("BonusChef is not linked to any pool")

        //     await this.bonusChef.linkToPool(0)
        //     await expect(this.bonusChef.addRewardPool(this.r.address, 0)).to.be.revertedWith("Duration is null")

        //     await this.bonusChef.addRewardPool(this.r.address, 1000)
        //     await expect(this.bonusChef.addRewardPool(this.r.address, 1000)).to.be.revertedWith("Pool is active")

        //     await advanceTime(1000)
        //     await this.bonusChef.inactivateRewardPool(this.r.address)
        //     // Once the pool is inactive, you can readd it with different duration value
        //     await this.bonusChef.addRewardPool(this.r.address, 2000)
        // })

        // it("Reverts on incorrect interactions with active pool", async function () {
        //     await this.bonusChef.linkToPool(0)
        //     await this.bonusChef.addRewardPool(this.r.address, 1000)
        //     let rewards = getBigNumber(10)
        //     await this.r.approve(this.bonusChef.address, rewards)
        //     await this.bonusChef.notifyRewardAmount(this.r.address, rewards)

        //     await advanceTime(999)
        //     await expect(this.bonusChef.inactivateRewardPool(this.r.address)).to.be.revertedWith("Pool has not concluded")
        //     await expect(this.bonusChef.rescue(this.r.address)).to.be.revertedWith("Cannot withdraw active reward token")

        //     await advanceTime(1)
        //     await expect(this.bonusChef.rescue(this.r.address)).to.be.revertedWith("Cannot withdraw active reward token")
        //     await expect(this.bonusChef.inactivateRewardPool(this.rlp.address)).to.be.revertedWith("Reward pool not found")
        //     await expect(this.bonusChef.inactivateRewardPoolByIndex(1)).to.be.revertedWith("Pool index out of range")

        //     await this.bonusChef.inactivateRewardPool(this.r.address)
        //     await expect(this.bonusChef.inactivateRewardPool(this.r.address)).to.be.revertedWith("Reward pool not found")

        //     await this.bonusChef.rescue(this.r.address)
        //     // this will rescue 0 tokens, but should not revert
        //     await this.bonusChef.rescue(this.r.address)
        // })

        // it("Rescue tokens from inactive pool", async function () {
        //     // Alice deposits 1 rLP token for Bob
        //     await this.chef.deposit(0, getBigNumber(1), this.bob.address)

        //     await this.bonusChef.linkToPool(0)
        //     await this.bonusChef.addRewardPool(this.r.address, 1000)
        //     let rewards = getBigNumber(10)
        //     await this.r.approve(this.bonusChef.address, rewards)
        //     await this.bonusChef.notifyRewardAmount(this.r.address, rewards)

        //     await advanceTime(100)
        //     let rewardsBob = rewards.div(10)
        //     await expect(() => this.chef.connect(this.bob).harvest(0, this.bob.address))
        //         .to.changeTokenBalances(this.r, [this.bonusChef, this.bob], [rewardsBob.mul(-1), rewardsBob])

        //     await advanceTime(900)
        //     let rewardsRescued = rewards.sub(rewardsBob)
        //     await this.bonusChef.inactivateRewardPool(this.r.address)

        //     // Bob is too late to the party
        //     await expect(() => this.chef.connect(this.bob).harvest(0, this.bob.address))
        //         .to.changeTokenBalances(this.r, [this.bonusChef, this.bob], [0, 0])
            
        //     await expect(() => this.bonusChef.rescue(this.r.address))
        //         .to.changeTokenBalances(this.r, [this.bonusChef, this.alice], [rewardsRescued.mul(-1), rewardsRescued])
        // })

        it("Correct Bonus Token values", async function () {
            let rewardsBob = getBigNumber(0)
            let rewardsCarol = getBigNumber(0)

            let rewards = getBigNumber(100000)
            let rewards_1_2 = rewards.div(2)
            let rewardsRound = rewards.div(10)
            let rewardsRound_1_4 = rewardsRound.div(4)
            let rewardsRound_1_2 = rewardsRound.div(2)
            let rewardsRound_3_4 = rewardsRound_1_4.mul(3)
            let rewardsRound_1_100 = rewardsRound.div(100)

            // Alice deposits 1 rLP token for Bob
            await this.chef.deposit(0, getBigNumber(1), this.bob.address)

            await this.bonusChef.linkToPool(0)
            await this.bonusChef.addRewardPool(this.r.address, 1000)
            
            await this.r.approve(this.bonusChef.address, rewards)
            await this.bonusChef.notifyRewardAmount(this.r.address, rewards)

            expect(await this.r.balanceOf(this.alice.address)).to.equal(0)
            expect(await this.r.balanceOf(this.bob.address)).to.equal(0)
            expect(await this.r.balanceOf(this.carol.address)).to.equal(0)

            console.log(await this.bonusChef.lastTimeRewardApplicable(this.r.address))
            
            
            console.log("1 / 10")
            await advanceTimeAndBlock(99)

            // Alice deposits 3 rLP tokens for Carol -> 1:3 ratio
            await this.chef.deposit(0, getBigNumber(3), this.carol.address)
            console.log(await this.bonusChef.lastTimeRewardApplicable(this.r.address))

            rewardsBob = rewardsBob.add(rewardsRound)

            expect(await this.bonusChef.earned2(this.r.address, this.bob.address)).to.equal(rewardsBob)
            expect(await this.bonusChef.earned2(this.r.address, this.carol.address)).to.equal(rewardsCarol)
            

            console.log("2 / 10")
            await advanceTimeAndBlock(99)
            // Bob withdraws
            console.log("Bob:" + (await this.r.balanceOf(this.bob.address)))
            await this.chef.connect(this.bob).withdraw(0, getBigNumber(1), this.bob.address)
            console.log("Bob:" + (await this.r.balanceOf(this.bob.address)))
            console.log(await this.bonusChef.lastTimeRewardApplicable(this.r.address))

            rewardsBob = rewardsBob.add(rewardsRound_1_4)
            rewardsCarol = rewardsCarol.add(rewardsRound_3_4)
            
            expect(await this.bonusChef.earned2(this.r.address, this.bob.address)).to.equal(0)
            expect(await this.bonusChef.earned2(this.r.address, this.carol.address)).to.equal(rewardsCarol)
            // expect(await this.bonusChef.rewards(this.r.address, this.bob.address)).to.equal(rewardsBob)


            console.log("3 / 10")
            await advanceTimeAndBlock(99)
            // Alice deposits 3 rLP tokens for Bob -> 3:3 ratio
            await this.chef.deposit(0, getBigNumber(3), this.bob.address)
            console.log(await this.bonusChef.lastTimeRewardApplicable(this.r.address))

            rewardsCarol = rewardsCarol.add(rewardsRound)
            expect(await this.bonusChef.earned2(this.r.address, this.bob.address)).to.equal(0)
            // expect(await this.bonusChef.earned(this.r.address, this.carol.address)).to.equal(rewardsCarol)
            // expect(await this.bonusChef.rewards(this.r.address, this.bob.address)).to.equal(rewardsBob)

            console.log("4 / 10")
            await advanceTimeAndBlock(99)
            // Carol withdraws, making the ratio 3:1
            await this.chef.connect(this.carol).withdraw(0, getBigNumber(2), this.carol.address)
            console.log(await this.bonusChef.lastTimeRewardApplicable(this.r.address))
            console.log("Carol:" + (await this.r.balanceOf(this.carol.address)))

            rewardsBob = rewardsBob.add(rewardsRound_1_2)
            rewardsCarol = rewardsCarol.add(rewardsRound_1_2)
            // expect(await this.bonusChef.earned(this.r.address, this.bob.address)).to.equal(rewardsRound_1_2)
            expect(await this.bonusChef.earned2(this.r.address, this.carol.address)).to.equal(0)
            // expect(await this.bonusChef.rewards(this.r.address, this.carol.address)).to.equal(rewardsCarol)


            console.log("5 / 10")
            await advanceTimeAndBlock(99)
            await this.chef.connect(this.bob).withdraw(0, getBigNumber(3), this.bob.address)
            console.log(await this.bonusChef.lastTimeRewardApplicable(this.r.address))
            console.log("Bob:" + (await this.r.balanceOf(this.bob.address)))
            
            rewardsBob = rewardsBob.add(rewardsRound_3_4)
            rewardsCarol = rewardsCarol.add(rewardsRound_1_4)
            expect(await this.bonusChef.earned2(this.r.address, this.bob.address)).to.equal(0)
            expect(await this.bonusChef.earned2(this.r.address, this.carol.address)).to.equal(rewardsRound_1_4)

            await this.chef.connect(this.carol).withdraw(0, getBigNumber(1), this.carol.address)
            console.log(await this.bonusChef.lastTimeRewardApplicable(this.r.address))
            console.log("Carol:" + (await this.r.balanceOf(this.carol.address)))

            rewardsCarol = rewardsCarol.add(rewardsRound_1_100)
            expect(await this.bonusChef.earned2(this.r.address, this.bob.address)).to.equal(0)
            expect(await this.bonusChef.earned2(this.r.address, this.carol.address)).to.equal(0)

            // LP Pool is now empty
            // Alice deposits 1 wei - this should be enough to gain ALL bonus rewards from now on
            await this.chef.deposit(0, 1, this.alice.address)

            console.log("6-10 / 10")
            await advanceTimeAndBlock(500)
            
            let rewardsAlice = rewards_1_2.sub(rewardsRound_1_100.mul(2))

            expect(await this.bonusChef.earned2(this.r.address, this.alice.address)).to.equal(rewardsAlice)
            expect(await this.bonusChef.earned2(this.r.address, this.bob.address)).to.equal(0)
            expect(await this.bonusChef.earned2(this.r.address, this.carol.address)).to.equal(0)

            await expect(() => this.chef.harvest(0, this.alice.address))
                .to.changeTokenBalances(this.r, [this.alice, this.bonusChef], [rewardsAlice, rewardsAlice.mul(-1)])

            await this.chef.harvest(0, this.bob.address)
            await this.chef.harvest(0, this.carol.address)

            await expect(() => this.chef.harvest(0, this.alice.address))
                .to.changeTokenBalances(this.r, [this.alice, this.bonusChef], [0, 0])

            
            expect(await this.r.balanceOf(this.bob.address)).to.equal(rewardsBob)
            expect(await this.r.balanceOf(this.carol.address)).to.equal(rewardsCarol)

            // Bonus pool should be depleted by now
            expect(await this.r.balanceOf(this.bonusChef.address)).to.equal(rewardsRound_1_100)
        })
    })

    // describe("PoolLength", function () {
    //     it("PoolLength should execute", async function () {
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         expect(await this.chef.poolLength()).to.be.equal(1)
    //     })
    // })

    // describe("Set", function () {
    //     it("Should emit event LogSetPool", async function () {
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await expect(this.chef.set(0, 10, this.dummy.address, false))
    //             .to.emit(this.chef, "LogSetPool")
    //             .withArgs(0, 10, this.rewarder.address, false)
    //         await expect(this.chef.set(0, 10, this.dummy.address, true)).to.emit(this.chef, "LogSetPool").withArgs(0, 10, this.dummy.address, true)
    //     })

    //     it("Should revert if invalid pool", async function () {
    //         let err
    //         try {
    //             await this.chef.set(0, 10, this.rewarder.address, false)
    //         } catch (e) {
    //             err = e
    //         }

    //         assert.equal(err.toString(), "Error: VM Exception while processing transaction: invalid opcode")
    //     })
    // })

    // describe("PendingSynapse", function () {
    //     it("PendingSynapse should equal ExpectedSynapse", async function () {
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await this.rlp.approve(this.chef.address, getBigNumber(10))
    //         let log = await this.chef.deposit(0, getBigNumber(1), this.alice.address)
    //         await advanceTime(86400)
    //         let log2 = await this.chef.updatePool(0)
    //         let timestamp2 = (await ethers.provider.getBlock(log2.blockNumber)).timestamp
    //         let timestamp = (await ethers.provider.getBlock(log.blockNumber)).timestamp
    //         let expectedSynapse = BigNumber.from("10000000000000000").mul(timestamp2 - timestamp)
    //         let pendingSynapse = await this.chef.pendingSynapse(0, this.alice.address)
    //         expect(pendingSynapse).to.be.equal(expectedSynapse)
    //     })
    //     it("When time is lastRewardTime", async function () {
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await this.rlp.approve(this.chef.address, getBigNumber(10))
    //         let log = await this.chef.deposit(0, getBigNumber(1), this.alice.address)
    //         await advanceBlockTo(3)
    //         let log2 = await this.chef.updatePool(0)
    //         let timestamp2 = (await ethers.provider.getBlock(log2.blockNumber)).timestamp
    //         let timestamp = (await ethers.provider.getBlock(log.blockNumber)).timestamp
    //         let expectedSynapse = BigNumber.from("10000000000000000").mul(timestamp2 - timestamp)
    //         let pendingSynapse = await this.chef.pendingSynapse(0, this.alice.address)
    //         expect(pendingSynapse).to.be.equal(expectedSynapse)
    //     })
    // })

    // describe("MassUpdatePools", function () {
    //     it("Should call updatePool", async function () {
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await advanceBlockTo(1)
    //         await this.chef.massUpdatePools([0])
    //         //expect('updatePool').to.be.calledOnContract(); //not suported by heardhat
    //         //expect('updatePool').to.be.calledOnContractWith(0); //not suported by heardhat
    //     })

    //     it("Updating invalid pools should fail", async function () {
    //         let err
    //         try {
    //             await this.chef.massUpdatePools([0, 10000, 100000])
    //         } catch (e) {
    //             err = e
    //         }

    //         assert.equal(err.toString(), "Error: VM Exception while processing transaction: invalid opcode")
    //     })
    // })

    // describe("Add", function () {
    //     it("Should add pool with reward token multiplier", async function () {
    //         await expect(this.chef.add(10, this.rlp.address, this.rewarder.address))
    //             .to.emit(this.chef, "LogPoolAddition")
    //             .withArgs(0, 10, this.rlp.address, this.rewarder.address)
    //     })

    //     // There's no check implemented, so this won't revert
    //     // it("Should revert if pool with same reward token added twice", async function () {
    //     //     await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //     //     await expect(this.chef.add(10, this.rlp.address, this.rewarder.address)).to.be.revertedWith("Token already added")
    //     // })
    // })

    // describe("UpdatePool", function () {
    //     it("Should emit event LogUpdatePool", async function () {
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await advanceBlockTo(1)
    //         await expect(this.chef.updatePool(0))
    //             .to.emit(this.chef, "LogUpdatePool")
    //             .withArgs(
    //                 0,
    //                 (await this.chef.poolInfo(0)).lastRewardTime,
    //                 await this.rlp.balanceOf(this.chef.address),
    //                 (await this.chef.poolInfo(0)).accSynapsePerShare
    //             )
    //     })

    //     it("Should take else path", async function () {
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await advanceBlockTo(1)
    //         await this.chef.batch(
    //             [this.chef.interface.encodeFunctionData("updatePool", [0]), this.chef.interface.encodeFunctionData("updatePool", [0])],
    //             true
    //         )
    //     })
    // })

    // describe("Deposit", function () {
    //     it("Depositing 0 amount", async function () {
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await this.rlp.approve(this.chef.address, getBigNumber(10))
    //         await expect(this.chef.deposit(0, getBigNumber(0), this.alice.address))
    //             .to.emit(this.chef, "Deposit")
    //             .withArgs(this.alice.address, 0, 0, this.alice.address)
    //     })

    //     it("Depositing into non-existent pool should fail", async function () {
    //         let err
    //         try {
    //             await this.chef.deposit(1001, getBigNumber(0), this.alice.address)
    //         } catch (e) {
    //             err = e
    //         }

    //         assert.equal(err.toString(), "Error: VM Exception while processing transaction: invalid opcode")
    //     })
    // })

    // describe("Withdraw", function () {
    //     it("Withdraw 0 amount", async function () {
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await expect(this.chef.withdraw(0, getBigNumber(0), this.alice.address))
    //             .to.emit(this.chef, "Withdraw")
    //             .withArgs(this.alice.address, 0, 0, this.alice.address)
    //     })
    // })

    // describe("Harvest", function () {
    //     it("Should give back the correct amount of SYN and reward", async function () {
    //         await this.r.transfer(this.rewarder.address, getBigNumber(100000))
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await this.rlp.approve(this.chef.address, getBigNumber(10))
    //         expect(await this.chef.lpToken(0)).to.be.equal(this.rlp.address)
    //         let log = await this.chef.deposit(0, getBigNumber(1), this.alice.address)
    //         await advanceTime(86400)
    //         let log2 = await this.chef.withdraw(0, getBigNumber(1), this.alice.address)
    //         let timestamp2 = (await ethers.provider.getBlock(log2.blockNumber)).timestamp
    //         let timestamp = (await ethers.provider.getBlock(log.blockNumber)).timestamp
    //         let expectedSynapse = BigNumber.from("10000000000000000").mul(timestamp2 - timestamp)
    //         expect((await this.chef.userInfo(0, this.alice.address)).rewardDebt).to.be.equal("-" + expectedSynapse)
    //         await this.chef.harvest(0, this.alice.address)
    //         expect(await this.syn.balanceOf(this.alice.address))
    //             .to.be.equal(await this.r.balanceOf(this.alice.address))
    //             .to.be.equal(expectedSynapse)
    //     })
    //     it("Harvest with empty user balance", async function () {
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await this.chef.harvest(0, this.alice.address)
    //     })

    //     it("Harvest for SYN-only pool", async function () {
    //         await this.chef.add(10, this.rlp.address, TestUtils.ADDRESS_ZERO)
    //         await this.rlp.approve(this.chef.address, getBigNumber(10))
    //         expect(await this.chef.lpToken(0)).to.be.equal(this.rlp.address)
    //         let log = await this.chef.deposit(0, getBigNumber(1), this.alice.address)
    //         await advanceBlock()
    //         let log2 = await this.chef.withdraw(0, getBigNumber(1), this.alice.address)
    //         let timestamp2 = (await ethers.provider.getBlock(log2.blockNumber)).timestamp
    //         let timestamp = (await ethers.provider.getBlock(log.blockNumber)).timestamp
    //         let expectedSynapse = BigNumber.from("10000000000000000").mul(timestamp2 - timestamp)
    //         expect((await this.chef.userInfo(0, this.alice.address)).rewardDebt).to.be.equal("-" + expectedSynapse)
    //         await this.chef.harvest(0, this.alice.address)
    //         expect(await this.syn.balanceOf(this.alice.address)).to.be.equal(expectedSynapse)
    //     })
    // })

    // describe("EmergencyWithdraw", function () {
    //     it("Should emit event EmergencyWithdraw", async function () {
    //         await this.r.transfer(this.rewarder.address, getBigNumber(100000))
    //         await this.chef.add(10, this.rlp.address, this.rewarder.address)
    //         await this.rlp.approve(this.chef.address, getBigNumber(10))
    //         await this.chef.deposit(0, getBigNumber(1), this.bob.address)
    //         //await this.chef.emergencyWithdraw(0, this.alice.address)
    //         await expect(this.chef.connect(this.bob).emergencyWithdraw(0, this.bob.address))
    //             .to.emit(this.chef, "EmergencyWithdraw")
    //             .withArgs(this.bob.address, 0, getBigNumber(1), this.bob.address)
    //     })
    // })
})