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
     * gas token prices on src and dst chain, gas limit for executing message on dst chain
     * and gas unit price on dst chain. In other words, message sender is paying dst chain
     * gas fees (to cover gas usage and gasdrop), but in src chain gas token.
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
     * src and dst gas token prices, while gasUsageFee also takes into account dst chain gas
     * unit price, which is an extra source of volatility.
     *
     * Generally, markupGasUsage >= markupGasDrop >= 0%. While markups can be set to 0%,
     * this is not recommended.
     */

    /**
     * @dev Chain's Config is supposed to be PARTLY synchronized cross-chain, i.e.
     * GasFeePricing contracts on different chain will have the SAME values for
     * the same dst chain:
     * - gasDropMax: maximum gas airdrop available on chain
     *               uint112 => max value ~= 5 * 10**33
     * - gasUnitsRcvMsg: Amount of gas units needed for GasFeePricing contract
     *                   to receive "update chain Config/Info" message
     *                   uint112 => max value ~= 5 * 10**33
     * These are universal values, and they should be the same on all GasFeePricing
     * contracts.
     *
     * Some of the values, however, are set unique for every "src-dst" chain combination:
     * - markupGasDrop: Markup for gas airdrop
     *                  uint16 => max value = 65535
     * - markupGasUsage: Markup for gas usage
     *                   uint16 => max value = 65535
     * These values depend on correlation between src and dst chains. For instance,
     * if both chains have the same gas token (like ETH), markup for the gas drop
     * can be set to 0, as gasDrop is limited, and the slight price difference between ETH
     * on src and dst chain can not be taken advantage of.
     *
     * On the contrary, if src and dst gas tokens have proven to be not that correlated
     * in terms of their price, higher markup is needed to compensate potential price spikes.
     *
     * ChainConfig is optimized to fit into one word of storage.
     * ChainConfig is not supposed to be updated regularly (the values are more or less persistent).
     */

    struct ChainConfig {
        /// @dev Values below are synchronized cross-chain
        uint112 gasDropMax;
        uint112 gasUnitsRcvMsg;
        /// @dev Values below are src-chain specific
        uint16 markupGasDrop;
        uint16 markupGasUsage;
    }

    /**
     * @dev Chain's Info is supposed to be FULLY synchronized cross-chain, i.e.
     * GasFeePricing contracts on different chain will have the SAME values for
     * the same dst chain:
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
     * the same dst chain:
     * - gasTokenPriceRatio: USD price ratio of dstGasToken / srcGasToken, scaled to wei
     *                       uint96 => max value ~= 8 * 10**28
     * - gasUnitPriceRatio: How much 1 gas unit on dst chain is worth, expressed in src chain wei,
     *                      multiplied by 10**18 (aka in attoWei = 10^-18 wei)
     *                      uint160 => max value ~= 10**48
     * These values are updated whenever "gas information" is updated for either source or destination chain.
     *
     * ChainRatios is optimized to fit into one word of storage.
     */

    /**
     * @dev Chain's Ratios are used for calculating a fee for sending a msg from src to dst chain.
     * To calculate cost of tx gas airdrop (assuming gasDrop airdrop value):
     * (gasDrop * gasTokenPriceRatio) / 10**18
     * To calculate cost of tx gas usage on dst chain (assuming gasAmount gas units):
     * (gasAmount * gasUnitPriceRatio) / 10**18
     *
     * Both numbers are expressed in src chain wei.
     */
    struct ChainRatios {
        /// @dev Values below are src-chain specific
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
    ▏*║                      DESTINATION CHAINS STORAGE                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev dstChainId => Info
    mapping(uint256 => ChainInfo) public dstInfo;
    /// @dev dstChainId => Ratios
    mapping(uint256 => ChainRatios) public dstRatios;
    /// @dev dstChainId => Config
    mapping(uint256 => ChainConfig) public dstConfig;
    /// @dev list of all dst chain ids
    uint256[] internal dstChainIds;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         SOURCE CHAIN STORAGE                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev See "Structs" docs
    /// srcConfig.markupGasDrop and srcConfig.markupGasUsage values are not used
    ChainConfig public srcConfig;
    ChainInfo public srcInfo;
    /// @dev Minimum fee related to gas usage on dst chain
    uint256 public minGasUsageFee;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              CONSTANTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    uint256 public constant DEFAULT_MIN_FEE_USD = 10**18;

    uint256 public constant DEFAULT_GAS_LIMIT = 200000;
    uint256 public constant MARKUP_DENOMINATOR = 100;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             INITIALIZER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function initialize(address _messageBus, uint256 _srcGasTokenPrice) external initializer {
        __Ownable_init_unchained();
        messageBus = _messageBus;
        srcInfo.gasTokenPrice = uint96(_srcGasTokenPrice);
        minGasUsageFee = _calculateMinGasUsageFee(DEFAULT_MIN_FEE_USD, _srcGasTokenPrice);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Get the fee for sending a message to dst chain with given options
    function estimateGasFee(uint256 _dstChainId, bytes calldata _options) external view returns (uint256 fee) {
        fee = _estimateGasFee(_dstChainId, _options);
    }

    /// @notice Get the fee for sending a message to a bunch of chains with given options
    function estimateGasFees(uint256[] calldata _dstChainIds, bytes[] calldata _options)
        external
        view
        returns (uint256 fee)
    {
        require(_dstChainIds.length == _options.length, "!arrays");
        for (uint256 i = 0; i < _dstChainIds.length; ++i) {
            fee = fee + _estimateGasFee(_dstChainIds[i], _options[i]);
        }
    }

    /// @dev Extracts the gas information from options and calculates the messaging fee
    function _estimateGasFee(uint256 _dstChainId, bytes calldata _options) internal view returns (uint256 fee) {
        ChainConfig memory config = dstConfig[_dstChainId];
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

        fee = _estimateGasFee(_dstChainId, gasAirdrop, gasLimit, config.markupGasDrop, config.markupGasUsage);
    }

    /// @dev Returns a gas fee for sending a message to dst chain, given the amount of gas to airdrop,
    /// and amount of gas units for message execution on dst chain.
    function _estimateGasFee(
        uint256 _dstChainId,
        uint256 _gasAirdrop,
        uint256 _gasLimit,
        uint256 _markupGasDrop,
        uint256 _markupGasUsage
    ) internal view returns (uint256 fee) {
        ChainRatios memory dstRatio = dstRatios[_dstChainId];

        // Calculate how much gas airdrop is worth in src chain wei
        uint256 feeGasDrop = (_gasAirdrop * dstRatio.gasTokenPriceRatio) / 10**18;
        // Calculate how much gas usage is worth in src chain wei
        uint256 feeGasUsage = (_gasLimit * dstRatio.gasUnitPriceRatio) / 10**18;

        // Sum up the fees multiplied by their respective markups
        feeGasDrop = (feeGasDrop * (_markupGasDrop + MARKUP_DENOMINATOR)) / MARKUP_DENOMINATOR;
        feeGasUsage = (feeGasUsage * (_markupGasUsage + MARKUP_DENOMINATOR)) / MARKUP_DENOMINATOR;
        // Check if gas usage fee is lower than minimum
        uint256 _minGasUsageFee = minGasUsageFee;
        if (feeGasUsage < _minGasUsageFee) feeGasUsage = _minGasUsageFee;
        fee = feeGasDrop + feeGasUsage;
    }

    /// @notice Get total gas fee for calling updateChainInfo()
    function estimateUpdateFees() external view returns (uint256 totalFee) {
        (totalFee, ) = _estimateUpdateFees();
    }

    /// @dev Returns total gas fee for calling updateChainInfo(), as well as
    /// fee for each dst chain.
    function _estimateUpdateFees() internal view returns (uint256 totalFee, uint256[] memory fees) {
        uint256[] memory _chainIds = dstChainIds;
        fees = new uint256[](_chainIds.length);
        for (uint256 i = 0; i < _chainIds.length; ++i) {
            uint256 chainId = _chainIds[i];
            ChainConfig memory config = dstConfig[chainId];
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
    function setDstConfig(
        uint256[] memory _dstChainId,
        uint256[] memory _gasDropMax,
        uint256[] memory _gasUnitsRcvMsg
    ) external onlyOwner {
        require(_dstChainId.length == _gasDropMax.length && _dstChainId.length == _gasUnitsRcvMsg.length, "!arrays");
        for (uint256 i = 0; i < _dstChainId.length; ++i) {
            _updateDstChainConfig(_dstChainId[i], _gasDropMax[i], _gasUnitsRcvMsg[i]);
        }
    }

    /// @notice Update information about gas unit/token price for a bunch of chains.
    /// Handy for initial setup.
    function setDstInfo(
        uint256[] memory _dstChainId,
        uint256[] memory _gasTokenPrice,
        uint256[] memory _gasUnitPrice
    ) external onlyOwner {
        require(_dstChainId.length == _gasTokenPrice.length && _dstChainId.length == _gasUnitPrice.length, "!arrays");
        for (uint256 i = 0; i < _dstChainId.length; ++i) {
            _updateDstChainInfo(_dstChainId[i], _gasTokenPrice[i], _gasUnitPrice[i]);
        }
    }

    /// @notice Sets markups (see "Structs" docs) for a bunch of chains. Markups are used for determining
    /// how much fee to charge on top of "projected gas cost" of delivering the message.
    function setDstMarkups(
        uint256[] memory _dstChainId,
        uint16[] memory _markupGasDrop,
        uint16[] memory _markupGasUsage
    ) external onlyOwner {
        require(_dstChainId.length == _markupGasDrop.length && _dstChainId.length == _markupGasUsage.length, "!arrays");
        for (uint256 i = 0; i < _dstChainId.length; ++i) {
            _updateMarkups(_dstChainId[i], _markupGasDrop[i], _markupGasUsage[i]);
        }
    }

    /// @notice Update the minimum fee for gas usage on message delivery. Quoted in src chain wei.
    function setMinFee(uint256 _minGasUsageFee) external onlyOwner {
        minGasUsageFee = _minGasUsageFee;
    }

    /// @notice Update the minimum fee for gas usage on message delivery. Quoted in USD, scaled to wei.
    function setMinFeeUsd(uint256 _minGasUsageFeeUsd) external onlyOwner {
        minGasUsageFee = _calculateMinGasUsageFee(_minGasUsageFeeUsd, srcInfo.gasTokenPrice);
    }

    /// @notice Update information about source chain config:
    /// amount of gas needed to do _updateDstChainInfo()
    /// and maximum airdrop available on this chain
    function updateSrcConfig(uint256 _gasDropMax, uint256 _gasUnitsRcvMsg) external payable onlyOwner {
        require(_gasUnitsRcvMsg != 0, "Gas amount is not set");
        _sendUpdateMessages(uint8(GasFeePricingUpdates.MsgType.UPDATE_CONFIG), _gasDropMax, _gasUnitsRcvMsg);
        ChainConfig memory config = srcConfig;
        config.gasDropMax = uint112(_gasDropMax);
        config.gasUnitsRcvMsg = uint112(_gasUnitsRcvMsg);
        srcConfig = config;
    }

    /// @notice Update information about source chain gas token/unit price on all configured dst chains,
    /// as well as on the source chain itself.
    function updateSrcInfo(uint256 _gasTokenPrice, uint256 _gasUnitPrice) external payable onlyOwner {
        /**
         * @dev Some chains (i.e. Aurora) allow free transactions,
         * so we're not checking gasUnitPrice for being zero.
         * gasUnitPrice is never used as denominator, and there's
         * a minimum fee for gas usage, so this can't be taken advantage of.
         */
        require(_gasTokenPrice != 0, "Gas token price is not set");
        // send messages before updating the values, so that it's possible to use
        // estimateUpdateFees() to calculate the needed fee for the update
        _sendUpdateMessages(uint8(GasFeePricingUpdates.MsgType.UPDATE_INFO), _gasTokenPrice, _gasUnitPrice);
        _updateSrcChainInfo(_gasTokenPrice, _gasUnitPrice);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          UPDATE STATE LOGIC                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Updates information about src chain gas token/unit price.
    /// All the dst chain ratios are updated as well, if gas token price changed
    function _updateSrcChainInfo(uint256 _gasTokenPrice, uint256 _gasUnitPrice) internal {
        if (srcInfo.gasTokenPrice != _gasTokenPrice) {
            // update ratios only if gas token price has changed
            uint256[] memory chainIds = dstChainIds;
            for (uint256 i = 0; i < chainIds.length; ++i) {
                uint256 chainId = chainIds[i];
                ChainInfo memory info = dstInfo[chainId];
                _updateDstChainRatios(_gasTokenPrice, chainId, info.gasTokenPrice, info.gasUnitPrice);
            }
        }

        srcInfo = ChainInfo({gasTokenPrice: uint128(_gasTokenPrice), gasUnitPrice: uint128(_gasUnitPrice)});

        // TODO: use context chainid here
        emit ChainInfoUpdated(block.chainid, _gasTokenPrice, _gasUnitPrice);
    }

    /// @dev Updates dst chain config:
    /// Amount of gas needed to do _updateDstChainInfo()
    /// Maximum airdrop available on this chain
    function _updateDstChainConfig(
        uint256 _dstChainId,
        uint256 _gasDropMax,
        uint256 _gasUnitsRcvMsg
    ) internal {
        require(_gasUnitsRcvMsg != 0, "Gas amount is not set");
        ChainConfig memory config = dstConfig[_dstChainId];
        config.gasDropMax = uint112(_gasDropMax);
        config.gasUnitsRcvMsg = uint112(_gasUnitsRcvMsg);
        dstConfig[_dstChainId] = config;
    }

    /// @dev Updates information about dst chain gas token/unit price.
    /// Dst chain ratios are updated as well.
    function _updateDstChainInfo(
        uint256 _dstChainId,
        uint256 _gasTokenPrice,
        uint256 _gasUnitPrice
    ) internal {
        /**
         * @dev Some chains (i.e. Aurora) allow free transactions,
         * so we're not checking gasUnitPrice for being zero.
         * gasUnitPrice is never used as denominator, and there's
         * a minimum fee for gas usage, so this can't be taken advantage of.
         */
        require(_gasTokenPrice != 0, "Dst gas token price is not set");
        uint256 _srcGasTokenPrice = srcInfo.gasTokenPrice;
        require(_srcGasTokenPrice != 0, "Src gas token price is not set");

        if (dstInfo[_dstChainId].gasTokenPrice == 0) {
            // store dst chainId only if it wasn't added already
            dstChainIds.push(_dstChainId);
        }

        dstInfo[_dstChainId] = ChainInfo({
            gasTokenPrice: uint128(_gasTokenPrice),
            gasUnitPrice: uint128(_gasUnitPrice)
        });
        _updateDstChainRatios(_srcGasTokenPrice, _dstChainId, _gasTokenPrice, _gasUnitPrice);

        emit ChainInfoUpdated(_dstChainId, _gasTokenPrice, _gasUnitPrice);
    }

    /// @dev Updates gas token/unit ratios for a given dst chain
    function _updateDstChainRatios(
        uint256 _srcGasTokenPrice,
        uint256 _dstChainId,
        uint256 _dstGasTokenPrice,
        uint256 _dstGasUnitPrice
    ) internal {
        dstRatios[_dstChainId] = ChainRatios({
            gasTokenPriceRatio: uint96((_dstGasTokenPrice * 10**18) / _srcGasTokenPrice),
            gasUnitPriceRatio: uint160((_dstGasUnitPrice * _dstGasTokenPrice * 10**18) / _srcGasTokenPrice)
        });
    }

    /// @dev Updates the markups (see "Structs" docs).
    /// Markup = 0% means exactly the "projected gas cost" will be charged.
    function _updateMarkups(
        uint256 _dstChainId,
        uint16 _markupGasDrop,
        uint16 _markupGasUsage
    ) internal {
        ChainConfig memory config = dstConfig[_dstChainId];
        config.markupGasDrop = _markupGasDrop;
        config.markupGasUsage = _markupGasUsage;
        dstConfig[_dstChainId] = config;
        emit MarkupsUpdated(_dstChainId, _markupGasDrop, _markupGasUsage);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           MESSAGING LOGIC                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Sends "something updated" messages to all registered dst chains
    function _sendUpdateMessages(
        uint8 _msgType,
        uint256 _newValueA,
        uint256 _newValueB
    ) internal {
        (uint256 totalFee, uint256[] memory fees) = _estimateUpdateFees();
        require(msg.value >= totalFee, "msg.value doesn't cover all the fees");

        bytes memory message = GasFeePricingUpdates.encode(_msgType, uint128(_newValueA), uint128(_newValueB));
        uint256[] memory chainIds = dstChainIds;
        bytes32[] memory receivers = new bytes32[](chainIds.length);
        bytes[] memory options = new bytes[](chainIds.length);

        for (uint256 i = 0; i < chainIds.length; ++i) {
            uint256 chainId = chainIds[i];
            uint256 gasLimit = dstConfig[chainId].gasUnitsRcvMsg;
            if (gasLimit == 0) gasLimit = DEFAULT_GAS_LIMIT;

            receivers[i] = trustedRemoteLookup[chainId];
            options[i] = Options.encode(gasLimit);
        }

        _send(receivers, chainIds, message, options, fees, payable(msg.sender));
        if (msg.value > totalFee) payable(msg.sender).transfer(msg.value - totalFee);
    }

    /// @dev Handles the received message.
    function _handleMessage(
        bytes32,
        uint256 _srcChainId,
        bytes memory _message,
        address
    ) internal override {
        (uint8 msgType, uint128 newValueA, uint128 newValueB) = GasFeePricingUpdates.decode(_message);
        if (msgType == uint8(GasFeePricingUpdates.MsgType.UPDATE_CONFIG)) {
            _updateDstChainConfig(_srcChainId, newValueA, newValueB);
        } else if (msgType == uint8(GasFeePricingUpdates.MsgType.UPDATE_INFO)) {
            _updateDstChainInfo(_srcChainId, newValueA, newValueB);
        } else {
            revert("Unknown message type");
        }
    }
}
