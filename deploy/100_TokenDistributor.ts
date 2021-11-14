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

  if ((await getChainId()) === '43114') {
    await deploy('nUSDTokenDistributor', {
      contract: "TokenDistributor",
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: ["0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46"],
    })
  }
}
export default func
func.tags = ['PoolConfig']
