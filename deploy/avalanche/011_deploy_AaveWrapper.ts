import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CHAIN_ID } from "../../utils/network"


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  if ((await getChainId()) === CHAIN_ID.AVALANCHE) {
        await deploy("AaveSwapWrapper", {
            from: deployer,
            log: true,
            skipIfAlreadyDeployed: true,
            args: [
            (await get('AaveETHPool')).address,
            [
                (await get('nETH')).address,
                (await get('WETH')).address,
            ],
            "0x4F01AeD16D97E3aB5ab2B501154DC9bb0F1A5A2C",
            (await get('DevMultisig')).address,
            ],
            gasLimit: 2000000
        })
    }
}
export default func
func.tags = ["AaveSwapWrapper"]
