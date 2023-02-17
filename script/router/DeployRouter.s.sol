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
        _deploySetupRouter(config);
        _deploySetupQuoter(config);
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
    function _deploySetupRouter(string memory config) internal {
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
        // Make sure that Router token config matches the provided config
        _setupRouter(config);
    }

    /// @dev Deploys SynapseRouter. Function is virtual to allow different deploy workflows.
    function _deployRouter(address bridge) internal virtual {
        bytes memory constructorArgs = abi.encode(bridge, broadcasterAddress);
        router = SynapseRouter(payable(deployBytecode(ROUTER, constructorArgs)));
    }

    /// @dev Configures SynapseRouter by adding all chain's bridge tokens.
    function _setupRouter(string memory config) internal {
        // Check if broadcaster is the owner of SynapseRouter contract
        address owner = router.owner();
        // Scan existing deployment to check how many tokens to we need to add
        uint256 missing = _scanTokens(config);
        string[] memory ids = config.readStringArray(".ids");
        LocalBridgeConfig.BridgeTokenConfig[] memory tokens = new LocalBridgeConfig.BridgeTokenConfig[](missing);
        // `missing` will now track the amount of found "missing tokens"
        missing = 0;
        for (uint256 i = 0; i < ids.length; ++i) {
            bytes memory rawConfig = config.parseRaw(_concat(".tokens.", ids[i]));
            TokenConfig memory tokenConfig = abi.decode(rawConfig, (TokenConfig));
            (, address bridgeToken) = router.config(tokenConfig.token);
            // Check if token is missing from Router config
            if (bridgeToken == address(0)) {
                _printAction("Adding", tokenConfig, ids[i]);
                _printAddress(tokenConfig);
                _printFees(tokenConfig, ids[i]);
                tokens[missing++] = LocalBridgeConfig.BridgeTokenConfig({
                    id: ids[i],
                    token: tokenConfig.token,
                    decimals: tokenConfig.decimals,
                    tokenType: LocalBridgeConfig.TokenType(tokenConfig.tokenType),
                    bridgeToken: tokenConfig.bridgeToken,
                    bridgeFee: tokenConfig.bridgeFee,
                    minFee: uint256(tokenConfig.minFee),
                    maxFee: uint256(tokenConfig.maxFee)
                });
                continue;
            }
            // Check if existing token fee structure is outdated
            if (_isOutdatedFee(tokenConfig)) {
                _printAction("Fixing", tokenConfig, ids[i]);
                _printFees(tokenConfig, ids[i]);
                if (owner == broadcasterAddress) {
                    router.setTokenFee(
                        tokenConfig.token,
                        tokenConfig.bridgeFee,
                        uint256(tokenConfig.minFee),
                        uint256(tokenConfig.maxFee)
                    );
                } else {
                    _printSkipped("adjust fee", ROUTER, owner);
                }
                continue;
            }
            // Token exists and fee structure is up to date
            _printAction("Exists", tokenConfig, ids[i]);
        }
        if (owner == broadcasterAddress) {
            router.addTokens(tokens);
        } else {
            _printSkipped("add tokens", ROUTER, owner);
        }
    }

    function _scanTokens(string memory config) internal view returns (uint256 missing) {
        string[] memory ids = config.readStringArray(".ids");
        for (uint256 i = 0; i < ids.length; ++i) {
            bytes memory rawConfig = config.parseRaw(_concat(".tokens.", ids[i]));
            TokenConfig memory tokenConfig = abi.decode(rawConfig, (TokenConfig));
            (LocalBridgeConfig.TokenType tokenType, address bridgeToken) = router.config(tokenConfig.token);
            if (bridgeToken == address(0)) {
                // Token is not added to SynapseRouter config
                ++missing;
                continue;
            }
            // tokenType and bridgeToken values need to be consistent throughout time
            // Unless their change is absolutely necessary
            require(bridgeToken == tokenConfig.bridgeToken, "Incorrect bridgeToken");
            require(uint8(tokenType) == tokenConfig.tokenType, "Incorrect tokenType");
        }
    }

    function _isOutdatedFee(TokenConfig memory tokenConfig) internal view returns (bool) {
        (uint40 bridgeFee, uint104 minFee, uint112 maxFee) = router.fee(tokenConfig.token);
        return
            bridgeFee != tokenConfig.bridgeFee ||
            minFee != uint256(tokenConfig.minFee) ||
            maxFee != uint256(tokenConfig.maxFee);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: QUOTER                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Deploys and configures SwapQuoter.
    function _deploySetupQuoter(string memory config) internal {
        console.log("=============== QUOTER ===============");
        // Read deploy params from the config
        address wgas = config.readAddress(".wgas");
        // Check if deployment already exists
        address quoterDeployment = tryLoadDeployment(QUOTER);
        if (quoterDeployment == address(0)) {
            _deployQuoter(wgas);
            _setupQuoter(config);
        } else {
            console.log("Skipping %s, deployed at %s", QUOTER, quoterDeployment);
            quoter = SwapQuoter(quoterDeployment);
        }
    }

    /// @dev Deploys SwapQuoter. Function is virtual to allow different deploy workflows.
    function _deployQuoter(address wgas) internal virtual {
        bytes memory constructorArgs = abi.encode(address(router), address(wgas), broadcasterAddress);
        quoter = SwapQuoter(deployBytecode(QUOTER, constructorArgs));
    }

    /// @dev Configures SwapQuoter by adding all chain's liquidity pools.
    function _setupQuoter(string memory config) internal {
        address[] memory pools = config.readAddressArray(".pools");
        quoter.addPools(pools);
        console.log("Pools added");
        // Check if Swap Quoter is setup correctly
        if (router.swapQuoter() != quoter) {
            address owner = router.owner();
            if (owner == broadcasterAddress) {
                router.setSwapQuoter(quoter);
                console.log("%s set to %s", QUOTER, address(quoter));
            } else {
                _printSkipped("set SwapQuoter", ROUTER, owner);
            }
        } else {
            console.log("%s already set up", QUOTER);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               LOGGING                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _printAction(
        string memory action,
        TokenConfig memory tokenConfig,
        string memory id
    ) internal view {
        console.log("%s: %s (%s)", action, id, tokenConfig.tokenType == 0 ? "Redeem" : "Deposit");
    }

    function _printAddress(TokenConfig memory tokenConfig) internal view {
        console.log("   Address: %s", tokenConfig.token);
        if (tokenConfig.token != tokenConfig.bridgeToken) {
            console.log("   Wrapper: %s", tokenConfig.bridgeToken);
        }
    }

    function _printFees(TokenConfig memory tokenConfig, string memory id) internal view {
        console.log("   Fee: %s (%s bps)", tokenConfig.bridgeFee, tokenConfig.bridgeFee / 10**6);
        console.log(
            "   Min: %s (%s %s)",
            uint256(tokenConfig.minFee),
            uint256(tokenConfig.minFee) / 10**tokenConfig.decimals,
            id
        );
        console.log(
            "   Max: %s (%s %s)",
            uint256(tokenConfig.maxFee),
            uint256(tokenConfig.maxFee) / 10**tokenConfig.decimals,
            id
        );
    }

    function _printSkipped(
        string memory action,
        string memory contractName,
        address owner
    ) internal view {
        console.log("Skipped [%s]: broadcaster is not the owner of %s. Use %s", action, contractName, owner);
    }
}
