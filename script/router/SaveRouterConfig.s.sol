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

    mapping(string => bool) public isIgnoredId;
    string[] public ids;

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
        string memory ethRPC = vm.envString("MAINNET_API");
        vm.createSelectFork(ethRPC);
        (LocalBridgeConfig.BridgeTokenConfig[] memory tokens, address[] memory pools) = getChainConfig(chainId);

        _loadIgnoredIds();

        for (uint256 i = 0; i < tokens.length; ++i) {
            if (isIgnoredId[tokens[i].id]) {
                console.log("Skipping: %s", tokens[i].id);
                continue;
            }
            ids.push(tokens[i].id);
            string memory token = tokens[i].id;
            token.serialize("token", tokens[i].token);
            token.serialize("decimals", tokens[i].decimals);
            token.serialize("tokenType", uint256(tokens[i].tokenType));
            token.serialize("bridgeToken", tokens[i].bridgeToken);
            token.serialize("bridgeFee", tokens[i].bridgeFee);
            token.serialize("minFee", bytes32(tokens[i].minFee));
            // Set caps for minFee/maxFee
            if (tokens[i].minFee > type(uint104).max) tokens[i].minFee = type(uint104).max;
            if (tokens[i].maxFee > type(uint112).max) tokens[i].maxFee = type(uint112).max;
            // Save JSON for a token
            token = token.serialize("maxFee", bytes32(tokens[i].maxFee));
            tokensConfig = string("tokens").serialize(tokens[i].id, token);
        }
        fullConfig.serialize("ids", ids);
        fullConfig.serialize("tokens", tokensConfig);
        fullConfig = fullConfig.serialize("pools", pools);

        saveDeployConfig(ROUTER, fullConfig);
    }

    function _loadIgnoredIds() internal {
        string memory ignored = loadGlobalConfig("SynapseRouter.ignored");
        string[] memory _ids = ignored.readStringArray(".ids");
        for (uint256 i = 0; i < _ids.length; ++i) {
            isIgnoredId[_ids[i]] = true;
        }
    }
}
