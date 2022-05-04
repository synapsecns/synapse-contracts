import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import {CHAIN_ID} from "../utils/network";
import {includes} from "lodash";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()
  const chainId = await getChainId();
  const HeroBridgeConfig = {
    [CHAIN_ID.DFK_TESTNET]: {
        "heroes": "0x3bcaCBeAFefed260d877dbE36378008D4e714c8E",
        "auction": "0x846635615609a8dd88eA4A92dA1F1Ba6880a9Eb5"
    },
    [CHAIN_ID.HARMONY_TESTNET]: {
      "heroes": "0xC57971c3EC0Fc2450FC5CC9c4398ac08ff09e6ED",
      "auction": "0x5f5a567140A4b7A0406f568B152aA4bc3aCda8Ed"
    }
  }
  if (includes([CHAIN_ID.DFK_TESTNET, CHAIN_ID.HARMONY_TESTNET], chainId)) {
    await deploy('HeroBridge', {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [(await get('MessageBus')).address, HeroBridgeConfig.chainId.heroes, HeroBridgeConfig.chainId.auction],
    })
    }
}
export default func
func.tags = ['DFKHeroBridge']
func.dependencies = ["Messaging"]