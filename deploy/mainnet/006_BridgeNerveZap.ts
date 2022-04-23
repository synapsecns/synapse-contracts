import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import {CHAIN_ID} from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  if ((await getChainId()) === CHAIN_ID.MAINNET) {
    await deploy('L1BridgeZap', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get('WETH')).address,
        (await get('USDPool')).address,
        (await get('SynapseBridge')).address,
      ],
      gasLimit: 5000000
    })
  }

  if ((await getChainId()) === CHAIN_ID.DFK) {
    await deploy('L1BridgeZap', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        (await get('WJEWEL')).address,
        "0x0000000000000000000000000000000000000000",
        (await get('SynapseBridge')).address,
      ],
      gasLimit: 5000000
    })
  }
}
export default func
func.tags = ['NerveBridgeZap']
