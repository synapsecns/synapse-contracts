// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./framework/SynMessagingReceiverUpgradeable.sol";
import "./interfaces/IGasFeePricing.sol";
import "./libraries/Options.sol";
import "./libraries/GasFeePricingUpdates.sol";

contract GasFeePricingUpgradeable is SynMessagingReceiverUpgradeable {
    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STRUCTS                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Whenever the messaging fee is calculated, it takes into account things as:
     * gas token prices on local and remote chain, gas limit for executing message on remote chain
     * and gas unit price on remote chain. In other words, message sender is paying remote chain
     * gas fees (to cover gas usage and gasdrop), but in local chain gas token.
     * The price values are static, though are supposed to be updated in the event of high
     * volatility. It is implied that gas token/unit prices reflect respective latest
     * average prices.
     *
     * Because of this, the markups are used, both for "gas drop fee", and "gas usage fee".
     * Markup is a value of 0% or higher. This is the coefficient applied to
     * "projected gas fee", that is calculated using static gas token/unit prices.
     * Markup of 0% means that exactly "projected gas fee" will be charged, markup of 50%
     * will result in fee that is 50% higher than "projected", etc.
     *
     * There are separate markups for gasDrop and gasUsage. gasDropFee is calculated only using
     * local and remote gas token prices, while gasUsageFee also takes into account remote chain gas
     * unit price, which is an extra source of volatility.
     *
     * Generally, markupGasUsage >= markupGasDrop >= 0%. While markups can be set to 0%,
     * this is not recommended.
     */

    /**
     * @dev Chain's Config is supposed to be PARTLY synchronized cross-chain, i.e.
     * GasFeePricing contracts on different chain will have the SAME values for
     * the same remote chain:
     * - gasDropMax: maximum gas airdrop available on chain
     *               uint112 => max value ~= 5 * 10**33
     * - gasUnitsRcvMsg: Amount of gas units needed for GasFeePricing contract
     *                   to receive "update chain Config/Info" message
     *                   uint80 => max value ~= 10**24
     * - minGasUsageFeeUsd: minimum amount of "gas usage" part of total messaging fee,
     *                      when sending message to given remote chain.
     *                      Quoted in USD, multiplied by USD_DENOMINATOR
     *                      uint32 => max value ~= 4 * 10**9
     * These are universal values, and they should be the same on all GasFeePricing
     * contracts.
     * ═══════════════════════════════════════════════════════════════════════════════════════
     * Some of the values, however, are set unique for every "local-remote" chain combination:
     * - markupGasDrop: Markup for gas airdrop
     *                  uint16 => max value = 65535
     * - markupGasUsage: Markup for gas usage
     *                   uint16 => max value = 65535
     * These values depend on correlation between local and remote chains. For instance,
     * if both chains have the same gas token (like ETH), markup for the gas drop
     * can be set to 0, as gasDrop is limited, and the slight price difference between ETH
     * on local and remote chain can not be taken advantage of.
     *
     * On the contrary, if local and remote gas tokens have proven to be not that correlated
     * in terms of their price, higher markup is needed to compensate potential price spikes.
     *
     * ChainConfig is optimized to fit into one word of storage.
     * ChainConfig is not supposed to be updated regularly (the values are more or less persistent).
     */

    struct ChainConfig {
        /// @dev Values below are synchronized cross-chain
        uint112 gasDropMax;
        uint80 gasUnitsRcvMsg;
        uint32 minGasUsageFeeUsd;
        /// @dev Values below are local-chain specific
        uint16 markupGasDrop;
        uint16 markupGasUsage;
    }

    /**
     * @dev Chain's Info is supposed to be FULLY synchronized cross-chain, i.e.
     * GasFeePricing contracts on different chain will have the SAME values for
     * the same remote chain:
     * - gasTokenPrice: Price of chain's gas token in USD, scaled to wei
     *                  uint128 => max value ~= 3 * 10**38
     * - gasUnitPrice: Price of chain's 1 gas unit in wei
     *                 uint128 => max value ~= 3 * 10**38
     *
     * These are universal values, and they should be the same on all GasFeePricing
     * contracts.
     *
     * ChainInfo is optimized to fit into one word of storage.
     * ChainInfo is supposed to be updated regularly, as the chain's gas token or unit
     * price changes drastically.
     */
    struct ChainInfo {
        /// @dev Values below are synchronized cross-chain
        uint128 gasTokenPrice;
        uint128 gasUnitPrice;
    }

    /**
     * @dev Chain's Ratios are supposed to be FULLY chain-specific, i.e.
     * GasFeePricing contracts on different chain will have different values for
     * the same remote chain:
     * - gasTokenPriceRatio: USD price ratio of remoteGasToken / localGasToken, scaled to wei
     *                       uint96 => max value ~= 8 * 10**28
     * - gasUnitPriceRatio: How much 1 gas unit on remote chain is worth, expressed in local chain wei,
     *                      multiplied by 10**18 (aka in attoWei = 10^-18 wei)
     *                      uint160 => max value ~= 10**48
     * These values are updated whenever "gas information" is updated for either local or remote chain.
     *
     * ChainRatios is optimized to fit into one word of storage.
     */

    /**
     * @dev Chain's Ratios are used for calculating a fee for sending a msg from local to remote chain.
     * To calculate cost of tx gas airdrop (assuming gasDrop airdrop value):
     * (gasDrop * gasTokenPriceRatio) / 10**18
     * To calculate cost of tx gas usage on remote chain (assuming gasAmount gas units):
     * (gasAmount * gasUnitPriceRatio) / 10**18
     *
     * Both numbers are expressed in local chain wei.
     */
    struct ChainRatios {
        /// @dev Values below are local-chain specific
        uint96 gasTokenPriceRatio;
        uint160 gasUnitPriceRatio;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                EVENTS                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev see "Structs" docs
    event ChainInfoUpdated(uint256 indexed chainId, uint256 gasTokenPrice, uint256 gasUnitPrice);
    /// @dev see "Structs" docs
    event MarkupsUpdated(uint256 indexed chainId, uint256 markupGasDrop, uint256 markupGasUsage);

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        REMOTE CHAINS STORAGE                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev remoteChainId => Info
    mapping(uint256 => ChainInfo) public remoteInfo;
    /// @dev remoteChainId => Ratios
    mapping(uint256 => ChainRatios) public remoteRatios;
    /// @dev remoteChainId => Config
    mapping(uint256 => ChainConfig) public remoteConfig;
    /// @dev list of all remote chain ids
    uint256[] internal remoteChainIds;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         SOURCE CHAIN STORAGE                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev See "Structs" docs
    /// localConfig.markupGasDrop and localConfig.markupGasUsage values are not used
    ChainConfig public localConfig;
    ChainInfo public localInfo;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              CONSTANTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    uint256 public constant DEFAULT_GAS_LIMIT = 200000;
    uint256 public constant MARKUP_DENOMINATOR = 100;
    uint256 public constant USD_DENOMINATOR = 10000;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             INITIALIZER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function initialize(address _messageBus, uint256 _localGasTokenPrice) external initializer {
        __Ownable_init_unchained();
        messageBus = _messageBus;
        localInfo.gasTokenPrice = uint96(_localGasTokenPrice);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Get the fee for sending a message to remote chain with given options
    function estimateGasFee(uint256 _remoteChainId, bytes calldata _options) external view returns (uint256 fee) {
        fee = _estimateGasFee(_remoteChainId, _options);
    }

    /// @notice Get the fee for sending a message to a bunch of chains with given options
    function estimateGasFees(uint256[] calldata _remoteChainIds, bytes[] calldata _options)
        external
        view
        returns (uint256 fee)
    {
        require(_remoteChainIds.length == _options.length, "!arrays");
        for (uint256 i = 0; i < _remoteChainIds.length; ++i) {
            fee = fee + _estimateGasFee(_remoteChainIds[i], _options[i]);
        }
    }

    /// @dev Extracts the gas information from options and calculates the messaging fee
    function _estimateGasFee(uint256 _remoteChainId, bytes calldata _options) internal view returns (uint256 fee) {
        ChainConfig memory config = remoteConfig[_remoteChainId];
        uint256 gasAirdrop;
        uint256 gasLimit;
        if (_options.length != 0) {
            (gasLimit, gasAirdrop, ) = Options.decode(_options);
            if (gasAirdrop != 0) {
                require(gasAirdrop <= config.gasDropMax, "GasDrop higher than max");
            }
        } else {
            gasLimit = DEFAULT_GAS_LIMIT;
        }

        fee = _estimateGasFee(_remoteChainId, gasAirdrop, gasLimit, config.markupGasDrop, config.markupGasUsage);
    }

    /// @dev Returns a gas fee for sending a message to remote chain, given the amount of gas to airdrop,
    /// and amount of gas units for message execution on remote chain.
    function _estimateGasFee(
        uint256 _remoteChainId,
        uint256 _gasAirdrop,
        uint256 _gasLimit,
        uint256 _markupGasDrop,
        uint256 _markupGasUsage
    ) internal view returns (uint256 fee) {
        ChainRatios memory remoteRatio = remoteRatios[_remoteChainId];

        // Calculate how much gas airdrop is worth in local chain wei
        uint256 feeGasDrop = (_gasAirdrop * remoteRatio.gasTokenPriceRatio) / 10**18;
        // Calculate how much gas usage is worth in local chain wei
        uint256 feeGasUsage = (_gasLimit * remoteRatio.gasUnitPriceRatio) / 10**18;

        // Sum up the fees multiplied by their respective markups
        feeGasDrop = (feeGasDrop * (_markupGasDrop + MARKUP_DENOMINATOR)) / MARKUP_DENOMINATOR;
        feeGasUsage = (feeGasUsage * (_markupGasUsage + MARKUP_DENOMINATOR)) / MARKUP_DENOMINATOR;
        // TODO: implement remote-chain-specific minGasUsageFee
        // Check if gas usage fee is lower than minimum
        // uint256 _minGasUsageFee = minGasUsageFee;
        // if (feeGasUsage < _minGasUsageFee) feeGasUsage = _minGasUsageFee;
        fee = feeGasDrop + feeGasUsage;
    }

    /// @notice Get total gas fee for calling updateChainInfo()
    function estimateUpdateFees() external view returns (uint256 totalFee) {
        (totalFee, ) = _estimateUpdateFees();
    }

    /// @dev Returns total gas fee for calling updateChainInfo(), as well as
    /// fee for each remote chain.
    function _estimateUpdateFees() internal view returns (uint256 totalFee, uint256[] memory fees) {
        uint256[] memory _chainIds = remoteChainIds;
        fees = new uint256[](_chainIds.length);
        for (uint256 i = 0; i < _chainIds.length; ++i) {
            uint256 chainId = _chainIds[i];
            ChainConfig memory config = remoteConfig[chainId];
            uint256 gasLimit = config.gasUnitsRcvMsg;
            if (gasLimit == 0) gasLimit = DEFAULT_GAS_LIMIT;

            uint256 fee = _estimateGasFee(chainId, 0, gasLimit, config.markupGasDrop, config.markupGasUsage);
            totalFee += fee;
            fees[i] = fee;
        }
    }

    function _calculateMinGasUsageFee(uint256 _minFeeUsd, uint256 _gasTokenPrice)
        internal
        pure
        returns (uint256 minFee)
    {
        minFee = (_minFeeUsd * 10**18) / _gasTokenPrice;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              ONLY OWNER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Update config (gasLimit for sending messages to chain, max gas airdrop) for a bunch of chains.
    function setRemoteConfig(
        uint256[] memory _remoteChainId,
        uint112[] memory _gasDropMax,
        uint80[] memory _gasUnitsRcvMsg,
        uint32[] memory _minGasUsageFeeUsd
    ) external onlyOwner {
        require(
            _remoteChainId.length == _gasDropMax.length &&
                _remoteChainId.length == _gasUnitsRcvMsg.length &&
                _remoteChainId.length == _minGasUsageFeeUsd.length,
            "!arrays"
        );
        for (uint256 i = 0; i < _remoteChainId.length; ++i) {
            _updateRemoteChainConfig(_remoteChainId[i], _gasDropMax[i], _gasUnitsRcvMsg[i], _minGasUsageFeeUsd[i]);
        }
    }

    /// @notice Update information about gas unit/token price for a bunch of chains.
    /// Handy for initial setup.
    function setRemoteInfo(
        uint256[] memory _remoteChainId,
        uint128[] memory _gasTokenPrice,
        uint128[] memory _gasUnitPrice
    ) external onlyOwner {
        require(
            _remoteChainId.length == _gasTokenPrice.length && _remoteChainId.length == _gasUnitPrice.length,
            "!arrays"
        );
        for (uint256 i = 0; i < _remoteChainId.length; ++i) {
            _updateRemoteChainInfo(_remoteChainId[i], _gasTokenPrice[i], _gasUnitPrice[i]);
        }
    }

    /// @notice Sets markups (see "Structs" docs) for a bunch of chains. Markups are used for determining
    /// how much fee to charge on top of "projected gas cost" of delivering the message.
    function setRemoteMarkups(
        uint256[] memory _remoteChainId,
        uint16[] memory _markupGasDrop,
        uint16[] memory _markupGasUsage
    ) external onlyOwner {
        require(
            _remoteChainId.length == _markupGasDrop.length && _remoteChainId.length == _markupGasUsage.length,
            "!arrays"
        );
        for (uint256 i = 0; i < _remoteChainId.length; ++i) {
            _updateMarkups(_remoteChainId[i], _markupGasDrop[i], _markupGasUsage[i]);
        }
    }

    /// @notice Update information about local chain config:
    /// amount of gas needed to do _updateRemoteChainInfo()
    /// and maximum airdrop available on this chain
    function updateLocalConfig(
        uint112 _gasDropMax,
        uint80 _gasUnitsRcvMsg,
        uint32 _minGasUsageFeeUsd
    ) external payable onlyOwner {
        require(_gasUnitsRcvMsg != 0, "Gas amount is not set");
        _sendUpdateMessages(GasFeePricingUpdates.encodeConfig(_gasDropMax, _gasUnitsRcvMsg, _minGasUsageFeeUsd));
        ChainConfig memory config = localConfig;
        config.gasDropMax = _gasDropMax;
        config.gasUnitsRcvMsg = _gasUnitsRcvMsg;
        config.minGasUsageFeeUsd = _minGasUsageFeeUsd;
        localConfig = config;
    }

    /// @notice Update information about local chain gas token/unit price on all configured remote chains,
    /// as well as on the local chain itself.
    function updateLocalInfo(uint128 _gasTokenPrice, uint128 _gasUnitPrice) external payable onlyOwner {
        /**
         * @dev Some chains (i.e. Aurora) allow free transactions,
         * so we're not checking gasUnitPrice for being zero.
         * gasUnitPrice is never used as denominator, and there's
         * a minimum fee for gas usage, so this can't be taken advantage of.
         */
        require(_gasTokenPrice != 0, "Gas token price is not set");
        // send messages before updating the values, so that it's possible to use
        // estimateUpdateFees() to calculate the needed fee for the update
        _sendUpdateMessages(GasFeePricingUpdates.encodeInfo(_gasTokenPrice, _gasUnitPrice));
        _updateLocalChainInfo(_gasTokenPrice, _gasUnitPrice);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          UPDATE STATE LOGIC                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Updates information about local chain gas token/unit price.
    /// All the remote chain ratios are updated as well, if gas token price changed
    function _updateLocalChainInfo(uint128 _gasTokenPrice, uint128 _gasUnitPrice) internal {
        if (localInfo.gasTokenPrice != _gasTokenPrice) {
            // update ratios only if gas token price has changed
            uint256[] memory chainIds = remoteChainIds;
            for (uint256 i = 0; i < chainIds.length; ++i) {
                uint256 chainId = chainIds[i];
                ChainInfo memory info = remoteInfo[chainId];
                _updateRemoteChainRatios(_gasTokenPrice, chainId, info.gasTokenPrice, info.gasUnitPrice);
            }
        }

        localInfo = ChainInfo({gasTokenPrice: _gasTokenPrice, gasUnitPrice: _gasUnitPrice});

        // TODO: use context chainid here
        emit ChainInfoUpdated(block.chainid, _gasTokenPrice, _gasUnitPrice);
    }

    /// @dev Updates remote chain config:
    /// Amount of gas needed to do _updateRemoteChainInfo()
    /// Maximum airdrop available on this chain
    function _updateRemoteChainConfig(
        uint256 _remoteChainId,
        uint112 _gasDropMax,
        uint80 _gasUnitsRcvMsg,
        uint32 _minGasUsageFeeUsd
    ) internal {
        require(_gasUnitsRcvMsg != 0, "Gas amount is not set");
        ChainConfig memory config = remoteConfig[_remoteChainId];
        config.gasDropMax = _gasDropMax;
        config.gasUnitsRcvMsg = _gasUnitsRcvMsg;
        config.minGasUsageFeeUsd = _minGasUsageFeeUsd;
        remoteConfig[_remoteChainId] = config;
    }

    /// @dev Updates information about remote chain gas token/unit price.
    /// Remote chain ratios are updated as well.
    function _updateRemoteChainInfo(
        uint256 _remoteChainId,
        uint128 _gasTokenPrice,
        uint128 _gasUnitPrice
    ) internal {
        /**
         * @dev Some chains (i.e. Aurora) allow free transactions,
         * so we're not checking gasUnitPrice for being zero.
         * gasUnitPrice is never used as denominator, and there's
         * a minimum fee for gas usage, so this can't be taken advantage of.
         */
        require(_gasTokenPrice != 0, "Remote gas token price is not set");
        uint256 _localGasTokenPrice = localInfo.gasTokenPrice;
        require(_localGasTokenPrice != 0, "Local gas token price is not set");

        if (remoteInfo[_remoteChainId].gasTokenPrice == 0) {
            // store remote chainId only if it wasn't added already
            remoteChainIds.push(_remoteChainId);
        }

        remoteInfo[_remoteChainId] = ChainInfo({gasTokenPrice: _gasTokenPrice, gasUnitPrice: _gasUnitPrice});
        _updateRemoteChainRatios(_localGasTokenPrice, _remoteChainId, _gasTokenPrice, _gasUnitPrice);

        emit ChainInfoUpdated(_remoteChainId, _gasTokenPrice, _gasUnitPrice);
    }

    /// @dev Updates gas token/unit ratios for a given remote chain
    function _updateRemoteChainRatios(
        uint256 _localGasTokenPrice,
        uint256 _remoteChainId,
        uint256 _remoteGasTokenPrice,
        uint256 _remoteGasUnitPrice
    ) internal {
        remoteRatios[_remoteChainId] = ChainRatios({
            gasTokenPriceRatio: uint96((_remoteGasTokenPrice * 10**18) / _localGasTokenPrice),
            gasUnitPriceRatio: uint160((_remoteGasUnitPrice * _remoteGasTokenPrice * 10**18) / _localGasTokenPrice)
        });
    }

    /// @dev Updates the markups (see "Structs" docs).
    /// Markup = 0% means exactly the "projected gas cost" will be charged.
    function _updateMarkups(
        uint256 _remoteChainId,
        uint16 _markupGasDrop,
        uint16 _markupGasUsage
    ) internal {
        ChainConfig memory config = remoteConfig[_remoteChainId];
        config.markupGasDrop = _markupGasDrop;
        config.markupGasUsage = _markupGasUsage;
        remoteConfig[_remoteChainId] = config;
        emit MarkupsUpdated(_remoteChainId, _markupGasDrop, _markupGasUsage);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           MESSAGING LOGIC                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Sends "something updated" messages to all registered remote chains
    function _sendUpdateMessages(bytes memory _message) internal {
        (uint256 totalFee, uint256[] memory fees) = _estimateUpdateFees();
        require(msg.value >= totalFee, "msg.value doesn't cover all the fees");

        uint256[] memory chainIds = remoteChainIds;
        bytes32[] memory receivers = new bytes32[](chainIds.length);
        bytes[] memory options = new bytes[](chainIds.length);

        for (uint256 i = 0; i < chainIds.length; ++i) {
            uint256 chainId = chainIds[i];
            uint256 gasLimit = remoteConfig[chainId].gasUnitsRcvMsg;
            if (gasLimit == 0) gasLimit = DEFAULT_GAS_LIMIT;

            receivers[i] = trustedRemoteLookup[chainId];
            options[i] = Options.encode(gasLimit);
        }

        _send(receivers, chainIds, _message, options, fees, payable(msg.sender));
        if (msg.value > totalFee) payable(msg.sender).transfer(msg.value - totalFee);
    }

    /// @dev Handles the received message.
    function _handleMessage(
        bytes32,
        uint256 _localChainId,
        bytes memory _message,
        address
    ) internal override {
        uint8 msgType = GasFeePricingUpdates.messageType(_message);
        if (msgType == uint8(GasFeePricingUpdates.MsgType.UPDATE_CONFIG)) {
            (uint112 gasDropMax, uint80 gasUnitsRcvMsg, uint32 minGasUsageFeeUsd) = GasFeePricingUpdates.decodeConfig(
                _message
            );
            _updateRemoteChainConfig(_localChainId, gasDropMax, gasUnitsRcvMsg, minGasUsageFeeUsd);
        } else if (msgType == uint8(GasFeePricingUpdates.MsgType.UPDATE_INFO)) {
            (uint128 gasTokenPrice, uint128 gasUnitPrice) = GasFeePricingUpdates.decodeInfo(_message);
            _updateRemoteChainInfo(_localChainId, gasTokenPrice, gasUnitPrice);
        } else {
            revert("Unknown message type");
        }
    }
}
