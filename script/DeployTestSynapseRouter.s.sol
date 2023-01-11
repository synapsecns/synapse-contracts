// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./utils/BaseScript.sol";
import "../contracts/bridge/router/SynapseRouter.sol";
import "../contracts/bridge/router/SwapQuoter.sol";

contract DeployTestSynapseRouter is BaseScript {
    using stdJson for string;

    // Alphabetical order to get the JSON parsing working
    struct TokenConfig {
        uint256 bridgeFee;
        address bridgeToken;
        bytes32 maxFee;
        bytes32 minFee;
        address token;
        uint256 tokenType;
    }

    string public constant ROUTER = "SynapseRouter";
    string public constant QUOTER = "SwapQuoter";

    function deploy(string memory chain) public {
        string memory config = vm.readFile(_concat("./script/router_", chain, ".json"));
        address bridge = config.readAddress("bridge");
        address wgas = config.readAddress("wgas");
        address[] memory pools = config.readAddressArray("pools");
        string[] memory ids = config.readStringArray("ids");
        console.log("Bridge: %s", bridge);
        console.log("WGAS: %s", wgas);
        console.log("Pools: %s", pools.length);
        for (uint256 i = 0; i < pools.length; ++i) {
            console.log(pools[i]);
        }
        console.log("Tokens: %s", ids.length);

        vm.startBroadcast(broadcasterPK);
        SynapseRouter router;
        address routerDeployment = loadDeploymentAddress(chain, ROUTER);
        if (routerDeployment == address(0)) {
            router = new SynapseRouter(bridge);
            saveDeployment(chain, ROUTER, address(router));
            for (uint256 i = 0; i < ids.length; ++i) {
                bytes memory rawConfig = config.parseRaw(_concat("tokens.", ids[i]));
                TokenConfig memory tokenConfig = abi.decode(rawConfig, (TokenConfig));
                console.log("Adding %s: %s", ids[i], tokenConfig.tokenType == 0 ? "Redeem" : "Deposit");
                console.log("Address: %s", tokenConfig.token);
                if (tokenConfig.token != tokenConfig.bridgeToken) {
                    console.log("Wrapper: %s", tokenConfig.bridgeToken);
                }
                router.addToken(
                    tokenConfig.token,
                    LocalBridgeConfig.TokenType(tokenConfig.tokenType),
                    tokenConfig.bridgeToken,
                    tokenConfig.bridgeFee,
                    uint256(tokenConfig.minFee),
                    uint256(tokenConfig.maxFee)
                );
            }
        } else {
            console.log("Skipping %s, deployed at %s", ROUTER, routerDeployment);
            router = SynapseRouter(payable(routerDeployment));
        }

        SwapQuoter quoter;
        address quoterDeployment = loadDeploymentAddress(chain, QUOTER);
        if (quoterDeployment == address(0)) {
            quoter = new SwapQuoter(address(router), address(wgas));
            saveDeployment(chain, QUOTER, address(quoter));
            quoter.addPools(pools);
            console.log("Pools added");
        } else {
            console.log("Skipping %s, deployed at %s", QUOTER, quoterDeployment);
            quoter = SwapQuoter(quoterDeployment);
        }

        if (router.swapQuoter() != quoter) {
            router.setSwapQuoter(quoter);
            console.log("%s set to %s", QUOTER, address(quoter));
        } else {
            console.log("%s already set up", QUOTER);
        }

        vm.stopBroadcast();
    }

    function deployAvax() external {
        deploy("avalanche");
    }

    function deployArb() external {
        deploy("arbitrum");
    }
}
