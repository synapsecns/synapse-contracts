import {RateLimiter, SynapseBridge} from "../../../build/typechain";
import { deployments, ethers } from "hardhat"
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

    // grant governance role so rate limiter can be set
    const governanceRole = await bridge.GOVERNANCE_ROLE()
    await bridge
        .connect(deployer)
        .grantRole(governanceRole, await deployer.getAddress())

    await bridge.setRateLimiter(rateLimiter.address)
    await bridge.setRateLimiterEnabled(true)

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