import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import {CHAIN_ID} from "../utils/network";
import {includes} from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  if (includes([CHAIN_ID.DFK_TESTNET, CHAIN_ID.HARMONY_TESTNET], await getChainId())) {
    await deploy('AuthVerifier', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [deployer],
    })

    await deploy('GasFeePricing', {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
        args: [],
      })

    await deploy('MessageBus', {
        from: deployer,
        log: true,
        skipIfAlreadyDeployed: true,
        args: [(await get('GasFeePricing')).address, (await get('AuthVerifier')).address],
      })
  }
}
export default func
func.tags = ['Messaging']
