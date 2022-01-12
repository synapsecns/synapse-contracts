import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";

import {default as hre} from "hardhat";

import {ethers} from "hardhat";

import {Context, Done} from "mocha";

import {step} from "mocha-steps";

import * as chai from "chai";
import chaiAsPromised from "chai-as-promised";

import type {SynapseBridge, TimelockController} from "../../build/typechain";

import {TestUtils, ZeroAddress} from "../util";

import {BytesLike, hexZeroPad} from "@ethersproject/bytes";
import {ContractReceipt, ContractTransaction} from "@ethersproject/contracts";
import {BigNumberish} from "ethers";

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
            this.timeout(30*1000);

            await deployments.fixture([
                'DevMultisig',
                'TimelockController',
                'SynapseBridge',
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

            describe("TimelockController testing I guess", function(this: Mocha.Suite) {
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

                step(`guess we're waiting 181 blocks...`, async function(this: Context, done: Done) {
                    this.timeout(240*1000);

                    const intervalSeconds = 10;

                    let
                        intervalCount = 0,
                        isReady = await timelockController.isOperationReady(scheduledGrantRoleId);

                    let interval = setInterval(async () => {
                        isReady = await timelockController.isOperationReady(scheduledGrantRoleId);
                        if (isReady) {
                            clearInterval(interval);
                            done();
                        } else {
                            intervalCount++;
                            console.log(`interval count: ${intervalCount}. Seconds waited: ${intervalSeconds*intervalCount}`);
                        }
                    }, intervalSeconds*1000);
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
                        .property("status").that.equals(1);

                    expect(timelockController.isOperationDone(scheduledGrantRoleId))
                        .to.eventually.be.true.notify(done);
                })

                step("ensure I have DEFAULT_ADMIN_ROLE on the Bridge contract", async function(this: Context, done: Done) {
                    this.timeout(240*1000);

                    const intervalSeconds = 5;

                    let
                        intervalCount = 0,
                        isReady = await synapseBridge.hasRole(adminRole, deployerAddr);

                    let interval = setInterval(async () => {
                        isReady = await synapseBridge.hasRole(adminRole, deployerAddr);
                        if (isReady) {
                            clearInterval(interval);
                            done();
                        } else {
                            intervalCount++;
                            console.log(`interval count: ${intervalCount}. Seconds waited: ${intervalSeconds*intervalCount}`);
                        }
                    }, intervalSeconds*1000);
                })
            })
        }

        describe("WETH_ADDRESS whackery", function(this: Mocha.Suite) {
            step(`should have a WETH_ADDRESS equal to ${ZeroAddress}`, function(this: Context, done: Done) {
                this.timeout(10*1000);

                expect(synapseBridge.WETH_ADDRESS())
                    .to.eventually.equal(ZeroAddress)
                    .notify(done);
            })

            const TestWETHAddress: string = "0x49d5c2bdffac6ce2bfdb6640f4f80f226bc10bab"; // AVAX WETH address

            step(`should set WETH_ADDRESS to ${TestWETHAddress}`, function(this: Context, done: Done) {
                this.timeout(10*1000);

                let setWETHTxn: Promise<ContractReceipt> = synapseBridge.setWethAddress(TestWETHAddress)
                    .then((r): Promise<ContractReceipt> =>
                        r.wait(1).then((receipt) => receipt)
                    )

                expect(setWETHTxn)
                    .to.eventually.have
                    .property("status").that.equals(1)
                    .notify(done);
            })

            step(`should have a WETH_ADDRESS equal to ${TestWETHAddress}`, function(this: Context, done: Done) {
                this.timeout(10*1000);

                expect(synapseBridge.WETH_ADDRESS())
                    .to.eventually.equal(TestWETHAddress)
                    .notify(done);
            })
        })
    })
})