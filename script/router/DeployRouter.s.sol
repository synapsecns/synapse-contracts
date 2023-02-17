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

    // Deployed contracts
    SynapseRouter internal router;
    SwapQuoter internal quoter;
    address internal owner;

    constructor() public {
        // Load deployer private key
        setupPK("ROUTER_DEPLOYER_PK");
        owner = loadAddress("OWNER_PK");
        // Load chain name that block.chainid refers to
        loadChain();
    }

    function execute(bool _isBroadcasted) public override {
        string memory config = loadDeployConfig(ROUTER);
        _checkConfig(config);
        startBroadcast(_isBroadcasted);
        _deployRouter(config);
        _deployQuoter(config);
        stopBroadcast();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: CONFIG                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _checkConfig(string memory config) internal view {
        // Check Bridge
        address bridge = config.readAddress(".bridge");
        console.log("Checking Bridge: %s", bridge);
        require(bridge.isContract(), "Incorrect config: bridge");
        // Check WGAS
        address wgas = config.readAddress(".wgas");
        console.log("Checking   WGAS: %s", wgas);
        require(wgas == address(0) || wgas.isContract(), "Incorrect config: wgas");
        console.log("=============== TOKENS ===============");
        // Check tokens
        string[] memory ids = config.readStringArray(".ids");
        for (uint256 i = 0; i < ids.length; ++i) {
            bytes memory rawConfig = config.parseRaw(_concat(".tokens.", ids[i]));
            TokenConfig memory tokenConfig = abi.decode(rawConfig, (TokenConfig));
            ERC20 token = ERC20(tokenConfig.token);
            console.log("Checking token: %s", address(token));
            // We're checking decimals, this should check if the provided address is ERC20 contract
            require(token.decimals() == tokenConfig.decimals, "Incorrect config: token");
        }
        console.log("===============  POOLS ===============");
        // Check pools
        address[] memory pools = config.readAddressArray(".pools");
        for (uint256 i = 0; i < pools.length; ++i) {
            console.log("Checking pool: %s", pools[i]);
            require(pools[i].isContract(), "Incorrect config: pool");
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: ROUTER                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Deploys and configures SynapseRouter.
    function _deployRouter(string memory config) internal {
        console.log("=============== ROUTER ===============");
        // Read deploy params from the config
        address bridge = config.readAddress(".bridge");
        // Check if the deployment already exists
        address routerDeployment = tryLoadDeployment(ROUTER);
        if (routerDeployment == address(0)) {
            _deployRouter(bridge);
        } else {
            console.log("Skipping %s, deployed at %s", ROUTER, routerDeployment);
            router = SynapseRouter(payable(routerDeployment));
        }
    }

    /// @dev Deploys SynapseRouter. Function is virtual to allow different deploy workflows.
    function _deployRouter(address bridge) internal virtual {
        bytes memory constructorArgs = abi.encode(bridge, owner);
        router = SynapseRouter(payable(deployBytecode(ROUTER, constructorArgs)));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: QUOTER                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Deploys and configures SwapQuoter.
    function _deployQuoter(string memory config) internal {
        console.log("=============== QUOTER ===============");
        // Read deploy params from the config
        address wgas = config.readAddress(".wgas");
        // Check if deployment already exists
        address quoterDeployment = tryLoadDeployment(QUOTER);
        if (quoterDeployment == address(0)) {
            _deployQuoter(wgas);
        } else {
            console.log("Skipping %s, deployed at %s", QUOTER, quoterDeployment);
            quoter = SwapQuoter(quoterDeployment);
        }
    }

    /// @dev Deploys SwapQuoter. Function is virtual to allow different deploy workflows.
    function _deployQuoter(address wgas) internal virtual {
        bytes memory constructorArgs = abi.encode(address(router), address(wgas), owner);
        quoter = SwapQuoter(deployBytecode(QUOTER, constructorArgs));
    }
}
