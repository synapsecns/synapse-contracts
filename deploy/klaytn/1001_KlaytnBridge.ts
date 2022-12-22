import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_ID } from "../../utils/network";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, get, catchUnknownSigner } = deployments;
  const { deployer } = await getNamedAccounts();

  if ((await getChainId()) != CHAIN_ID.KLATYN) {
    return;
  }

  await deploy("WKlayUnwrapper", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
    args: [(await get("DevMultisig")).address],
  });

  await catchUnknownSigner(
    deploy("SynapseBridge", {
      contract: "KlaytnSynapseBridge",
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [(await get("WKlayUnwrapper")).address],
      proxy: {
        owner: (await get("TimelockController")).address,
        proxyContract: "OpenZeppelinTransparentProxy",
      },
    })
  );
};
export default func;
func.tags = ["KlaytnSynapseBridge"];
