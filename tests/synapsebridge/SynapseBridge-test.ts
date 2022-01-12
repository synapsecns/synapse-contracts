import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";

import {default as hre, ethers} from "hardhat";

import {Context, Done} from "mocha";

import {step} from "mocha-steps";

import * as chai from "chai";
import chaiAsPromised from "chai-as-promised";

import type {SynapseBridge, TimelockController, SynapseERC20} from "../../build/typechain";

import {TestUtils, ZeroAddress} from "../util";

import {BytesLike, hexZeroPad} from "@ethersproject/bytes";
import {ContractReceipt, ContractTransaction, PopulatedTransaction} from "@ethersproject/contracts";
import {BigNumber, BigNumberish} from "@ethersproject/bignumber";

chai.use(chaiAsPromised);

const { expect } = chai;

describe("SynapseBridge", function(this: Mocha.Suite) {
    const
        { deployments, getNamedAccounts } = hre,
        adminRole: BytesLike = hexZeroPad('0x0', 32);

    let
        synapseBridge: SynapseBridge,
        timelockController: TimelockController,
        deployerAddr: string;

    describe("Basic Tests", function(this: Mocha.Suite) {
        step("setup", async function(this: Context, done: Done) {
            this.timeout(65*1000);

            await deployments.fixture([
                'DevMultisig',
                'Multicall2',
                'TimelockController',
                'SynapseBridge',
                'SynapseERC20Factory',
                'SynapseERC20',
                'SynapseToken',
            ])

            synapseBridge = (await TestUtils.contractInstanceFromDeployment('SynapseBridge', hre)) as SynapseBridge;
            timelockController = (await TestUtils.contractInstanceFromDeployment('TimelockController', hre) as TimelockController);

            let {deployer} = await getNamedAccounts();
            deployerAddr = deployer;

            done();
        })

        let deployerIsBridgeAdmin: boolean;

        step("check if I have DEFAULT_ADMIN_ROLE on SynapseBridge", async function(this: Context, done: Done) {
            this.timeout(10*1000);

            expect(synapseBridge).to.not.be.undefined;
            expect(deployerAddr).to.not.equal("");

            deployerIsBridgeAdmin = await synapseBridge.hasRole(adminRole, deployerAddr);

            done()
        })

        if (!deployerIsBridgeAdmin) {
            let
                scheduledGrantRoleId: string,
                encodedFunc: string;

            const
                schedulerValue: BigNumberish = 0,
                schedulerSalt = ethers.utils.randomBytes(32),
                schedulerDelay = 181;

            describe.skip("TimelockController testing I guess", function(this: Mocha.Suite) {
                step(`schedule up a grantRole call for me`, function(this: Context, done: Done) {
                    this.timeout(13*1000);

                    expect(synapseBridge).to.not.be.undefined;
                    expect(deployerAddr).to.not.equal("");

                    encodedFunc = synapseBridge.interface.encodeFunctionData('grantRole', [adminRole, deployerAddr]);

                    let hashCall: Promise<boolean> = timelockController.hashOperation(
                        deployerAddr,
                        schedulerValue,
                        encodedFunc,
                        hexZeroPad('0x0', 32),
                        schedulerSalt,
                        { from: deployerAddr }
                    ).then((hash: string): boolean => {
                        scheduledGrantRoleId = hash;

                        return true
                    });

                    let txnProm: Promise<ContractReceipt> = Promise.resolve(timelockController.schedule(
                            deployerAddr,
                            schedulerValue,
                            encodedFunc,
                            hexZeroPad('0x0', 32),
                            schedulerSalt,
                            schedulerDelay,
                            { from: deployerAddr }
                        )
                            .then(TestUtils.waitForConfirmations(1))
                            .catch(TestUtils.catchError(done))
                    ).then((r: ContractReceipt) => r)

                    expect(hashCall).to.eventually.be.true;
                    expect(txnProm)
                        .to.eventually.have
                        .property("status").that.equals(1)
                        .notify(done);
                })

                step(`guess we're waiting 181 blocks...`, function(this: Context, done: Done) {
                    this.timeout(240*1000);

                    TestUtils.pollContract(timelockController.isOperationReady, 10, done, scheduledGrantRoleId);
                })

                step("execute grantRole(DEFAULT_ADMIN_ROLE) action", function(this: Context, done: Done) {
                    this.timeout(13*1000);

                    let txnProm: Promise<ContractReceipt> = Promise.resolve(timelockController.execute(
                            deployerAddr,
                            schedulerValue,
                            encodedFunc,
                            hexZeroPad('0x0', 32),
                            schedulerSalt,
                            { from: deployerAddr }
                        )
                            .then(TestUtils.waitForConfirmations(5))
                            .catch(TestUtils.catchError(done))
                    ).then((r: ContractReceipt) => r)

                    expect(txnProm)
                        .to.eventually.have
                        .property("status").that.equals(1)
                        .notify(done);
                })

                step("ensure I have DEFAULT_ADMIN_ROLE on the Bridge contract", function(this: Context, done: Done) {
                    this.timeout(240*1000);

                    expect(timelockController.isOperationDone(scheduledGrantRoleId))
                        .to.eventually.be.true.notify(done);

                    TestUtils.pollContract(synapseBridge.hasRole, 5, done, adminRole, deployerAddr, { from: deployerAddr });
                })
            })
        }

        it("should be able to fetch the chain gas amount", function(this: Context, done: Done) {
            expect(synapseBridge.chainGasAmount())
                .to.eventually.be.fulfilled.notify(done);
        })

        describe("do some weird stuff with SynapseToken", function(this: Mocha.Suite) {
            const { deployments: {get, execute} } = hre;

            step("give meself mint privileges for SYN", function(this: Context, done: Done) {
                get("DevMultisig")
                    .then((dm) => {
                        execute(
                            "SynapseToken",
                            { from: dm.address, log: true },
                            "grantRole",
                            "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
                            dm.address
                        ).then(() => done())
                    })
            })

            step("mint some shiz", function(this: Context, done: Done) {
                TestUtils.contractInstanceFromDeployment("SynapseToken", hre)
                    .then((tok) => {
                        let t = (tok as SynapseERC20);
                        t.mint(deployerAddr, ethers.utils.parseEther('20'))
                            .then(() => {
                                t.balanceOf(deployerAddr).then((bal) => {
                                    expect(bal.eq(ethers.utils.parseEther('20'))).to.be.true.notify(done);
                                })
                            })
                    })
            })
        })
    })
})