// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import {Initializable} from "@openzeppelin/contracts-upgradeable-solc8/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable-solc8/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable-solc8/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable-solc8/security/PausableUpgradeable.sol";

import {ERC20Burnable} from "@openzeppelin/contracts-solc8/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import {IVault} from "./interfaces/IVault.sol";
import {IBridge} from "./interfaces/IBridge.sol";

import {IBridgeRouter} from "../router/interfaces/IBridgeRouter.sol";

// solhint-disable reason-string

contract Bridge is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IBridge
{
    using SafeERC20 for IERC20;

    IVault public vault;
    IBridgeRouter public router;

    bytes32 public constant NODEGROUP_ROLE = keccak256("NODEGROUP_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    /// @notice Maximum amount of GAS units for Swap part of bridge transaction
    uint256 public maxGasForSwap;

    uint256 internal constant UINT_MAX = type(uint256).max;

    /**
     * @dev In regards to the same `token`:
     * tokenLocal -> `token` address on this chain
     * tokenGlobal -> `token` address on another chain
     */

    /// @dev List of tokenLocal
    address[] public bridgeTokens;

    /// @dev [tokenLocal => config]
    mapping(address => TokenConfig) public tokenConfigs;

    /// @dev [tokenLocal => [chainID => tokenGlobal]]
    mapping(address => mapping(uint256 => address)) public localMapEVM;

    /// @dev [chainID => [tokenGlobal => tokenLocal]]
    mapping(uint256 => mapping(address => address)) public globalMapEVM;

    /// @dev [chainID => [tokenGlobal => tokenLocal]]
    mapping(uint256 => mapping(string => address)) public globalMapNonEVM;

    uint256 internal constant FEE_DENOMINATOR = 10**10;

    function initialize(IVault _vault, uint256 _maxGasForSwap)
        external
        initializer
    {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        vault = _vault;
        maxGasForSwap = _maxGasForSwap;
    }

    // -- MODIFIERS --

    modifier checkDirectionSupported(
        IERC20 token,
        uint256 chainId,
        bool isEVM
    ) {
        require(chainId != _getLocalChainId(), "!chain");

        if (isEVM) {
            require(
                _getBridgeTokenEVM(address(token), chainId) != address(0),
                "!chain"
            );
        } else {
            TokenConfig memory config = tokenConfigs[address(token)];
            bytes memory mapped = bytes(config.bridgeTokenNonEVM);
            require(mapped.length > 0, "!token");
            require(config.chainIdNonEVM == chainId, "!chain");
        }

        _;
    }

    modifier checkTokenEnabled(IERC20 token) {
        require(tokenConfigs[address(token)].isEnabled, "!token");

        _;
    }

    modifier checkSwapParams(SwapParams calldata swapParams) {
        require(
            swapParams.path.length == swapParams.adapters.length + 1,
            "|path|!=|adapters|+1"
        );

        _;
    }

    // -- RECOVER TOKEN/GAS --

    /**
        @notice Recover GAS from the contract
     */
    function recoverGAS() external onlyRole(GOVERNANCE_ROLE) {
        uint256 amount = address(this).balance;
        require(amount != 0, "!balance");

        emit Recovered(address(0), amount);
        //solhint-disable-next-line
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "!xfer");
    }

    /**
        @notice Recover a token from the contract
        @param token token to recover
     */
    function recoverERC20(IERC20 token) external onlyRole(GOVERNANCE_ROLE) {
        uint256 amount = token.balanceOf(address(this));
        require(amount != 0, "!balance");

        emit Recovered(address(token), amount);
        //solhint-disable-next-line
        token.safeTransfer(msg.sender, amount);
    }

    // -- RESTRICTED SETTERS --

    function setMaxGasForSwap(uint256 _maxGasForSwap)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        maxGasForSwap = _maxGasForSwap;
    }

    function setRouter(IBridgeRouter _router)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        router = _router;
    }

    // -- BRIDGE CONFIG: swap fees --

    /**
     * @notice Add a new Bridge token config. Called by Governance only.
     * @dev This will revert if a token has been added before, use {updateTokenFees},
     * {updateTokenSetup} to update things later.
     * Most of the time, `token == bridgeToken`. Another contract is used when token.mint(to, amount)
     * or token.burn(amount) are impossible to call.
     * In that case, `bridgeToken` should implement such functions to perform mint/burn of `token`.
     * The concept of `bridgeToken` is isolated in `Bridge` entirely - no one needs to know how
     * exactly `token` is being bridged.
     * @param token Token to add: the version that is used on this chain.
     * @param bridgeToken Bridge token that will be used for bridging `token`.
     * @param isMintBurn Specifies if token is bridged via mint-burn or deposit-withdraw.
     * @param synapseFee Synapse:Bridge fee value(i.e. 0.1%), multiplied by `FEE_DENOMINATOR`
     * @param maxTotalFee Maximum total bridge fee, in `token` decimals
     * @param minBridgeFee Minimum fee covering bridging in (always present), in `token` decimals
     * @param minGasDropFee Minimum fee covering covering GasDrop (when GasDrop is present), in `token` decimals
     * @param minSwapFee Minimum fee covering covering further swap (when swap is present), in `token` decimals
     */
    function addNewBridgeToken(
        IERC20 token,
        address bridgeToken,
        bool isMintBurn,
        uint256 synapseFee,
        uint256 maxTotalFee,
        uint256 minBridgeFee,
        uint256 minGasDropFee,
        uint256 minSwapFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_getBridgeToken(token) == address(0), "+token");

        _updateTokenFees(
            token,
            synapseFee,
            maxTotalFee,
            minBridgeFee,
            minGasDropFee,
            minSwapFee
        );

        _updateTokenSetup(token, bridgeToken, isMintBurn);

        // Store the token that is used on chain instead of wrapper
        bridgeTokens.push(address(token));
    }

    /**
     * @notice Update an existing `token` config. Called by Governance only.
     * @dev This will revert if `token` wasn't added before.
     * @param token Token to add: the version that is used on this chain.
     * @param synapseFee Synapse:Bridge fee value(i.e. 0.1%), multiplied by `FEE_DENOMINATOR`
     * @param maxTotalFee Maximum total bridge fee, in `token` decimals
     * @param minBridgeFee Minimum fee covering bridging in (always present), in `token` decimals
     * @param minGasDropFee Minimum fee covering covering GasDrop (when GasDrop is present), in `token` decimals
     * @param minSwapFee Minimum fee covering covering further swap (when swap is present), in `token` decimals
     */
    function updateTokenFees(
        IERC20 token,
        uint256 synapseFee,
        uint256 maxTotalFee,
        uint256 minBridgeFee,
        uint256 minGasDropFee,
        uint256 minSwapFee
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_getBridgeToken(token) != address(0), "!token");

        _updateTokenFees(
            token,
            synapseFee,
            maxTotalFee,
            minBridgeFee,
            minGasDropFee,
            minSwapFee
        );
    }

    /**
     * @notice Update an existing `token` config. Called by Governance only.
     * @dev This will revert if `token` wasn't added before.
     * @param token Token to add: the version that is used on this chain.
     * @param bridgeToken Bridge token that will be used for bridging `token`.
     * @param isMintBurn Specifies if token is bridged via mint-burn or deposit-withdraw.
     */
    function updateTokenSetup(
        IERC20 token,
        address bridgeToken,
        bool isMintBurn
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_getBridgeToken(token) != address(0), "!token");

        _updateTokenSetup(token, bridgeToken, isMintBurn);
    }

    function _updateTokenFees(
        IERC20 token,
        uint256 synapseFee,
        uint256 maxTotalFee,
        uint256 minBridgeFee,
        uint256 minGasDropFee,
        uint256 minSwapFee
    ) internal {
        TokenConfig storage config = tokenConfigs[address(token)];

        config.synapseFee = synapseFee;
        config.maxTotalFee = maxTotalFee;
        config.minBridgeFee = minBridgeFee;
        config.minGasDropFee = minGasDropFee;
        config.minSwapFee = minSwapFee;

        emit TokenFeesUpdated(
            token,
            synapseFee,
            maxTotalFee,
            minBridgeFee,
            minGasDropFee,
            minSwapFee
        );
    }

    function _updateTokenSetup(
        IERC20 token,
        address bridgeToken,
        bool isMintBurn
    ) internal {
        TokenConfig storage config = tokenConfigs[address(token)];

        config.bridgeToken = bridgeToken;
        config.tokenType = isMintBurn
            ? TokenType.MINT_BURN
            : TokenType.DEPOSIT_WITHDRAW;

        emit TokenSetupUpdated(token, bridgeToken, isMintBurn);
    }

    // -- BRIDGE CONFIG: Token Map (Governance) --

    /**
     * @dev Checks whether provided arrays length match,
     * also checks for blank values.
     */
    modifier checkConfigEVM(
        uint256[] calldata chainIdsEVM,
        address[] calldata bridgeTokensEVM
    ) {
        require(bridgeTokensEVM.length == chainIdsEVM.length, "!length");
        for (uint256 i = 0; i < chainIdsEVM.length; ++i) {
            require(chainIdsEVM[i] != 0, "!ID");
            require(bridgeTokensEVM[i] != address(0), "!token");
        }

        _;
    }

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
     * @param bridgeTokenNonEVM address of token on non-EVM chain. Ignored, if `chainIdNonEVM==0`.
     */
    function addNewMap(
        uint256[] calldata chainIdsEVM,
        address[] calldata bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string calldata bridgeTokenNonEVM
    )
        external
        onlyRole(GOVERNANCE_ROLE)
        checkConfigEVM(chainIdsEVM, bridgeTokensEVM)
    {
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
     * @param bridgeTokenNonEVM address of token on NEW non-EVM chain. Ignored, if `chainIdNonEVM==0`.
     */
    function addChainsToMap(
        address token,
        uint256[] calldata newChainIdsEVM,
        address[] calldata newBridgeTokensEVM,
        uint256 chainIdNonEVM,
        string calldata bridgeTokenNonEVM
    )
        external
        onlyRole(GOVERNANCE_ROLE)
        checkConfigEVM(newChainIdsEVM, newBridgeTokensEVM)
    {
        TokenConfig memory config = tokenConfigs[token];
        require(config.chainIdsEVM.length != 0, "!Map");

        _updateTokenMap(
            token,
            newChainIdsEVM,
            newBridgeTokensEVM,
            chainIdNonEVM,
            bridgeTokenNonEVM
        );

        // config.chainIdsEVM now contains both old and new chainIds
        address[] memory allTokenAddresses = _getAllTokenAddressesEVM(
            token,
            config.chainIdsEVM
        );

        // Use both old and new chains in the emitted Event
        emit TokenMapUpdated(
            config.chainIdsEVM,
            allTokenAddresses,
            chainIdNonEVM,
            bridgeTokenNonEVM
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
     * @param isEnabled New token Bridge status
     */
    function changeTokenStatus(IERC20 token, bool isEnabled)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        if (_changeTokenStatus(token, isEnabled)) {
            TokenConfig memory config = tokenConfigs[address(token)];

            address[] memory allTokenAddresses = _getAllTokenAddressesEVM(
                address(token),
                config.chainIdsEVM
            );

            emit TokenStatusUpdated(
                config.chainIdsEVM,
                allTokenAddresses,
                isEnabled
            );
        }
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
     * @param bridgeTokenNonEVM address of token on non-EVM chain. Ignored, if `chainIdNonEVM==0`.
     */
    function updateMap(
        uint256[] calldata chainIdsEVM,
        address[] calldata bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string calldata bridgeTokenNonEVM
    )
        external
        onlyRole(NODEGROUP_ROLE)
        checkConfigEVM(chainIdsEVM, bridgeTokensEVM)
    {
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
     * @param isEnabled New token Bridge status
     */
    function updateTokenStatus(IERC20 token, bool isEnabled)
        external
        onlyRole(NODEGROUP_ROLE)
    {
        _changeTokenStatus(token, isEnabled);

        // DO NOT emit anything, as this is a relayed setup tx
    }

    // -- BRIDGE CONFIG: token setup (internal implementation) --

    function _changeTokenStatus(IERC20 token, bool isEnabled)
        internal
        returns (bool)
    {
        TokenConfig storage config = tokenConfigs[address(token)];
        require(config.bridgeToken != address(0), "!token");
        require(config.chainIdsEVM.length != 0, "!Map");

        if (config.isEnabled == isEnabled) {
            // Y U DO DIS
            return false;
        }

        config.isEnabled = isEnabled;
        return true;
    }

    function _getAllTokenAddressesEVM(address token, uint256[] memory chainIds)
        internal
        view
        returns (address[] memory allTokenAddresses)
    {
        uint256 amount = chainIds.length;
        allTokenAddresses = new address[](amount);

        for (uint256 i = 0; i < amount; i++) {
            allTokenAddresses[i] = _getBridgeTokenEVM(token, chainIds[i]);
        }
    }

    function _findLocalToken(
        uint256[] calldata chainIdsEVM,
        address[] calldata bridgeTokensEVM
    ) internal view returns (address token) {
        uint256 chainId = _getLocalChainId();
        // Find bridge token address on this chain
        for (uint256 i = 0; i < chainIdsEVM.length; i++) {
            if (chainIdsEVM[i] == chainId) {
                token = bridgeTokensEVM[i];
                break;
            }
        }
        require(token != address(0), "!Found");
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
            !checkEmpty || tokenConfigs[tokenLocal].chainIdsEVM.length == 0,
            "+Map"
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
        TokenConfig storage config = tokenConfigs[tokenLocal];

        require(config.bridgeToken != address(0), "!token");

        for (uint256 i = 0; i < chainIdsEVM.length; i++) {
            uint256 chainId = chainIdsEVM[i];
            // Add chain to the map, only if it is currently missing
            if (_getBridgeTokenEVM(tokenLocal, chainId) == address(0)) {
                address tokenGlobal = bridgeTokensEVM[i];
                localMapEVM[tokenLocal][chainId] = tokenGlobal;
                globalMapEVM[chainId][tokenGlobal] = tokenLocal;
                config.chainIdsEVM.push(chainId);
            }
        }

        if (chainIdNonEVM != 0) {
            require(config.chainIdNonEVM == 0, "+chain");
            globalMapNonEVM[chainIdNonEVM][bridgeTokenNonEVM] = tokenLocal;
            config.chainIdNonEVM = chainIdNonEVM;
            config.bridgeTokenNonEVM = bridgeTokenNonEVM;
        }
    }

    // -- BRIDGE CONFIG: views --

    function calculateBridgeFee(
        address token,
        uint256 amount,
        bool gasdropRequested,
        bool swapRequested
    ) public view returns (uint256 fee) {
        TokenConfig memory config = tokenConfigs[token];
        uint256 minFee = config.minBridgeFee +
            (gasdropRequested ? config.minGasDropFee : 0) +
            (swapRequested ? config.minSwapFee : 0);

        fee = (amount * config.synapseFee) / FEE_DENOMINATOR;

        if (minFee > fee) {
            fee = minFee;
        }
    }

    /**
     * @notice Get a list of tokens bridgeable between current and a given EVM chain
     * @param chainTo EVM chain to bridge to
     * @return tokensLocal bridge token addresses on this chain
     * @return tokensGlobal bridge token addresses on `chainTo`
     */
    function getAllBridgeTokensEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, address[] memory tokensGlobal)
    {
        uint256 amountTo = 0;

        uint256 amountFull = bridgeTokens.length;
        for (uint256 i = 0; i < amountFull; ++i) {
            if (_getBridgeTokenEVM(bridgeTokens[i], chainTo) != address(0)) {
                ++amountTo;
            }
        }

        tokensLocal = new address[](amountTo);
        tokensGlobal = new address[](amountTo);
        amountTo = 0;

        for (uint256 i = 0; i < amountFull; ++i) {
            address tokenLocal = bridgeTokens[i];
            address tokenGlobal = _getBridgeTokenEVM(tokenLocal, chainTo);
            if (tokenGlobal != address(0)) {
                tokensLocal[amountTo] = tokenLocal;
                tokensGlobal[amountTo] = tokenGlobal;
                ++amountTo;
            }
        }
    }

    /**
     * @notice Get a list of tokens bridgeable between current and a given non-EVM chain
     * @param chainTo non-EVM chain to bridge to
     * @return tokensLocal bridge token addresses on this chain
     * @return tokensGlobal bridge token addresses on `chainTo`
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

    function _getBridgeToken(IERC20 token) internal view returns (address) {
        return tokenConfigs[address(token)].bridgeToken;
    }

    function _getBridgeTokenEVM(address token, uint256 chainID)
        internal
        view
        returns (address)
    {
        return localMapEVM[token][chainID];
    }

    function _getBridgeTokenNonEVM(address token)
        internal
        view
        returns (string memory)
    {
        return tokenConfigs[token].bridgeTokenNonEVM;
    }

    function _getLocalChainId() internal view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }

    function _getTokenType(IERC20 token) internal view returns (TokenType) {
        return tokenConfigs[address(token)].tokenType;
    }

    function _isMintBurnWithCheck(IERC20 token) internal view returns (bool) {
        TokenType tokenType = _getTokenType(token);
        require(tokenType != TokenType.NOT_SUPPORTED, "!token");
        return tokenType == TokenType.MINT_BURN;
    }

    // -- BRIDGE OUT FUNCTIONS: to EVM chains --

    function bridgeToEVM(
        address to,
        uint256 chainId,
        IERC20 token,
        SwapParams calldata destinationSwapParams,
        bool gasdropRequested
    )
        external
        checkDirectionSupported(token, chainId, true)
        checkTokenEnabled(token)
        checkSwapParams(destinationSwapParams)
        returns (uint256 amountBridged)
    {
        // First, burn token, or deposit to Vault (depending on bridge token type).
        // Use verified burnt/deposited amount for bridging purposes.
        amountBridged = _lockToken(token);

        // Then, get token address on destination chain
        // checked for not being zero in checkDirectionSupported
        address tokenBridgedTo = _getBridgeTokenEVM(address(token), chainId);

        // Finally, emit a Bridge Event
        emit BridgedOutEVM(
            to,
            chainId,
            token,
            amountBridged,
            IERC20(tokenBridgedTo),
            destinationSwapParams,
            gasdropRequested
        );
    }

    // -- BRIDGE OUT FUNCTIONS: to non-EVM chain --

    function bridgeToNonEVM(
        bytes32 to,
        uint256 chainId,
        IERC20 token
    )
        external
        checkDirectionSupported(token, chainId, false)
        checkTokenEnabled(token)
        returns (uint256 amountBridged)
    {
        // First, burn token, or deposit to Vault (depending on bridge token type).
        // Use verified burnt/deposited amount for bridging purposes.
        amountBridged = _lockToken(token);

        // Then, get token address on destination chain
        // chainId and address was checked in checkDirectionSupported
        string memory tokenBridgedTo = _getBridgeTokenNonEVM(address(token));

        // Finally, emit a Bridge Event
        emit BridgedOutNonEVM(
            to,
            chainId,
            token,
            amountBridged,
            tokenBridgedTo
        );
    }

    // -- BRIDGE OUT : internal helpers --

    function _lockToken(IERC20 token)
        internal
        returns (uint256 amountVerified)
    {
        // Figure out how much tokens do we have.
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "!amount");

        address bridgeTokenAddress = _getBridgeToken(token);

        if (_isMintBurnWithCheck(token)) {
            // Burn token, and verify how much was burnt
            uint256 balanceBefore = token.balanceOf(address(this));

            ERC20Burnable(bridgeTokenAddress).burn(amount);

            amountVerified = balanceBefore - token.balanceOf(address(this));
        } else {
            // Deposit token into Vault, and verify how much was burnt
            uint256 balanceBefore = token.balanceOf(address(vault));

            IERC20(bridgeTokenAddress).transfer(address(vault), amount);

            amountVerified = token.balanceOf(address(vault)) - balanceBefore;
        }

        require(amountVerified > 0, "!locked");
    }

    // -- BRIDGE IN FUNCTIONS --

    function bridgeInEVM(
        address to,
        IERC20 token,
        uint256 amount,
        SwapParams calldata swapParams,
        bool gasdropRequested,
        bytes32 kappa
    ) external onlyRole(NODEGROUP_ROLE) nonReentrant whenNotPaused {
        _bridgeIn(to, token, amount, swapParams, gasdropRequested, kappa);
    }

    function bridgeInNonEVM(
        address to,
        uint256 chainIdFrom,
        string memory bridgeTokenFrom,
        uint256 amount,
        bytes32 kappa
    ) external onlyRole(NODEGROUP_ROLE) nonReentrant whenNotPaused {
        address token = globalMapNonEVM[chainIdFrom][bridgeTokenFrom];
        require(token != address(0), "!token");

        address[] memory path = new address[](1);
        path[0] = token;

        _bridgeIn(
            to,
            IERC20(token),
            amount,
            // (minAmountOut, path, adapters, deadline)
            SwapParams(0, path, new address[](0), UINT_MAX),
            // gasdropEnabled = true
            true,
            kappa
        );
    }

    function _bridgeIn(
        address to,
        IERC20 token,
        uint256 amount,
        SwapParams memory swapParams,
        bool gasdropRequested,
        bytes32 kappa
    ) internal checkTokenEnabled(token) {
        _BridgeInData memory data;
        data.isMint = _isMintBurnWithCheck(token);

        // solhint-disable not-rely-on-time
        bool isSwapPresent = _isSwapPresent(swapParams) &&
            block.timestamp <= swapParams.deadline;

        uint256 fee = calculateBridgeFee(
            address(token),
            amount,
            gasdropRequested,
            isSwapPresent
        );
        require(amount > fee, "!fee");

        // First, get the amount post fees
        amount = amount - fee;

        // If swap is present, release tokens to Router directly
        // Otherwise, release them to specified user address
        data.gasdropAmount = _releaseToken(
            isSwapPresent ? address(router) : to,
            token,
            amount,
            fee,
            data.isMint,
            to, // always send gasDrop to user
            gasdropRequested,
            kappa
        );

        // If swap is present, do it and gather the info about tokens received
        // Otherwise, use bridge token and its amount
        (data.tokenReceived, data.amountReceived) = isSwapPresent
            ? _handleSwap(to, token, amount, swapParams)
            : (token, amount);

        // Finally, emit BridgeIn Event
        emit TokenBridgedIn(
            to,
            token,
            amount + fee,
            fee,
            data.tokenReceived,
            data.amountReceived,
            data.gasdropAmount,
            kappa
        );
    }

    // -- BRIDGE IN: internal helpers --

    function _handleSwap(
        address to,
        IERC20 token,
        uint256 amountPostFee,
        SwapParams memory swapParams
    ) internal returns (IERC20 tokenOut, uint256 amountOut) {
        // We're limiting amount of gas forwarded to Router,
        // so we always have some leftover gas to transfer
        // bridged token, should the swap run out of gas
        try
            router.postBridgeSwap{gas: maxGasForSwap}(
                to,
                swapParams,
                amountPostFee
            )
        returns (uint256 _amountOut) {
            // Swap succeeded, save information about received token
            tokenOut = IERC20(swapParams.path[swapParams.path.length - 1]);
            amountOut = _amountOut;
        } catch {
            // Swap failed, return bridge token to user
            tokenOut = token;
            amountOut = amountPostFee;
            router.refundToAddress(to, token, amountPostFee);
        }
    }

    function _isSwapPresent(SwapParams memory params)
        internal
        pure
        returns (bool)
    {
        return params.adapters.length > 0;
    }

    function _releaseToken(
        address to,
        IERC20 token,
        uint256 amountPostFee,
        uint256 fee,
        bool isMint,
        address userAddress,
        bool gasdropRequested,
        bytes32 kappa
    ) internal returns (uint256 gasdropAmount) {
        address bridgeTokenAddress = _getBridgeToken(token);
        gasdropAmount = (isMint ? vault.mintToken : vault.withdrawToken)(
            to,
            IERC20(bridgeTokenAddress),
            amountPostFee,
            fee,
            userAddress,
            gasdropRequested,
            kappa
        );
    }
}
