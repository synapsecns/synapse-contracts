// noinspection JSUnusedGlobalSymbols

import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";

import {ethers} from "hardhat";

import "./chaisetup";

import {Done} from "mocha";

import {Contract, ContractReceipt, ContractTransaction} from "@ethersproject/contracts";
import {HardhatRuntimeEnvironment} from "hardhat/types";
import {BigNumber, PopulatedTransaction} from "ethers";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {Deployment} from "hardhat-deploy/types";
import {ERC20, SynapseERC20} from "../../build/typechain";
import {Birdies} from "./birdies";
import {TransactionResponse} from "@ethersproject/abstract-provider";

export namespace TestUtils {
    export const
        DEFAULT_ADMIN_ROLE:             string = ethers.utils.hexZeroPad("0x0", 32),
        SYNAPSE_ERC20_MINTER_ROLE:      string = ethers.utils.hexlify("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"),
        SYNAPSEBRIDGE_NODEGROUP_ROLE:   string = ethers.utils.hexlify("0xb5c00e6706c3d213edd70ff33717fac657eacc5fe161f07180cf1fcab13cc4cd"),
        SYNAPSEBRIDGE_GOVERNANCE_ROLE:  string = ethers.utils.hexlify("0x71840dc4906352362b0cdaf79870196c8e42acafade72d5d5a6d59291253ceb1"),
        ADDRESS_ZERO:                   string = "0x0000000000000000000000000000000000000000"

    export function doneWithError(err: any, done: Done) {
        let e = err instanceof Error ? err : new Error(err);

        done(e);
    }

    export function catchError(done: Done): (err: any) => void { return (err: any) => doneWithError(err, done); }


    export async function signer(hre: HardhatRuntimeEnvironment): Promise<SignerWithAddress> {
        return hre.getNamedAccounts().then(({deployer}) => hre.ethers.getSigner(deployer));
    }

    export function getSynapseERC20Balance(
        hre: HardhatRuntimeEnvironment,
        deploymentName: string,
        addr: string
    ): Promise<BigNumber> {
        return Promise.resolve(
            hre.deployments.read(
                deploymentName,
                "balanceOf",
                addr
            ).then((bal: BigNumber) => bal)
        )
    }
}