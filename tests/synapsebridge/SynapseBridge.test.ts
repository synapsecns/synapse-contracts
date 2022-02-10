import "../util/chaisetup";

import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";

import {default as hre, ethers} from "hardhat";

import {Context, Done} from "mocha";

import {step} from "mocha-steps";

import {expect} from "chai";

import type {SynapseBridge, TimelockController, SynapseERC20} from "../../build/typechain";

import {TestUtils, Birdies} from "../util";

import {DeployUtils} from "../../deploy/utils";

import {Event as ContractEvent} from "@ethersproject/contracts";
import {BigNumber} from "@ethersproject/bignumber";
import {CHAIN_ID} from "../../utils/network";
import {Deployment} from "hardhat-deploy/types";


describe("SynapseBridge", function(this: Mocha.Suite) {
    const { getNamedAccounts } = hre;
    let
        synapseBridge:      Deployment,
        devMultisig:        Deployment,
        deployerAddr:       string;

    step("setup", function(this: Context, done: Done) {
        this.timeout(120 * 1000);

        hre.deployments.log("setting up fixtures...")

        hre.deployments.fixture([
            'DevMultisig',
            'Multicall2',
            'TimelockController',
            'SynapseBridge',
            "SynapseERC20",
            "SynapseERC20Factory",
            "SynapseToken",
            "nUSD",
            "gOHM"
        ], {keepExistingDeployments: true})
            .then(() => {
                let preloadTasks = [
                    hre.deployments.get("SynapseBridge").then((d) => synapseBridge = d),
                    hre.deployments.get("DevMultisig").then((d) => devMultisig = d),
                    getNamedAccounts().then(({deployer}) => deployerAddr = deployer)
                ]

                expect(Promise.resolve(preloadTasks)).to.eventually.be.fulfilled.notify(done);
            })
            .catch(TestUtils.catchError(done))
    })

    describe("Basic read-only function tests", function(this: Mocha.Suite) {
        step("should be able to fetch the chain gas amount", function(this: Context, done: Done) {
            hre.deployments.read(
                "SynapseBridge",
                "chainGasAmount"
            ).then((res: BigNumber) => {
                expect(res).to.be.gte(0);
                done();
            })
        })
    })

    describe("do some weird stuff with Tokens", function(this: Mocha.Suite) {
        const { deployments: {execute} } = hre;

        const tokenNames = ["SynapseToken", "nUSD", "gOHM"];

        describe("give meself mint privileges", function(this: Mocha.Suite) {
            this.timeout(30*1000);

            for (const tName of tokenNames) {
                step(`should make me a minter for ${tName}`, function(this: Context, done: Done) {
                    execute(
                        tName,
                        {from: devMultisig.address, log: true},
                        "grantRole",
                        DeployUtils.Roles.SynapseERC20MinterRole,
                        devMultisig.address
                    ).then((txn) => {
                        // Birdies.expectTxnReceiptSuccess(txn);
                        TestUtils.signer(hre).then((s) => {
                            s.provider.getTransaction(txn.transactionHash).then((txn2) => {
                                Birdies.expectTxnReceiptSuccess(txn2.wait(2)).notify(done)
                            })
                        }).catch(TestUtils.catchError(done))
                    })
                })
            }
        })

        describe("mint some shiz", function(this: Mocha.Suite) {
            const desiredBalance: BigNumber = ethers.utils.parseEther('2000');

            tokenNames.forEach((tName: string) => {
                step(`should mint some ${tName}`, function(this: Context, done: Done) {
                    this.timeout(20*1000);

                    execute(
                        tName,
                        {from: devMultisig.address, log: true},
                        "mint",
                        deployerAddr,
                        desiredBalance
                    ).then(() =>
                        TestUtils.getSynapseERC20Balance(
                            hre,
                            tName,
                            deployerAddr
                        ).then((bal: BigNumber) => {
                            expect(bal).to.equal(desiredBalance);
                            done()
                        })
                    )
                })
            })
        })
    })

    describe("test SynapseBridge.deposit()", function(this: Mocha.Suite) {
        interface testCase {
            amt:         BigNumber,
            token:       string,
            toChain:     number,
        }

        const testCases: testCase[] = [
            {
                amt:       ethers.utils.parseEther('27'),
                toChain:   parseInt(CHAIN_ID.BSC),
                token:     "SynapseToken",
            },
            {
                amt:       ethers.utils.parseEther('522'),
                toChain:   parseInt(CHAIN_ID.MAINNET),
                token:     "SynapseToken",
            },
            {
                amt:       ethers.utils.parseEther('420'),
                toChain:   parseInt(CHAIN_ID.POLYGON),
                token:     "nUSD",
            }
        ]

        describe(`should deposit tokens into the Bridge`, function(this: Mocha.Suite) {
            testCases.forEach((tc) => {
                step(`should approve ${tc.amt} of ${tc.token} for spending`, function(this: Context, done: Done) {
                    this.timeout(10*1000)
                    hre.deployments.execute(
                        tc.token,
                        {from: deployerAddr, log: true},
                        "approve",
                        synapseBridge.address,
                        tc.amt
                    )
                        .then((txn) => Birdies.expectTxnReceiptSuccess(txn).notify(done))
                        .catch(TestUtils.catchError(done))
                })

                step(`should deposit ${tc.amt} of ${tc.token}`, function(this: Context, done: Done) {
                    this.timeout(30*1000);

                    let startBalProm: Promise<BigNumber> = Promise.resolve(
                        hre.deployments.read(
                            tc.token,
                            "balanceOf",
                            deployerAddr
                        ).then((bal: BigNumber) => bal)
                    )

                    hre.deployments.get(tc.token).then(({address: tokenAddress}) => {
                        hre.deployments.execute(
                            "SynapseBridge",
                            {from:deployerAddr, log:true},
                            "deposit",
                            deployerAddr,
                            tc.toChain,
                            tokenAddress,
                            tc.amt,
                        ).then(txnReceipt=> {
                            Birdies.expectArrayObject(txnReceipt.events, "event", "TokenDeposit");
                            const eventLog: ContractEvent = txnReceipt.events.find((e) => e.event === "TokenDeposit");
                            expect(eventLog.args).to.have.a.lengthOf(4);

                            const testVals: any[] = [deployerAddr, tc.toChain, tokenAddress, tc.amt];

                            eventLog.args.forEach((arg: any, idx: number) => {
                                if (arg instanceof BigNumber) {
                                    Birdies.expectBigNumber(arg, testVals[idx]);
                                } else if (typeof arg === 'string') {
                                    Birdies.expectString(arg, testVals[idx]);
                                }
                            })

                            TestUtils.getSynapseERC20Balance(
                                hre,
                                tc.token,
                                deployerAddr
                            ).then((bal) => {
                                startBalProm.then((startBal) => {
                                    let diff: BigNumber = startBal.sub(tc.amt);
                                    expect(bal).to.equal(diff);

                                    done();
                                })
                            })
                        })
                    })
                })
            })
        })
    })
})