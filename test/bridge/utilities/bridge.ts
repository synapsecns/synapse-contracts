import {RateLimiter, SynapseBridge} from "../../../build/typechain";
import { deployments, ethers, upgrades } from "hardhat"
import {Signer} from "ethers";
import {addBridgeOwner, upgradeBridgeProxy} from "./fork";

/**
 * deploys a rate limiter and sets it up with a role
 * @param deployer - dpeloyer of the contract
 * @param owner - owner of the rate limiter.
 */
export async function deployRateLimiter(deployer: Signer, owner: Signer): Promise<RateLimiter> {
    const rateLimiterFactory = await ethers.getContractFactory("RateLimiter")
    const rateLimiter = (await rateLimiterFactory.deploy()) as RateLimiter
    await rateLimiter.initialize()

    const limiterRole = await rateLimiter.LIMITER_ROLE()
    await rateLimiter
        .connect(deployer)
        .grantRole(limiterRole, await owner.getAddress())

    const governanceRole = await rateLimiter.GOVERNANCE_ROLE()

    await rateLimiter
        .connect(deployer)
        .grantRole(governanceRole, await owner.getAddress())

    // connect the bridge config v3 with the owner. For unauthorized tests, this can be overriden
    return rateLimiter.connect(owner)
}

export async function setupForkedBridge(rateLimiter: RateLimiter, bridgeAddress: string, deployer: Signer, nodeGroup: Signer): Promise<SynapseBridge> {
    if (rateLimiter == null) {
        throw "rate limiter must be deployed before bridge"
    }

    // deploy and initialize the rate limiter
    const synapseBridgeFactory = await ethers.getContractFactory(
        "SynapseBridge",
    )

    await upgradeBridgeProxy(bridgeAddress)

    // attach to the deployed bridge
    let bridge = (await synapseBridgeFactory.attach(
        bridgeAddress,
    )) as SynapseBridge

    await addBridgeOwner(bridgeAddress, await deployer.getAddress())

    // grant rate limiter role on bridge to rate limiter
    const rateLimiterRole = await bridge.RATE_LIMITER_ROLE()
    await bridge
        .connect(deployer)
        .grantRole(rateLimiterRole, rateLimiter.address)

    await bridge.setRateLimiter(rateLimiter.address)

    const nodeGroupRole = await bridge.NODEGROUP_ROLE()
    await bridge
        .connect(deployer)
        .grantRole(nodeGroupRole, await nodeGroup.getAddress())

    bridge = await bridge.connect(nodeGroup)

    await rateLimiter
        .connect(deployer)
        .grantRole(await rateLimiter.BRIDGE_ROLE(), bridge.address)

    await rateLimiter.setBridgeAddress(bridge.address)

    return bridge
}

const BRIDGE_CONFIGS = {
    1: {
        bridge: "0x2796317b0fF8538F253012862c06787Adfb8cEb6",
        nusd: "0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F",
        nusd_pool: "0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8"
    }
}