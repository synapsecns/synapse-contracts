import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import {CHAIN_ID} from "../utils/network";

import {DeployUtils} from "./utils";

const DEPLOYMENT_NAME: string = "SynapseBridge";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre
    const { deploy, execute, catchUnknownSigner, get } = deployments
    const { deployer } = await getNamedAccounts()

    await catchUnknownSigner(
        deploy(DEPLOYMENT_NAME, {
            from: deployer,
            log: true,
            skipIfAlreadyDeployed: true,
            proxy: {
                owner: (await get("TimelockController")).address,
                proxyContract: "OpenZeppelinTransparentProxy",
            },
        }),
    )

    // const isHardhat = await Utils.isHardhat(hre);
    // if (isHardhat) {
    //     await catchUnknownSigner(
    //         execute(
    //             DEPLOYMENT_NAME,
    //             { from: deployer, log: true },
    //             "grantRole",
    //             Utils.DEFAULT_ADMIN_ROLE,
    //             await Utils.deploymentAddress("DevMultisig", hre),
    //         )
    //     )
    // }
}
export default func
func.tags = [DEPLOYMENT_NAME]
