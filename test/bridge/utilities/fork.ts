import { deployments, ethers, network } from "hardhat"
import {ProxyAdmin, SynapseBridge} from "../../../build/typechain";
import {impersonateAccount} from "../../utils";

// upgradeForkBridge upgrade a forked bridge to the latest version
export async function upgradeBridgeProxy(bridgeAddress: string){
    // set the current bridge to a SynapseBridge type so we can pull out the owner
    const synapseBridge = await ethers.getContractFactory("SynapseBridge");

    const proxyAdminContract = await ethers.getContractFactory("ProxyAdmin")
    const proxyAdmin = (proxyAdminContract.attach(await getProxyAdmin(bridgeAddress))) as ProxyAdmin
    const proxyAdminOwner = await proxyAdmin.owner()

    const signer = await impersonateAccount(proxyAdminOwner)

    // set the balance
    await network.provider.send("hardhat_setBalance", [
        signer._address,
        "0x1228610962826298768",
    ]);

    // upgrade the contract
    await proxyAdmin.connect(signer).upgrade(bridgeAddress, (await synapseBridge.deploy()).address)
}

// addBridgeOwner adds a new bridge owner to a deployed bridge contract for forking
export async function addBridgeOwner(bridgeAddress: string, newOwner: string) {
    // set the current bridge to a SynapseBridge type so we can pull out the owner
    const synapseBridge = await ethers.getContractFactory("SynapseBridge");

    const deployedBridge = (await synapseBridge.attach(bridgeAddress)) as SynapseBridge
    const adminRole = await deployedBridge.DEFAULT_ADMIN_ROLE()
    const currentOwner = await deployedBridge.getRoleMember(adminRole, 0)

    const signer = await impersonateAccount(currentOwner)
    await deployedBridge.connect(signer).grantRole(adminRole, newOwner)
}

// getAdmin gets the admin of a TransparentUpgradableProxy.
// see: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/TransparentUpgradeableProxy.sol#L61 for the slot
export async function getProxyAdmin(proxyAddress: String){
    // @ts-ignore
    const rawOwner = await ethers.getDefaultProvider().getStorageAt(proxyAddress, "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103")

    return ethers.utils.defaultAbiCoder.decode(["address"], rawOwner)[0]
}
