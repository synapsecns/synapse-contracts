// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./framework/SynMessagingReceiverUpgradeable.sol";
import "./interfaces/IGasFeePricing.sol";
import "./libraries/Bytes32AddressLib.sol";
import "./libraries/OptionsLib.sol";
import "./libraries/PricingUpdateLib.sol";

contract MessageExecutorUpgradeable is SynMessagingReceiverUpgradeable {
    using Bytes32AddressLib for bytes32;

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
     *                      when sending message to a given chain.
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
        uint256 gasAirdrop;
        uint256 gasLimit;
        if (_options.length != 0) {
            (gasLimit, gasAirdrop, ) = OptionsLib.decode(_options);
        } else {
            gasLimit = DEFAULT_GAS_LIMIT;
        }
        fee = _estimateGasFee(_remoteChainId, gasAirdrop, gasLimit);
    }

    /// @dev Returns a gas fee for sending a message to remote chain, given the amount of gas to airdrop,
    /// and amount of gas units for message execution on remote chain.
    function _estimateGasFee(
        uint256 _chainId,
        uint256 _gasAirdrop,
        uint256 _gasLimit
    ) internal view returns (uint256 fee) {
        // Read config/info for destination (remote) chain
        ChainConfig memory dstConfig = remoteConfig[_chainId];
        ChainInfo memory dstInfo = remoteInfo[_chainId];
        // Read info for source (local) chain
        ChainInfo memory srcInfo = localInfo;
        require(_gasAirdrop <= dstConfig.gasDropMax, "GasDrop higher than max");

        // Calculate how much [gas airdrop] is worth in [local chain wei]
        uint256 feeGasDrop = (_gasAirdrop * dstInfo.gasTokenPrice) / srcInfo.gasTokenPrice;
        // Calculate how much [gas usage] is worth in [local chain wei]
        uint256 feeGasUsage = (_gasLimit * dstInfo.gasUnitPrice * dstInfo.gasTokenPrice) / srcInfo.gasTokenPrice;

        // Sum up the fees multiplied by their respective markups
        feeGasDrop = (feeGasDrop * (dstConfig.markupGasDrop + MARKUP_DENOMINATOR)) / MARKUP_DENOMINATOR;
        feeGasUsage = (feeGasUsage * (dstConfig.markupGasUsage + MARKUP_DENOMINATOR)) / MARKUP_DENOMINATOR;

        // Calculate min fee (specific to destination chain)
        // Multiply by 10**18 to convert to wei
        // Multiply by 10**18 again, as gasTokenPrice is scaled by 10**18
        // Divide by USD_DENOMINATOR, as minGasUsageFeeUsd is scaled by USD_DENOMINATOR
        uint256 minFee = (uint256(dstConfig.minGasUsageFeeUsd) * 10**36) /
            (uint256(srcInfo.gasTokenPrice) * USD_DENOMINATOR);
        if (feeGasUsage < minFee) feeGasUsage = minFee;

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
            uint256 gasLimit = remoteConfig[chainId].gasUnitsRcvMsg;
            if (gasLimit == 0) gasLimit = DEFAULT_GAS_LIMIT;

            uint256 fee = _estimateGasFee(chainId, 0, gasLimit);
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
        _sendUpdateMessages(PricingUpdateLib.encodeConfig(_gasDropMax, _gasUnitsRcvMsg, _minGasUsageFeeUsd));
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
        _sendUpdateMessages(PricingUpdateLib.encodeInfo(_gasTokenPrice, _gasUnitPrice));
        _updateLocalChainInfo(_gasTokenPrice, _gasUnitPrice);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          UPDATE STATE LOGIC                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Updates information about local chain gas token/unit price.
    function _updateLocalChainInfo(uint128 _gasTokenPrice, uint128 _gasUnitPrice) internal {
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
        emit ChainInfoUpdated(_remoteChainId, _gasTokenPrice, _gasUnitPrice);
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
            options[i] = OptionsLib.encode(gasLimit);
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
        uint8 msgType = PricingUpdateLib.messageType(_message);
        if (msgType == uint8(PricingUpdateLib.MsgType.UPDATE_CONFIG)) {
            (uint112 gasDropMax, uint80 gasUnitsRcvMsg, uint32 minGasUsageFeeUsd) = PricingUpdateLib.decodeConfig(
                _message
            );
            _updateRemoteChainConfig(_localChainId, gasDropMax, gasUnitsRcvMsg, minGasUsageFeeUsd);
        } else if (msgType == uint8(PricingUpdateLib.MsgType.UPDATE_INFO)) {
            (uint128 gasTokenPrice, uint128 gasUnitPrice) = PricingUpdateLib.decodeInfo(_message);
            _updateRemoteChainInfo(_localChainId, gasTokenPrice, gasUnitPrice);
        } else {
            revert("Unknown message type");
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       EXECUTING MESSAGES LOGIC                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function executeMessage(
        uint256 _srcChainId,
        bytes32 _srcAddress,
        address _dstAddress,
        bytes calldata _message,
        bytes calldata _options
    ) external returns (address gasDropRecipient, uint256 gasDropAmount) {
        require(msg.sender == messageBus, "!messageBus");

        (uint256 gasLimit, uint256 _gasDropAmount, bytes32 _dstReceiver) = OptionsLib.decode(_options);
        if (_gasDropAmount != 0) {
            // check if requested airdrop is not more than max allowed
            uint256 maxGasDropAmount = localConfig.gasDropMax;
            // cap gas airdrop to max amount if needed
            if (_gasDropAmount > maxGasDropAmount) _gasDropAmount = maxGasDropAmount;
            // check airdrop amount again, in case max amount was 0
            if (_gasDropAmount != 0) {
                address payable receiver = payable(_dstReceiver.fromLast20Bytes());
                if (receiver != address(0)) {
                    if (receiver.send(_gasDropAmount)) {
                        gasDropRecipient = receiver;
                        gasDropAmount = _gasDropAmount;
                    }
                }
            }
        }
        // tx.origin is in fact the initial message executor on local chain
        // TODO: do we need to pass that information though?
        ISynMessagingReceiver(_dstAddress).executeMessage{gas: gasLimit}(_srcAddress, _srcChainId, _message, tx.origin);
    }
}
