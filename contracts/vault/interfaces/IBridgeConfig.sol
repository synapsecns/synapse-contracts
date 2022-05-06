// SPDX-License-Identifier: MIT

pragma solidity >=0.8.11;

interface IBridgeConfig {
    /// @dev UNKNOWN would be default value
    enum TokenType {
        UNKNOWN,
        MINT_BURN,
        DEPOSIT_WITHDRAW
    }

    struct TokenConfig {
        // ------------------------------------ TOKEN SETUP ---------------------------------------
        /// @notice Describes how `token` is going to be bridged: mint or withdraw
        TokenType tokenType;
        /// @notice Contract responsible for `token` locking/releasing.
        /// @dev If `token` is compatible with Synapse:Bridge directly, this would be `token` address.
        /// Otherwise, it is address of BridgeWrapper for `token`.
        /// No one (UI, users, validators) needs to know about this extra layer, it is abstracted away
        /// outside of Bridge contract.
        address bridgeToken;
        /// @notice Whether bridging is enabled for given token
        bool isEnabled;
        // ------------------------------------ FEES ----------------------------------------------
        /// @notice Synapse:bridge fee value(i.e. 0.1%), multiplied by `FEE_DENOMINATOR`
        uint256 synapseFee;
        /// @notice Maximum total bridge fee
        uint256 maxTotalFee;
        /// @notice Minimum part of the fee covering bridging in (always present)
        uint256 minBridgeFee;
        /// @notice Minimum part of the fee covering GasDrop (when gasDrop is present)
        uint256 minGasDropFee;
        /// @notice Minimum part of the fee covering further swap (when swap is present)
        uint256 minSwapFee;
        // ------------------------------------ MAP INFO ------------------------------------------
        /// @dev If `token` comes from non-EVM chain, these will store the token config on non-EVM chain.
        /// Otherwise, these are left empty.
        uint256 chainIdNonEVM;
        string bridgeTokenNonEVM;
    }

    // -- SINGLE CHAIN SETUP EVENTS --

    event TokenSetupUpdated(
        address token,
        address bridgeToken,
        bool isMintBurn
    );

    event TokenFeesUpdated(
        address token,
        uint256 synapseFee,
        uint256 maxTotalFee,
        uint256 minBridgeFee,
        uint256 minGasDropFee,
        uint256 minSwapFee
    );

    // -- CROSS CHAIN SETUP EVENTS --

    event TokenDeleted(uint256 chainIdEVM, address bridgeTokenEVM);

    event TokenMapUpdated(
        uint256[] chainIdsEVM,
        address[] bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string bridgeTokenNonEVM
    );

    event TokenStatusUpdated(
        uint256[] chainIdsEVM,
        address[] bridgeTokensEVM,
        bool isEnabled
    );

    // -- VIEWS --

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
        );

    function getAllBridgeTokensEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, address[] memory tokensGlobal);

    function getAllBridgeTokensNonEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, string[] memory tokensGlobal);

    function getBridgeToken(address token)
        external
        view
        returns (
            address bridgeToken,
            bool isEnabled,
            bool isMintBurn
        );

    function getTokenAddressEVM(address tokenLocal, uint256 chainId)
        external
        view
        returns (address tokenGlobal, bool isEnabled);

    function getTokenAddressNonEVM(address tokenLocal, uint256 chainId)
        external
        view
        returns (string memory tokenGlobal, bool isEnabled);

    function findTokenEVM(uint256 chainId, address tokenGlobal)
        external
        view
        returns (address tokenLocal);

    function findTokenNonEVM(uint256 chainId, string calldata tokenGlobal)
        external
        view
        returns (address tokenLocal);

    function isTokenEnabled(address bridgeToken) external view returns (bool);
}
