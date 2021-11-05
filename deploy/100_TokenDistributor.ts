import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  if ((await getChainId()) === '56') {
    await deploy('VestTokenDistributor', {
      contract: "TokenDistributor",
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: ["0x42F6f551ae042cBe50C739158b4f0CAC0Edb9096"],
    })
  }
}
export default func
func.tags = ['PoolConfig']
