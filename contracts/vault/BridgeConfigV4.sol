// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import {IBridgeConfig} from "./interfaces/IBridgeConfig.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable-solc8/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable-solc8/access/AccessControlUpgradeable.sol";

contract BridgeConfig is
    Initializable,
    AccessControlUpgradeable,
    IBridgeConfig
{
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant NODEGROUP_ROLE = keccak256("NODEGROUP_ROLE");

    /// @dev List of tokenLocal
    address[] public bridgeTokens;

    /// @dev [tokenLocal => config]
    mapping(address => TokenConfig) public tokenConfigs;

    mapping(address => uint256[]) internal tokenChainIds;

    /// @dev [tokenLocal => [chainID => tokenGlobal]]
    mapping(address => mapping(uint256 => address)) internal localMapEVM;

    /// @dev [chainID => [tokenGlobal => tokenLocal]]
    mapping(uint256 => mapping(address => address)) internal globalMapEVM;

    /// @dev [chainID => [tokenGlobal => tokenLocal]]
    mapping(uint256 => mapping(string => address)) internal globalMapNonEVM;

    uint256 internal constant FEE_DENOMINATOR = 10**10;
    uint256 internal constant UINT_MAX = type(uint256).max;

    function initialize() external initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // -- VIEWS --

    /**
     * @notice Calculates Synapse: Bridge fee for a token.
     * @param token Bridged token.
     * @param amount Amount of bridged tokens, in `token` decimals.
     * @param gasdropRequested Whether user requested a gas airdrop (in that case minimum fee is higher).
     * @param amountOfSwaps Amount of swaps after bridging (minimum fee is higher when amount is higher).
     * @return fee Total Synapse: Bridge fee, in `token` decimals.
     * @return bridgeToken Contract used for bridging `token` on this chain.
     * @return isEnabled Whether bridging of `token` is enabled on this chain.
     * @return isMintBurn Whether `token` is bridged on this chain by mint/burn or withdraw/deposit.
     */
    function calculateBridgeFee(
        address token,
        uint256 amount,
        bool gasdropRequested,
        uint256 amountOfSwaps
    )
        external
        view
        returns (
            uint256 fee,
            address bridgeToken,
            bool isEnabled,
            bool isMintBurn
        )
    {
        TokenConfig memory config = tokenConfigs[token];
        if (config.tokenType != TokenType.UNKNOWN && config.isEnabled) {
            uint256 minFee = config.minBridgeFee +
                (gasdropRequested ? config.minGasDropFee : 0) +
                (amountOfSwaps > 0 ? config.minSwapFee : 0);

            fee = (amount * config.synapseFee) / FEE_DENOMINATOR;

            if (minFee > fee) {
                fee = minFee;
            } else if (fee > config.maxTotalFee) {
                fee = config.maxTotalFee;
            }

            bridgeToken = config.bridgeToken;
            isEnabled = true;
            isMintBurn = config.tokenType == TokenType.MINT_BURN;
        }
    }

    /**
     * @notice Get bridge token information.
     * @dev Most of the time, `token == bridgeToken`. Another contract is used when token.mint(to, amount)
     * or token.burn(amount) are impossible to call.
     * In that case, `bridgeToken` should implement such functions to perform mint/burn of `token`.
     * The concept of `bridgeToken` is isolated in `Bridge` entirely.
     * No one outside of `Bridge` needs to know how exactly `token` is being bridged.
     * @param token Bridged token.
     * @return bridgeToken Contract used for bridging `token` on this chain.
     * @return isEnabled Whether bridging of `token` is enabled on this chain.
     * @return isMintBurn Whether `token` is bridged on this chain by mint/burn or deposit/withdraw.
     */
    function getBridgeToken(address token)
        external
        view
        returns (
            address bridgeToken,
            bool isEnabled,
            bool isMintBurn
        )
    {
        TokenConfig memory config = tokenConfigs[token];
        bridgeToken = config.bridgeToken;
        isEnabled = config.isEnabled;
        isMintBurn = config.tokenType == TokenType.MINT_BURN;
    }

    /**
     * @notice Get information about token address on another EVM chain.
     * @param tokenLocal Bridged token address on this chain.
     * @param chainId Id of EVM chain to get information about.
     * @return tokenGlobal Token address on requested chain.
     * @return isEnabled Whether bridging of `token` is enabled on this chain.
     */
    function getTokenAddressEVM(address tokenLocal, uint256 chainId)
        external
        view
        returns (address tokenGlobal, bool isEnabled)
    {
        tokenGlobal = localMapEVM[tokenLocal][chainId];
        if (tokenGlobal != address(0)) {
            isEnabled = tokenConfigs[tokenLocal].isEnabled;
        }
    }

    /**
     * @notice Get information about token address on non-EVM chain.
     * @param tokenLocal Bridged token address on this chain.
     * @param chainId Id of non-EVM chain to get information about.
     * @return tokenGlobal Token address on requested chain.
     * @return isEnabled Whether bridging of `token` is enabled on this chain.
     */
    function getTokenAddressNonEVM(address tokenLocal, uint256 chainId)
        external
        view
        returns (string memory tokenGlobal, bool isEnabled)
    {
        TokenConfig memory config = tokenConfigs[tokenLocal];
        if (config.chainIdNonEVM == chainId) {
            tokenGlobal = tokenConfigs[tokenLocal].bridgeTokenNonEVM;
            if (bytes(tokenGlobal).length > 0) {
                isEnabled = tokenConfigs[tokenLocal].isEnabled;
            }
        }
    }

    function getTokenChainIds(address tokenLocal)
        external
        view
        returns (uint256[] memory chainIds)
    {
        chainIds = tokenChainIds[tokenLocal];
    }

    /**
     * @notice Find address of given token from EVM chain on this chain.
     * @param chainId Id of EVM chain.
     * @param tokenGlobal Token address on EVM chain.
     * @return tokenLocal Bridge token address on this chain.
     */
    function findTokenEVM(uint256 chainId, address tokenGlobal)
        external
        view
        returns (address tokenLocal)
    {
        tokenLocal = globalMapEVM[chainId][tokenGlobal];
    }

    /**
     * @notice Find address of given token from non-EVM chain on this chain.
     * @param chainId Id of non-EVM chain.
     * @param tokenGlobal Token address on non-EVM chain.
     * @return tokenLocal Bridge token address on this chain.
     */
    function findTokenNonEVM(uint256 chainId, string calldata tokenGlobal)
        external
        view
        returns (address tokenLocal)
    {
        tokenLocal = globalMapNonEVM[chainId][tokenGlobal];
    }

    /**
     * @notice Get a list of tokens bridgeable between current and a given EVM chain.
     * @param chainTo EVM chain to bridge to.
     * @return tokensLocal Bridge token addresses on this chain.
     * @return tokensGlobal Bridge token addresses on `chainTo`.
     */
    function getAllBridgeTokensEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, address[] memory tokensGlobal)
    {
        uint256 amountTo = 0;

        uint256 amountFull = bridgeTokens.length;
        for (uint256 i = 0; i < amountFull; ++i) {
            if (localMapEVM[bridgeTokens[i]][chainTo] != address(0)) {
                ++amountTo;
            }
        }

        tokensLocal = new address[](amountTo);
        tokensGlobal = new address[](amountTo);
        amountTo = 0;

        for (uint256 i = 0; i < amountFull; ++i) {
            address tokenLocal = bridgeTokens[i];
            address tokenGlobal = localMapEVM[tokenLocal][chainTo];
            if (tokenGlobal != address(0)) {
                tokensLocal[amountTo] = tokenLocal;
                tokensGlobal[amountTo] = tokenGlobal;
                ++amountTo;
            }
        }
    }

    /**
     * @notice Get a list of tokens bridgeable between current and a given non-EVM chain.
     * @param chainTo Non-EVM chain to bridge to.
     * @return tokensLocal Bridge token addresses on this chain.
     * @return tokensGlobal Bridge token addresses on `chainTo`.
     */
    function getAllBridgeTokensNonEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, string[] memory tokensGlobal)
    {
        uint256 amountTo = 0;

        uint256 amountFull = bridgeTokens.length;
        for (uint256 i = 0; i < amountFull; ++i) {
            if (tokenConfigs[bridgeTokens[i]].chainIdNonEVM == chainTo) {
                ++amountTo;
            }
        }

        tokensLocal = new address[](amountTo);
        tokensGlobal = new string[](amountTo);
        amountTo = 0;

        for (uint256 i = 0; i < amountFull; ++i) {
            address tokenLocal = bridgeTokens[i];
            TokenConfig memory config = tokenConfigs[tokenLocal];
            if (config.chainIdNonEVM == chainTo) {
                tokensLocal[amountTo] = tokenLocal;
                tokensGlobal[amountTo] = config.bridgeTokenNonEVM;
                ++amountTo;
            }
        }
    }

    /**
     * @notice Check is bridging for given token is currently enabled.
     * @param bridgeToken Token in question.
     */
    function isTokenEnabled(address bridgeToken) external view returns (bool) {
        return tokenConfigs[bridgeToken].isEnabled;
    }

    // -- BRIDGE CONFIG: swap fees --

    /**
     * @notice Add a new Bridge token config. Called by Governance only.
     * @dev This will revert if a token has been added before, use {updateTokenFees},
     * {updateTokenSetup} to update things later.
     * @param token Token to add: the version that is used on this chain.
     * @param bridgeToken Bridge token that will be used for bridging `token`.
     * @param isMintBurn Specifies if token is bridged via mint-burn or deposit-withdraw.
     * @param synapseFee Synapse:Bridge fee value(i.e. 0.1%), multiplied by `FEE_DENOMINATOR`.
     * @param maxTotalFee Maximum total bridge fee, in `token` decimals.
     * @param minBridgeFee Minimum fee covering bridging in (always present), in `token` decimals.
     * @param minGasDropFee Minimum fee covering covering GasDrop (when GasDrop is present), in `token` decimals.
     * @param minSwapFee Minimum fee covering covering further swap (when swap is present), in `token` decimals.
     */
    function addNewToken(
        address token,
        address bridgeToken,
        bool isMintBurn,
        uint256 synapseFee,
        uint256 maxTotalFee,
        uint256 minBridgeFee,
        uint256 minGasDropFee,
        uint256 minSwapFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(
            tokenConfigs[token].tokenType == TokenType.UNKNOWN,
            "Token already added"
        );
        bridgeTokens.push(token);

        _updateTokenSetup(token, bridgeToken, isMintBurn);
        updateTokenFees(
            token,
            synapseFee,
            maxTotalFee,
            minBridgeFee,
            minGasDropFee,
            minSwapFee
        );
    }

    /**
     * @notice Update an existing `token` setup. Called by Governance only.
     * @dev This will revert if `token` wasn't added before.
     * @param token Token to add: the version that is used on this chain
     * @param bridgeToken Bridge token that will be used for bridging `token`
     * @param isMintBurn Specifies if token is bridged via mint-burn or deposit-withdraw
     */
    function updateTokenSetup(
        address token,
        address bridgeToken,
        bool isMintBurn
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(
            tokenConfigs[token].tokenType != TokenType.UNKNOWN,
            "Token not added"
        );

        _updateTokenSetup(token, bridgeToken, isMintBurn);
    }

    function _updateTokenSetup(
        address token,
        address bridgeToken,
        bool isMintBurn
    ) internal {
        TokenConfig memory config = tokenConfigs[token];

        config.bridgeToken = bridgeToken;
        config.tokenType = isMintBurn
            ? TokenType.MINT_BURN
            : TokenType.DEPOSIT_WITHDRAW;

        tokenConfigs[token] = config;

        emit TokenSetupUpdated(token, bridgeToken, isMintBurn);
    }

    /**
     * @notice Update an existing `token` fees. Called by Governance only.
     * @param token Token to add: the version that is used on this chain.
     * @param synapseFee Synapse:Bridge fee value(i.e. 0.1%), multiplied by `FEE_DENOMINATOR`.
     * @param maxTotalFee Maximum total bridge fee, in `token` decimals.
     * @param minBridgeFee Minimum fee covering bridging in (always present), in `token` decimals.
     * @param minGasDropFee Minimum fee covering covering GasDrop (when GasDrop is present), in `token` decimals.
     * @param minSwapFee Minimum fee covering covering further swap (when swap is present), in `token` decimals.
     */
    function updateTokenFees(
        address token,
        uint256 synapseFee,
        uint256 maxTotalFee,
        uint256 minBridgeFee,
        uint256 minGasDropFee,
        uint256 minSwapFee
    ) public onlyRole(GOVERNANCE_ROLE) {
        TokenConfig memory config = tokenConfigs[token];
        require(config.tokenType != TokenType.UNKNOWN, "Token not added");

        config.synapseFee = synapseFee;
        config.maxTotalFee = maxTotalFee;
        config.minBridgeFee = minBridgeFee;
        config.minGasDropFee = minGasDropFee;
        config.minSwapFee = minSwapFee;

        tokenConfigs[token] = config;

        emit TokenFeesUpdated(
            token,
            synapseFee,
            maxTotalFee,
            minBridgeFee,
            minGasDropFee,
            minSwapFee
        );
    }

    // -- BRIDGE CONFIG: Token Map (Governance) --

    /**
     * @notice Adds a new token Map. Called by Governance only.
     * @dev This will emit TokenMapUpdated Event, which Validators are supposed to relay
     * to other chains.
     * This will revert if:
     * 1. Current chain ID is not present in the list.
     * 2. Token wasn't added via {addNewBridgeToken}.
     * 3. Map was already added, use {addChainsToMap} to update it later.
     * @param chainIdsEVM IDs of all EVM chains token is deployed on, INCLUDING current one.
     * @param bridgeTokensEVM Token addresses on all EVM chains token is deployed on, INCLUDING current one.
     * @param chainIdNonEVM ID of non-EVM chain, token is deployed on. Zero, if not deployed.
     * @param bridgeTokenNonEVM Address of token on non-EVM chain. Ignored, if `chainIdNonEVM==0`.
     */
    function addNewMap(
        uint256[] calldata chainIdsEVM,
        address[] calldata bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string calldata bridgeTokenNonEVM
    ) external onlyRole(GOVERNANCE_ROLE) {
        _checkConfigEVM(chainIdsEVM, bridgeTokensEVM);
        _updateMap(
            chainIdsEVM,
            bridgeTokensEVM,
            chainIdNonEVM,
            bridgeTokenNonEVM,
            true
        );

        // We were given the full token map, will emit it, so that
        // Bridge.addToMap() can be called by the Node Group on other chains
        emit TokenMapUpdated(
            chainIdsEVM,
            bridgeTokensEVM,
            chainIdNonEVM,
            bridgeTokenNonEVM
        );
    }

    /**
     * @notice Adds chains to an existing token Map. Called by Governance only.
     * @dev This will emit `TokenMapUpdated` Event, which Validators are supposed to relay
     * to other chains, both old and new ones.
     * This will revert if:
     * 1. Token wasn't added via {addNewBridgeToken}.
     * 2. Map wasn't added via {addNewMap} or {updateMap}.
     * @param token Token to update: the version that is used on this chain.
     * @param newChainIdsEVM IDs of NEW EVM chains token is deployed on. This excludes any old chains.
     * @param newBridgeTokensEVM Token addresses on NEW EVM chains token is deployed on. This excludes any old chains.
     * @param chainIdNonEVM ID of NEW non-EVM chain, token is deployed on. Ignored, if zero.
     * @param bridgeTokenNonEVM Address of token on NEW non-EVM chain. Ignored, if `chainIdNonEVM==0`.
     */
    function addChainsToMap(
        address token,
        uint256[] calldata newChainIdsEVM,
        address[] calldata newBridgeTokensEVM,
        uint256 chainIdNonEVM,
        string calldata bridgeTokenNonEVM
    ) external onlyRole(GOVERNANCE_ROLE) {
        _checkConfigEVM(newChainIdsEVM, newBridgeTokensEVM);
        require(tokenChainIds[token].length != 0, "Token map not created");

        _updateTokenMap(
            token,
            newChainIdsEVM,
            newBridgeTokensEVM,
            chainIdNonEVM,
            bridgeTokenNonEVM
        );

        // tokenChainIds[token] now contains both old and new chainIds
        address[] memory allTokenAddresses = _getAllTokenAddressesEVM(token);

        // Use both old and new chains in the emitted Event
        emit TokenMapUpdated(
            tokenChainIds[token],
            allTokenAddresses,
            tokenConfigs[token].chainIdNonEVM,
            tokenConfigs[token].bridgeTokenNonEVM
        );
    }

    /**
     * @notice Enable/Disable token bridging. Called by Governance only.
     * @dev This will emit `TokenStatusUpdated`, which Validators are supposed to relay
     * to other chains. Wil not emit anything, if token status hasn't changed.
     * This will revert if:
     * 1. Token wasn't added via {addNewBridgeToken}.
     * 2. Map wasn't added via {addNewMap} or {updateMap}.
     * @param token Token to toggle: the version that is used on this chain.
     * @param isEnabled New token Bridge status.
     */
    function changeTokenStatus(address token, bool isEnabled)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        if (_changeTokenStatus(token, isEnabled)) {
            address[] memory allTokenAddresses = _getAllTokenAddressesEVM(
                token
            );

            emit TokenStatusUpdated(
                tokenChainIds[token],
                allTokenAddresses,
                isEnabled
            );
        }
    }

    /**
     * @notice Delete this chain's version of token from Bridge on all chains.
     * Other chains' version of token will remain. Called by Governance only.
     * @dev This will emit `TokenDeleted`, which validators are supposed to relay
     * to other chains. This will revert if
     * 1. Token wasn't added via {addNewBridgeToken}.
     * @param token Token to delete: the version that is used on this chain.
     */
    function deleteTokenEVM(address token) external onlyRole(GOVERNANCE_ROLE) {
        uint256[] memory chainIds = tokenChainIds[token];
        _deleteTokenEVM(token);

        emit TokenDeleted(chainIds, block.chainid, address(token));
    }

    /**
     * @notice Delete given chain's version of token from Bridge on all chains.
     * Other chains' version of token will remain. Called by Governance only.
     * @param chainId Id of chain where token (being deleted) is deployed.
     * @param tokenGlobal Token to delete: the given that is used on given chain.
     */
    function removeGlobalTokenEVM(uint256 chainId, address tokenGlobal)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        uint256[] memory chainIds = _removeGlobalTokenEVM(chainId, tokenGlobal);

        emit TokenDeleted(chainIds, chainId, tokenGlobal);
    }

    // -- BRIDGE CONFIG: Token Map (Node Group) --

    /**
     * @notice Adds chains to an existing token Map. Called by Node Group only.
     * @dev This will NOT overwrite data for chains already existing in Map.
     * This will revert if:
     * 1. Current chain ID is not present in the list.
     * 2. Token wasn't added via {addNewBridgeToken}.
     * @param chainIdsEVM IDs of all EVM chains token is deployed on, INCLUDING current one.
     * @param bridgeTokensEVM Token addresses on all EVM chains token is deployed on, INCLUDING current one.
     * @param chainIdNonEVM ID of non-EVM chain, token is deployed on. Zero, if not deployed.
     * @param bridgeTokenNonEVM Address of token on non-EVM chain. Ignored, if `chainIdNonEVM==0`.
     */
    function updateMap(
        uint256[] calldata chainIdsEVM,
        address[] calldata bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string calldata bridgeTokenNonEVM
    ) external onlyRole(NODEGROUP_ROLE) {
        _checkConfigEVM(chainIdsEVM, bridgeTokensEVM);
        _updateMap(
            chainIdsEVM,
            bridgeTokensEVM,
            chainIdNonEVM,
            bridgeTokenNonEVM,
            false
        );

        // DO NOT emit anything, as this is a relayed setup tx
    }

    /**
     * @notice Enable/Disable token bridging. Called by Node Group only.
     * @dev This will revert if:
     * 1. Token wasn't added via {addNewBridgeToken}.
     * 2. Map wasn't added via {addNewMap} or {updateMap}.
     * @param token Token to toggle: the version that is used on this chain.
     * @param isEnabled New token Bridge status.
     */
    function updateTokenStatus(address token, bool isEnabled)
        external
        onlyRole(NODEGROUP_ROLE)
    {
        _changeTokenStatus(token, isEnabled);

        // DO NOT emit anything, as this is a relayed setup tx
    }

    function removeTokenEVM(uint256 chainId, address tokenAddress)
        external
        onlyRole(NODEGROUP_ROLE)
    {
        // Check if current chain is the specified one for deleting
        if (chainId == block.chainid) {
            // delete token entirely on this chain
            _deleteTokenEVM(tokenAddress);
        } else {
            // remove records about token on given chain
            _removeGlobalTokenEVM(chainId, tokenAddress);
        }

        // DO NOT emit anything, as this is a relayed deletion tx
    }

    /**
     * @dev Checks whether provided arrays length match,
     * also checks for blank values.
     */
    function _checkConfigEVM(
        uint256[] calldata chainIdsEVM,
        address[] calldata bridgeTokensEVM
    ) internal pure {
        require(
            bridgeTokensEVM.length == chainIdsEVM.length,
            "Arrays length differs"
        );
        for (uint256 i = 0; i < chainIdsEVM.length; ++i) {
            require(chainIdsEVM[i] != 0, "Zero chainId is setup");
            require(bridgeTokensEVM[i] != address(0), "Zero token in setup");
        }
    }

    function _getAllTokenAddressesEVM(address token)
        internal
        view
        returns (address[] memory allTokenAddresses)
    {
        uint256[] memory chainIds = tokenChainIds[token];
        uint256 amount = chainIds.length;
        allTokenAddresses = new address[](amount);

        for (uint256 i = 0; i < amount; i++) {
            allTokenAddresses[i] = localMapEVM[token][chainIds[i]];
        }
    }

    // -- BRIDGE CONFIG: token setup (internal implementation) --

    function _changeTokenStatus(address token, bool isEnabled)
        internal
        returns (bool)
    {
        TokenConfig memory config = tokenConfigs[token];
        require(config.tokenType != TokenType.UNKNOWN, "Token not added");
        require(tokenChainIds[token].length != 0, "Token map not created");

        if (config.isEnabled == isEnabled) {
            // Y U DO DIS
            return false;
        }

        tokenConfigs[token].isEnabled = isEnabled;
        return true;
    }

    function _findLocalToken(
        uint256[] calldata chainIdsEVM,
        address[] calldata bridgeTokensEVM
    ) internal view returns (address token) {
        // Find bridge token address on this chain
        for (uint256 i = 0; i < chainIdsEVM.length; i++) {
            if (chainIdsEVM[i] == block.chainid) {
                token = bridgeTokensEVM[i];
                break;
            }
        }
        require(token != address(0), "Local chain not found in list");
    }

    function _updateMap(
        uint256[] calldata chainIdsEVM,
        address[] calldata bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string calldata bridgeTokenNonEVM,
        bool checkEmpty
    ) internal {
        address tokenLocal = _findLocalToken(chainIdsEVM, bridgeTokensEVM);
        require(
            !checkEmpty || tokenChainIds[tokenLocal].length == 0,
            "Token map already created"
        );
        _updateTokenMap(
            tokenLocal,
            chainIdsEVM,
            bridgeTokensEVM,
            chainIdNonEVM,
            bridgeTokenNonEVM
        );
    }

    function _updateTokenMap(
        address tokenLocal,
        uint256[] calldata chainIdsEVM,
        address[] calldata bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string calldata bridgeTokenNonEVM
    ) internal {
        TokenConfig memory config = tokenConfigs[tokenLocal];
        require(config.tokenType != TokenType.UNKNOWN, "Token not added");

        for (uint256 i = 0; i < chainIdsEVM.length; i++) {
            uint256 chainId = chainIdsEVM[i];
            // Add chain to the map, only if it is currently missing
            if (localMapEVM[tokenLocal][chainId] == address(0)) {
                address tokenGlobal = bridgeTokensEVM[i];
                localMapEVM[tokenLocal][chainId] = tokenGlobal;
                globalMapEVM[chainId][tokenGlobal] = tokenLocal;
                tokenChainIds[tokenLocal].push(chainId);
            }
        }

        if (chainIdNonEVM != 0) {
            // Need to setup non-EVM chain
            if (config.chainIdNonEVM == 0) {
                // If token doesn't have non-EVM chain setup, use provided variables.
                globalMapNonEVM[chainIdNonEVM][bridgeTokenNonEVM] = tokenLocal;
                config.chainIdNonEVM = chainIdNonEVM;
                config.bridgeTokenNonEVM = bridgeTokenNonEVM;

                tokenConfigs[tokenLocal] = config;
            } else {
                // If token already has non-EVM chain setup, check that it's the same chain.
                require(
                    config.chainIdNonEVM == chainIdNonEVM,
                    "Deployed on other non-EVM"
                );
                require(
                    keccak256(bytes(config.bridgeTokenNonEVM)) ==
                        keccak256(bytes(bridgeTokenNonEVM)),
                    "Wrong non-EVM token address"
                );
            }
        }
    }

    function _deleteTokenEVM(address tokenLocal) internal {
        TokenConfig memory config = tokenConfigs[tokenLocal];
        require(config.tokenType != TokenType.UNKNOWN, "Token not added");

        {
            uint256 index = UINT_MAX;
            uint256 tokensAmount = bridgeTokens.length;
            for (uint256 i = 0; i < tokensAmount; ++i) {
                if (bridgeTokens[i] == tokenLocal) {
                    index = i;
                    break;
                }
            }

            require(index != UINT_MAX, "Bridge token not found in list");

            // Replace found token with the last one
            bridgeTokens[index] = bridgeTokens[tokensAmount - 1];
            // Remove now duplicated last token from list
            bridgeTokens.pop();
        }

        uint256[] memory chainIds = tokenChainIds[tokenLocal];
        uint256 chainAmount = chainIds.length;
        for (uint256 i = 0; i < chainAmount; ++i) {
            uint256 chainId = chainIds[i];
            address tokenGlobal = localMapEVM[tokenLocal][chainIds[i]];

            localMapEVM[tokenLocal][chainId] = address(0);
            globalMapEVM[chainId][tokenGlobal] = address(0);
        }

        // Delete both token config and token chainIds
        delete tokenChainIds[tokenLocal];
        delete tokenConfigs[tokenLocal];
    }

    function _removeGlobalTokenEVM(uint256 chainId, address tokenGlobal)
        internal
        returns (uint256[] memory chainIds)
    {
        address tokenLocal = globalMapEVM[chainId][tokenGlobal];
        require(tokenLocal != address(0), "Token doesn't exist");

        chainIds = tokenChainIds[tokenLocal];

        {
            uint256 index = UINT_MAX;
            uint256 chainsAmount = chainIds.length;
            for (uint256 i = 0; i < chainsAmount; ++i) {
                if (chainIds[i] == chainId) {
                    index = i;
                    break;
                }
            }

            require(index != UINT_MAX, "Given chain not found in list");

            // Replace found chain with the last one
            tokenChainIds[tokenLocal][index] = chainIds[chainsAmount - 1];
            // Remove last chain from list, which is now duplicated
            tokenChainIds[tokenLocal].pop();
        }

        localMapEVM[tokenLocal][chainId] = address(0);
        globalMapEVM[chainId][tokenGlobal] = address(0);
    }
}
