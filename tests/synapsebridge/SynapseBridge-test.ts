import "../util/chaisetup";

import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";

import {default as hre, ethers} from "hardhat";

import {Context, Done} from "mocha";

import {step} from "mocha-steps";

import {expect} from "chai";

import type {SynapseBridge, TimelockController, SynapseERC20, ERC20} from "../../build/typechain";

import {TestUtils, Birdies} from "../util";

import {DeployUtils} from "../../deploy/utils";

import {hexZeroPad} from "@ethersproject/bytes";
import {ContractReceipt, Event as ContractEvent} from "@ethersproject/contracts";
import {BigNumber, BigNumberish} from "@ethersproject/bignumber";
import {CHAIN_ID} from "../../utils/network";


describe("SynapseBridge", function(this: Mocha.Suite) {
    const { deployments, getNamedAccounts } = hre;
    let
        synapseBridge: SynapseBridge,
        timelockController: TimelockController,
        deployerAddr: string;

    step("setup", function(this: Context, done: Done) {
        this.timeout(120 * 1000);

        deployments.fixture([
            'DevMultisig',
            'Multicall2',
            'TimelockController',
            'SynapseBridge',
            'SynapseERC20Factory',
            'SynapseERC20',
            'SynapseToken',
            'nUSD',
            'gOHM'
        ], {keepExistingDeployments: false})
            .then(() => {
                let preloadTasks = [
                    TestUtils.contractInstanceFromDeployment('SynapseBridge', hre).then((c) => synapseBridge = c as SynapseBridge),
                    TestUtils.contractInstanceFromDeployment('TimelockController', hre).then((c) => timelockController = c as TimelockController),
                    getNamedAccounts().then(({deployer}) => deployerAddr = deployer)
                ]

                expect(Promise.resolve(preloadTasks)).to.eventually.be.fulfilled.notify(done);
            })
    })

    describe("AccessControl fuckery", function(this: Mocha.Suite) {
        let deployerIsBridgeAdmin: boolean;

        step("check if I have DEFAULT_ADMIN_ROLE on SynapseBridge", function (this: Context, done: Done) {
            this.timeout(10 * 1000);

            expect(synapseBridge).to.not.be.undefined;
            expect(deployerAddr).to.not.equal("");

            synapseBridge.hasRole(DeployUtils.Roles.DefaultAdminRole, deployerAddr)
                .then((res: boolean) => {
                    deployerIsBridgeAdmin = res;
                    done();
                })
                .catch(TestUtils.catchError(done))
        })

        if (!deployerIsBridgeAdmin) {
            let
                scheduledGrantRoleId: string,
                encodedFunc: string;

            const
                schedulerValue: BigNumberish = 0,
                schedulerSalt = ethers.utils.randomBytes(32),
                schedulerDelay = 181;

            describe.skip("TimelockController testing I guess", function (this: Mocha.Suite) {
                step(`schedule up a grantRole call for me`, function (this: Context, done: Done) {
                    this.timeout(13 * 1000);

                    expect(synapseBridge).to.not.be.undefined;
                    expect(deployerAddr).to.not.equal("");

                    encodedFunc = synapseBridge.interface.encodeFunctionData('grantRole', [DeployUtils.Roles.DefaultAdminRole, deployerAddr]);

                    let hashCall: Promise<boolean> = timelockController.hashOperation(
                        deployerAddr,
                        schedulerValue,
                        encodedFunc,
                        hexZeroPad('0x0', 32),
                        schedulerSalt,
                        {from: deployerAddr}
                    ).then((hash: string): boolean => {
                        scheduledGrantRoleId = hash;

                        return true
                    });

                    expect(hashCall).to.eventually.be.true;

                    Birdies.expectTxnReceiptSuccess(timelockController.schedule(
                            deployerAddr,
                            schedulerValue,
                            encodedFunc,
                            hexZeroPad('0x0', 32),
                            schedulerSalt,
                            schedulerDelay,
                            {from: deployerAddr}
                        ).then(TestUtils.waitForConfirmations(1)).catch(TestUtils.catchError(done))
                    ).notify(done);
                })

                step(`guess we're waiting 181 blocks...`, function (this: Context, done: Done) {
                    this.timeout(240 * 1000);

                    TestUtils.pollContract(timelockController.isOperationReady, 10, done, scheduledGrantRoleId);
                })

                step("execute grantRole(DEFAULT_ADMIN_ROLE) action", function (this: Context, done: Done) {
                    this.timeout(13 * 1000);

                    Birdies.expectTxnReceiptSuccess(timelockController.execute(
                            deployerAddr,
                            schedulerValue,
                            encodedFunc,
                            hexZeroPad('0x0', 32),
                            schedulerSalt,
                            {from: deployerAddr}
                        ).then(TestUtils.waitForConfirmations(5)).catch(TestUtils.catchError(done))
                    ).notify(done)
                })

                step("ensure I have DEFAULT_ADMIN_ROLE on the Bridge contract", function (this: Context, done: Done) {
                    this.timeout(240 * 1000);

                    expect(timelockController.isOperationDone(scheduledGrantRoleId))
                        .to.eventually.be.true.notify(done);

                    TestUtils.pollContract(synapseBridge.hasRole, 5, done, DeployUtils.Roles.DefaultAdminRole, deployerAddr, {from: deployerAddr});
                })
            })
        }
    })

    describe("Basic read-only function tests", function(this: Mocha.Suite) {
        step("should be able to fetch the chain gas amount", function(this: Context, done: Done) {
            expect(synapseBridge.chainGasAmount())
                .to.eventually.be.fulfilled.notify(done);
        })
    })

    describe("do some weird stuff with Tokens", function(this: Mocha.Suite) {
        const { deployments: {get, execute} } = hre;

        const tokenNames = ["SynapseToken", "nUSD", "gOHM"];

        step("give meself mint privileges", async function(this: Context, done: Done) {
            this.timeout(30*1000);

            const devMS = await get("DevMultisig");

            const execFunc = async (tokenName: string) => {
                let txn = await execute(
                    tokenName,
                    { from: devMS.address, log: true },
                    "grantRole",
                    DeployUtils.Roles.SynapseERC20MinterRole,
                    devMS.address
                );

                Birdies.expectTxnReceiptSuccess(txn);

                let txn2 = await (await TestUtils.signer(hre)).provider.getTransaction(txn.transactionHash);
                await txn2.wait(2);

                return;
            }

            for (const tName of tokenNames) {
                await execFunc(tName);
            }

            done();
        })

        step("mint some shiz", function(this: Context, done: Done) {
            this.timeout(30*1000);

            const desiredBalance: BigNumber = ethers.utils.parseEther('2000');

            const minterFunc = async (tokenName: string, nonce: number) => {
                const instance = await TestUtils.SynapseERC20Instance(tokenName, hre);

                let populated = await instance.populateTransaction.mint(deployerAddr, desiredBalance);
                populated.nonce = nonce;

                let txn = await (await TestUtils.signer(hre)).sendTransaction(populated);
                await txn.wait(2);
                Birdies.expectBigNumber((await instance.balanceOf(deployerAddr)), desiredBalance);
            }

            TestUtils.getLastNonce(hre)
                .then((lastNonce) => {
                    expect(Promise.resolve(
                        tokenNames.map((tName, idx): Promise<void> =>
                            minterFunc(tName, lastNonce+(idx+1)))
                    )).to.eventually.be.fulfilled.notify(done);
                })
        })
    })

    describe("test SynapseBridge.deposit()", async function(this: Mocha.Suite) {
        interface testCase {
            amt:         BigNumber,
            token:       string,
            deployment?: boolean,
            toChain:     number,
        }

        const testCases: testCase[] = [
            {
                amt:       ethers.utils.parseEther('27'),
                toChain:   parseInt(CHAIN_ID.BSC),
                token:     "SynapseToken",
                deployment: true,
            },
            {
                amt:       ethers.utils.parseEther('522'),
                toChain:   parseInt(CHAIN_ID.MAINNET),
                token:     "SynapseToken",
                deployment: true,
            },
            {
                amt:       ethers.utils.parseEther('420'),
                toChain:   parseInt(CHAIN_ID.POLYGON),
                token:     "nUSD",
                deployment: true,
            }
        ]

        let lastNonce: number = await TestUtils.getLastNonce(hre);

        testCases.forEach((tc) => {
            let instance: Promise<SynapseERC20|ERC20>;

            step("approve transfer", async function(this: Context, done: Done) {
                instance = (tc.deployment ?? false)
                    ? TestUtils.SynapseERC20Instance(tc.token, hre)
                    : TestUtils.ERC20Instance(tc.token, hre)

                this.timeout(10*1000);

                const f = txnReceipt => Birdies.expectTxnReceiptSuccess(txnReceipt);

                const tok = await instance;
                lastNonce++;

                let populated = await tok.populateTransaction.approve(synapseBridge.address, tc.amt, {from:deployerAddr});
                populated.nonce = lastNonce;

                let r = await (await TestUtils.signer(hre)).sendTransaction(populated);
                await f(r.wait(2));

                done();
            })

            step(`should deposit ${ethers.utils.formatEther(tc.amt)} of token into the Bridge`, async function(this: Context, done: Done) {
                this.timeout(10*1000);

                const tok = await instance;

                let startBal: BigNumber = await tok.balanceOf(deployerAddr).then(b => b.sub(tc.amt));

                const f = async txnReceipt => {
                    Birdies.expectTxnReceiptSuccess(txnReceipt);

                    txnReceipt = await txnReceipt;
                    Birdies.expectArrayObject(txnReceipt.events, "event", "TokenDeposit");

                    const eventLog: ContractEvent = txnReceipt.events.find((e) => e.event === "TokenDeposit");

                    expect(eventLog.args).to.have.a.lengthOf(4);

                    Birdies.expectString(eventLog.args[0], deployerAddr)

                    Birdies.expectBigNumber(eventLog.args[1], tc.toChain)

                    Birdies.expectString(eventLog.args[2], tok.address)

                    Birdies.expectBigNumber(eventLog.args[3], tc.amt)

                    Birdies.expectBigNumber(tok.balanceOf(deployerAddr), startBal);
                }

                lastNonce++;

                let populated = await synapseBridge.populateTransaction.deposit(deployerAddr, tc.toChain, tok.address, tc.amt, { from: deployerAddr });
                populated.nonce = lastNonce;

                let txn = await (await TestUtils.signer(hre)).sendTransaction(populated);
                await f(txn.wait(2));

                done();
            })
        })
    })
})