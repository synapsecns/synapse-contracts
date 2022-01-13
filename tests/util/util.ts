import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";

import {ethers} from "hardhat";

import "./chaisetup";

import {Done} from "mocha";

import {Contract, ContractReceipt, ContractTransaction} from "@ethersproject/contracts";
import {HardhatRuntimeEnvironment} from "hardhat/types";
import {BigNumber} from "ethers";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {Deployment} from "hardhat-deploy/types";
import {ERC20, SynapseERC20} from "../../build/typechain";
import {expect} from "chai";
import {Birdies} from "./birdies";

export const ZeroAddress: string = "0x0000000000000000000000000000000000000000";

export namespace TestUtils {
    export const
        DEFAULT_ADMIN_ROLE:             string = ethers.utils.hexZeroPad("0x0", 32),
        SYNAPSE_ERC20_MINTER_ROLE:      string = ethers.utils.hexlify("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"),
        SYNAPSEBRIDGE_NODEGROUP_ROLE:   string = ethers.utils.hexlify("0xb5c00e6706c3d213edd70ff33717fac657eacc5fe161f07180cf1fcab13cc4cd"),
        SYNAPSEBRIDGE_GOVERNANCE_ROLE:  string = ethers.utils.hexlify("0x71840dc4906352362b0cdaf79870196c8e42acafade72d5d5a6d59291253ceb1");

    export async function getDeployment(name: string, hre: HardhatRuntimeEnvironment): Promise<Deployment> {
        let {deployments: {get}} = hre;

        return get(name);
    }

    export async function deploymentAddress(name: string, hre: HardhatRuntimeEnvironment): Promise<string|null> {
        return Promise.resolve(getDeployment(name, hre)
            .then(({address}) => address)
            .catch((err: any): any => {
                console.error(err instanceof Error ? err : new Error(err));
                return null
            })
        )
    }

    export function doneWithError(err: any, done: Done) {
        let e = err instanceof Error ? err : new Error(err);

        done(e);
    }

    export function catchError(done: Done): (err: any) => void { return (err: any) => doneWithError(err, done); }


    export async function signer(hre: HardhatRuntimeEnvironment): Promise<SignerWithAddress> {
        return (await ethers.getSigner((await hre.getNamedAccounts()).deployer))
    }

    export async function contractInstanceFromDeployment(name: string, hre: HardhatRuntimeEnvironment): Promise<Contract> {
        const
            {deployments: {get}, getNamedAccounts} = hre,
            {deployer}     = await getNamedAccounts(),
            {address, abi} = await get(name),
            signer         = await ethers.getSigner(deployer);

        return await ethers.getContractAt(abi, address, signer)
    }

    export function waitForConfirmations(
        confs?: number,
        fn?: (txReceipt: ContractReceipt) => any|void
    ): (txn: ContractTransaction) => Promise<any|void> {
        fn = fn ?? (txReceipt => txReceipt)
        return (txn: ContractTransaction): Promise<any|void> => txn.wait(confs ?? 1).then(fn)
    }

    export async function pollContract(f: (...args: any) => Promise<boolean>, seconds: number, done: Done, ...args: any) {
        let isReady = await f(...args);

        let interval = setInterval(async () => {
            isReady = await f(...args);
            if (isReady) {
                clearInterval(interval);
                done();
            }
        }, seconds*1000);
    }

    export async function checkWalletBalance(hre: HardhatRuntimeEnvironment): Promise<BigNumber> {
        return (await signer(hre)).getBalance()
    }

    export async function ERC20Instance(address: Birdies.KindaPromise<string>, hre: HardhatRuntimeEnvironment): Promise<ERC20> {
        return (await hre.ethers.getContractAt("ERC20", await address)) as ERC20;
    }

    export async function SynapseERC20Instance(
        name: string,
        hre:  HardhatRuntimeEnvironment
    ): Promise<SynapseERC20> {
        return (await contractInstanceFromDeployment(name, hre)) as SynapseERC20
    }
}