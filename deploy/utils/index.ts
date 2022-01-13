import "@nomiclabs/hardhat-ethers";

import {ethers} from "hardhat";

import type { HardhatRuntimeEnvironment } from "hardhat/types"

import {CHAIN_ID} from "../../utils/network";
import {BytesLike} from "@ethersproject/bytes";


export namespace DeployUtils {
    interface ContractRoles {
        DefaultAdminRole:            string,
        SynapseERC20MinterRole:      string,
        SynapseBridgeNodegroupRole:  string,
        SynapseBridgeGovernanceRole: string,
    }

    const mkHex = (val: BytesLike): string => ethers.utils.hexlify(val);

    export const Roles: ContractRoles = {
        DefaultAdminRole:            ethers.utils.hexZeroPad("0x0", 32),
        SynapseERC20MinterRole:      mkHex("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"),
        SynapseBridgeNodegroupRole:  mkHex("0xb5c00e6706c3d213edd70ff33717fac657eacc5fe161f07180cf1fcab13cc4cd"),
        SynapseBridgeGovernanceRole: mkHex("0x71840dc4906352362b0cdaf79870196c8e42acafade72d5d5a6d59291253ceb1"),
    }

    export async function isHardhat(hre: HardhatRuntimeEnvironment): Promise<boolean> {
        const {getChainId} = hre;

        return (await getChainId()) === CHAIN_ID.HARDHAT
    }
}