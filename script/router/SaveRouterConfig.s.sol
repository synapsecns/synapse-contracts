// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import {SynapseScript} from "../utils/SynapseScript.sol";

import {BridgeConfigV3Lens, LocalBridgeConfig} from "../../contracts/bridge/utils/BridgeConfigV3Lens.sol";

contract SaveRouterConfigScript is BridgeConfigV3Lens, SynapseScript {
    using stdJson for string;

    uint256 internal constant METIS_CHAINID = 1088;

    string public constant ROUTER = "SynapseRouter";

    constructor() public {
        // Load chain name that block.chainid refers to
        loadChain();
    }

    function run() external {
        if (deployConfigExists(ROUTER)) {
            console.log("Skipping: deploy config for [%s] on [%s] already exists", ROUTER, chain);
            return;
        }
        address bridge = loadDeployment("SynapseBridge");
        // Apparently, METIS predeploy at 0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000
        // could be used as ERC20 token representing METIS, rendering the concept of WGAS useless on that chain.
        address wgas = _chainId() == METIS_CHAINID ? address(0) : loadDeployment("WGAS");

        string memory fullConfig = "full";
        string memory tokensConfig = "";
        fullConfig.serialize("bridge", bridge);
        fullConfig.serialize("wgas", wgas);

        // Save current chainId before switching to Mainnet
        uint256 chainId = _chainId();
        string memory ethRPC = vm.envString("ALCHEMY_API");
        vm.createSelectFork(ethRPC);
        (LocalBridgeConfig.BridgeTokenConfig[] memory tokens, address[] memory pools) = getChainConfig(chainId);
        string[] memory ids = new string[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            ids[i] = tokens[i].id;
            string memory token = tokens[i].id;
            token.serialize("token", tokens[i].token);
            token.serialize("decimals", tokens[i].decimals);
            token.serialize("tokenType", uint256(tokens[i].tokenType));
            token.serialize("bridgeToken", tokens[i].bridgeToken);
            token.serialize("bridgeFee", tokens[i].bridgeFee);
            token.serialize("minFee", bytes32(tokens[i].minFee));
            // Save JSON for a token
            token = token.serialize("maxFee", bytes32(tokens[i].maxFee));
            tokensConfig = string("tokens").serialize(tokens[i].id, token);
        }
        fullConfig.serialize("ids", ids);
        fullConfig.serialize("tokens", tokensConfig);
        fullConfig = fullConfig.serialize("pools", pools);

        saveDeployConfig(ROUTER, fullConfig);
    }
}
