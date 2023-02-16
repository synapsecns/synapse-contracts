// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import {BaseScript} from "../utils/BaseScript.sol";

import {LocalBridgeConfig, SynapseRouter} from "../../contracts/bridge/router/SynapseRouter.sol";
import {SwapQuoter} from "../../contracts/bridge/router/SwapQuoter.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract DeployRouterScript is BaseScript {
    using Address for address;
    using stdJson for string;

    // Alphabetical order to get the JSON parsing working
    struct TokenConfig {
        uint256 bridgeFee;
        address bridgeToken;
        uint256 decimals;
        bytes32 maxFee;
        bytes32 minFee;
        address token;
        uint256 tokenType;
    }

    string public constant ROUTER = "SynapseRouter";
    string public constant QUOTER = "SwapQuoter";

    constructor() public {
        // Load deployer private key
        setupDeployerPK();
        // Load chain name that block.chainid refers to
        loadChain();
    }

    function execute(bool _isBroadcasted) public override {
        string memory config = loadDeployConfig(ROUTER);
        _checkConfig(config);
        startBroadcast(_isBroadcasted);
        SynapseRouter router = _deploySetupRouter(config);
        SwapQuoter quoter = _deploySetupQuoter(config, router);
        // Check if Swap Quoter is setup correctly
        if (router.swapQuoter() != quoter) {
            router.setSwapQuoter(quoter);
            console.log("%s set to %s", QUOTER, address(quoter));
        } else {
            console.log("%s already set up", QUOTER);
        }
        stopBroadcast();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: CONFIG                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _checkConfig(string memory config) internal view {
        // Check Bridge
        address bridge = config.readAddress("bridge");
        console.log("Checking Bridge: %s", bridge);
        require(bridge.isContract(), "Incorrect config: bridge");
        // Check WGAS
        address wgas = config.readAddress("wgas");
        console.log("Checking   WGAS: %s", wgas);
        require(wgas == address(0) || wgas.isContract(), "Incorrect config: wgas");
        console.log("=============== TOKENS ===============");
        // Check tokens
        string[] memory ids = config.readStringArray("ids");
        for (uint256 i = 0; i < ids.length; ++i) {
            bytes memory rawConfig = config.parseRaw(_concat("tokens.", ids[i]));
            TokenConfig memory tokenConfig = abi.decode(rawConfig, (TokenConfig));
            ERC20 token = ERC20(tokenConfig.token);
            console.log("Checking token: %s", address(token));
            // We're checking decimals, this should check if the provided address is ERC20 contract
            require(token.decimals() == tokenConfig.decimals, "Incorrect config: token");
        }
        console.log("===============  POOLS ===============");
        // Check pools
        address[] memory pools = config.readAddressArray("pools");
        for (uint256 i = 0; i < pools.length; ++i) {
            console.log("Checking pool: %s", pools[i]);
            require(pools[i].isContract(), "Incorrect config: pool");
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: ROUTER                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Deploys and configures SynapseRouter.
    function _deploySetupRouter(string memory config) internal returns (SynapseRouter router) {
        console.log("=============== ROUTER ===============");
        // Read deploy params from the config
        address bridge = config.readAddress("bridge");
        // Check if the deployment already exists
        address routerDeployment = tryLoadDeployment(ROUTER);
        if (routerDeployment == address(0)) {
            router = _deployRouter(bridge);
            _setupRouter(config, router);
        } else {
            console.log("Skipping %s, deployed at %s", ROUTER, routerDeployment);
            router = SynapseRouter(payable(routerDeployment));
        }
    }

    /// @dev Deploys SynapseRouter. Function is virtual to allow different deploy workflows.
    function _deployRouter(address bridge) internal virtual returns (SynapseRouter router) {
        router = new SynapseRouter(bridge, broadcasterAddress);
        saveDeployment(ROUTER, address(router));
    }

    /// @dev Configures SynapseRouter by adding all chain's bridge tokens.
    function _setupRouter(string memory config, SynapseRouter router) internal {
        string[] memory ids = config.readStringArray("ids");
        LocalBridgeConfig.BridgeTokenConfig[] memory tokens = new LocalBridgeConfig.BridgeTokenConfig[](ids.length);
        for (uint256 i = 0; i < ids.length; ++i) {
            bytes memory rawConfig = config.parseRaw(_concat("tokens.", ids[i]));
            TokenConfig memory tokenConfig = abi.decode(rawConfig, (TokenConfig));
            console.log("Adding %s: %s", ids[i], tokenConfig.tokenType == 0 ? "Redeem" : "Deposit");
            console.log("Address: %s", tokenConfig.token);
            if (tokenConfig.token != tokenConfig.bridgeToken) {
                console.log("Wrapper: %s", tokenConfig.bridgeToken);
            }
            tokens[i] = LocalBridgeConfig.BridgeTokenConfig({
                id: ids[i],
                token: tokenConfig.token,
                decimals: tokenConfig.decimals,
                tokenType: LocalBridgeConfig.TokenType(tokenConfig.tokenType),
                bridgeToken: tokenConfig.bridgeToken,
                bridgeFee: tokenConfig.bridgeFee,
                minFee: uint256(tokenConfig.minFee),
                maxFee: uint256(tokenConfig.maxFee)
            });
        }
        router.addTokens(tokens);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: QUOTER                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Deploys and configures SwapQuoter.
    function _deploySetupQuoter(string memory config, SynapseRouter router) internal returns (SwapQuoter quoter) {
        console.log("=============== QUOTER ===============");
        // Read deploy params from the config
        address wgas = config.readAddress("wgas");
        // Check if deployment already exists
        address quoterDeployment = tryLoadDeployment(QUOTER);
        if (quoterDeployment == address(0)) {
            quoter = _deployQuoter(router, wgas);
            _setupQuoter(config, quoter);
        } else {
            console.log("Skipping %s, deployed at %s", QUOTER, quoterDeployment);
            quoter = SwapQuoter(quoterDeployment);
        }
    }

    /// @dev Deploys SwapQuoter. Function is virtual to allow different deploy workflows.
    function _deployQuoter(SynapseRouter router, address wgas) internal virtual returns (SwapQuoter quoter) {
        quoter = new SwapQuoter(address(router), address(wgas), broadcasterAddress);
        saveDeployment(QUOTER, address(quoter));
    }

    /// @dev Configures SwapQuoter by adding all chain's liquidity pools.
    function _setupQuoter(string memory config, SwapQuoter quoter) internal {
        address[] memory pools = config.readAddressArray("pools");
        quoter.addPools(pools);
        console.log("Pools added");
    }
}
