import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, get } = deployments
  const { deployer, bscMultisig, ethMultisig, polyMultisig } = await getNamedAccounts()
  let multisig;


  if ((await getChainId()) === '1') {
    multisig = ethMultisig;
  }

  if ((await getChainId()) === '56') {
    multisig = bscMultisig;
  }

  if ((await getChainId()) === '137') {
    multisig = polyMultisig;
  }


  await deploy('SynapseBridge', {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    proxy: {
      owner: multisig,
      proxyContract: 'OpenZeppelinTransparentProxy',
    },
  })
}
export default func
func.tags = ['SynapseBridge']
