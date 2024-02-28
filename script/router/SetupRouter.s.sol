// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import {DeployScript} from "../utils/DeployScript.sol";

import {LocalBridgeConfig, SynapseRouter} from "../../contracts/bridge/router/SynapseRouter.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IBridge} from "./interfaces/IBridge.sol";

// solhint-disable no-console
contract SetupRouterScript is DeployScript {
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

    // TODO: Use new template scripts
    constructor() public {
        // Load deployer private key
        // setupPK("OWNER_PK");
        // Load chain name that block.chainid refers to
        loadChain();
    }

    function execute(bool _isBroadcasted) public override {
        string memory config = loadDeployConfig(ROUTER);
        _checkConfig(config);
        vm.startBroadcast();
        broadcasterAddress = msg.sender;
        router = SynapseRouter(payable(loadDeployment(ROUTER)));
        _setupRouter(config);
        _removeRouterTokens(config);
        vm.stopBroadcast();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: CONFIG                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _checkConfig(string memory config) internal {
        // Check Bridge
        address bridge = config.readAddress(".bridge");
        console.log("Checking Bridge: %s", bridge);
        require(bridge.isContract(), "Incorrect config: bridge");
        // Check WGAS
        address wgas = config.readAddress(".wgas");
        console.log("Checking   WGAS: %s", wgas);
        address bridgeETH = IBridge(bridge).WETH_ADDRESS();
        if (wgas != bridgeETH) {
            require(bridgeETH == address(0), "WGAS doesn't match Bridge");
            if (wgas == address(0)) {
                console.log("CHECK THIS! WGAS not set on %s", chain);
            } else {
                require(wgas.isContract(), "WGAS is not a contract");
                console.log("WGAS name: %s", ERC20(wgas).name());
            }
        }
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
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: ROUTER                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

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
            if (tokens.length != 0) {
                router.addTokens(tokens);
            } else {
                console.log("No tokens to update");
            }
        } else {
            _printSkipped("add tokens", ROUTER, owner);
        }
    }

    function _removeRouterTokens(string memory config) internal {
        address[] memory tokens = router.bridgeTokens();
        bool[] memory toRemove = new bool[](tokens.length);
        uint256 toRemoveAmount = 0;

        // Go though all tokens and mark the ones that are not in config to be removed
        string[] memory ids = config.readStringArray(".ids");
        for (uint256 i = 0; i < tokens.length; ++i) {
            bool found = false;
            for (uint256 j = 0; j < ids.length; ++j) {
                bytes memory rawConfig = config.parseRaw(_concat(".tokens.", ids[j]));
                TokenConfig memory tokenConfig = abi.decode(rawConfig, (TokenConfig));
                if (tokens[i] == tokenConfig.token) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                console.log("   Will be removing: %s", tokens[i]);
                toRemove[i] = true;
                ++toRemoveAmount;
            }
        }

        if (toRemoveAmount == 0) {
            console.log("No tokens to remove");
            return;
        }

        address[] memory removedTokens = new address[](toRemoveAmount);
        toRemoveAmount = 0;
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (toRemove[i]) {
                removedTokens[toRemoveAmount++] = tokens[i];
            }
        }

        // Check if broadcaster is the owner of SynapseRouter contract
        address owner = router.owner();
        if (owner == broadcasterAddress) {
            console.log("Removing %s tokens", toRemoveAmount);
            router.removeTokens(removedTokens);
        } else {
            _printSkipped("remove tokens", ROUTER, owner);
        }
    }

    function _scanTokens(string memory config) internal returns (uint256 missing) {
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
