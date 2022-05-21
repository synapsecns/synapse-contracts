// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./framework/SynMessagingReceiverUpgradeable.sol";
import "./interfaces/IGasFeePricing.sol";
import "./libraries/Options.sol";

contract GasFeePricingUpgradeable is SynMessagingReceiverUpgradeable, IGasFeePricing {
    /*┌──────────────────────────────────────────────────────────────────────┐
      │                               STRUCTS                                │
      └──────────────────────────────────────────────────────────────────────┘*/

    /// @dev Dst chain's basic variables, that are unlikely to change over time.
    struct ChainConfig {
        // Amount of gas units needed to receive "update chainInfo" message
        uint128 gasAmountNeeded;
        // Maximum gas airdrop available on chain
        uint128 maxGasDrop;
    }

    /// @dev Information about dst chain's gas price, which can change over time
    /// due to gas token price movement, or gas spikes.
    struct ChainInfo {
        // Price of chain's gas token in USD, scaled to wei
        uint128 gasTokenPrice;
        // Price of chain's 1 gas unit in wei
        uint128 gasUnitPrice;
    }

    /// @dev Ratio between src and dst gas price ratio.
    /// Used for calculating a fee for sending a msg from src to dst chain.
    /// Updated whenever "gas information" is changed for either source or destination chain.
    struct ChainRatios {
        // USD price ratio of dstGasToken / srcGasToken, scaled to wei
        uint96 gasTokenPriceRatio;
        // How much 1 gas unit on dst chain is worth,
        // expressed in src chain wei, multiplied by 10**18 (aka in attoWei = 10^-18 wei)
        uint160 gasUnitPriceRatio;
        // To calculate gas cost of tx on dst chain, which consumes gasAmount gas units:
        // (gasAmount * gasUnitPriceRatio) / 10**18
        // This number is expressed in src chain wei
    }

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                                EVENTS                                │
      └──────────────────────────────────────────────────────────────────────┘*/

    event ChainInfoUpdated(uint256 indexed chainId, uint256 gasTokenPrice, uint256 gasUnitPrice);

    event MarkupsUpdated(uint256 markupGasDrop, uint256 markupGasUsage);

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                      DESTINATION CHAINS STORAGE                      │
      └──────────────────────────────────────────────────────────────────────┘*/

    // dstChainId => Info
    mapping(uint256 => ChainInfo) public dstInfo;
    // dstChainId => Ratios
    mapping(uint256 => ChainRatios) public dstRatios;
    // dstChainId => Config
    mapping(uint256 => ChainConfig) public dstConfig;
    // dstChainId => GasFeePricing contract address
    mapping(uint256 => bytes32) public dstGasFeePricing;

    uint256[] internal dstChainIds;

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                         SOURCE CHAIN STORAGE                         │
      └──────────────────────────────────────────────────────────────────────┘*/

    ChainConfig public srcConfig;
    ChainInfo public srcInfo;

    uint256 public minGasUsageFee;

    // how much message sender is paying, multiple of "estimated price"
    // markup of 100% means user is paying exactly the projected price
    // set this more than 100% to make sure messaging fees cover the expenses to deliver the msg
    uint128 public markupGasDrop;
    uint128 public markupGasUsage;

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                              CONSTANTS                               │
      └──────────────────────────────────────────────────────────────────────┘*/

    uint256 public constant DEFAULT_MIN_FEE_USD = 10**18;

    uint256 public constant DEFAULT_GAS_LIMIT = 200000;
    uint256 public constant MARKUP_DENOMINATOR = 100;

    uint8 public constant CHAIN_CONFIG_UPDATED = 1;
    uint8 public constant CHAIN_INFO_UPDATED = 2;

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                             INITIALIZER                              │
      └──────────────────────────────────────────────────────────────────────┘*/

    function initialize(
        address _messageBus,
        uint256 _srcGasTokenPrice,
        uint128 _markupGasDrop,
        uint128 _markupGasUsage
    ) external initializer {
        __Ownable_init_unchained();
        messageBus = _messageBus;
        srcInfo.gasTokenPrice = uint96(_srcGasTokenPrice);
        minGasUsageFee = _calculateMinGasUsageFee(DEFAULT_MIN_FEE_USD, _srcGasTokenPrice);
        _updateMarkups(_markupGasDrop, _markupGasUsage);
    }

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                                VIEWS                                 │
      └──────────────────────────────────────────────────────────────────────┘*/

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
        uint256 gasAirdrop;
        uint256 gasLimit;
        if (_options.length != 0) {
            (gasLimit, gasAirdrop, ) = Options.decode(_options);
            if (gasAirdrop != 0) {
                require(gasAirdrop <= dstConfig[_dstChainId].maxGasDrop, "GasDrop higher than max");
            }
        } else {
            gasLimit = DEFAULT_GAS_LIMIT;
        }

        fee = _estimateGasFee(_dstChainId, gasAirdrop, gasLimit);
    }

    /// @dev Returns a gas fee for sending a message to dst chain, given the amount of gas to airdrop,
    /// and amount of gas units for message execution on dst chain.
    function _estimateGasFee(
        uint256 _dstChainId,
        uint256 _gasAirdrop,
        uint256 _gasLimit
    ) internal view returns (uint256 fee) {
        ChainRatios memory dstRatio = dstRatios[_dstChainId];
        (uint128 _markupGasDrop, uint128 _markupGasUsage) = (markupGasDrop, markupGasUsage);

        // Calculate how much gas airdrop is worth in src chain wei
        uint256 feeGasDrop = (_gasAirdrop * dstRatio.gasTokenPriceRatio) / 10**18;
        // Calculate how much gas usage is worth in src chain wei
        uint256 feeGasUsage = (_gasLimit * dstRatio.gasUnitPriceRatio) / 10**18;

        // Sum up the fees multiplied by their respective markups
        feeGasDrop = (feeGasDrop * _markupGasDrop) / MARKUP_DENOMINATOR;
        feeGasUsage = (feeGasUsage * _markupGasUsage) / MARKUP_DENOMINATOR;
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
            uint256 gasLimit = dstConfig[chainId].gasAmountNeeded;
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

    /// @dev Converts address to bytes32
    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                              ONLY OWNER                              │
      └──────────────────────────────────────────────────────────────────────┘*/

    /// @dev Update information about gas unit/token price for a dst chain.
    function setCostPerChain(
        uint256 _dstChainId,
        uint256 _gasUnitPrice,
        uint256 _gasTokenPrice
    ) external onlyOwner {
        _updateDstChainInfo(_dstChainId, _gasUnitPrice, _gasTokenPrice);
    }

    /// @notice Update information about gas unit/token price for a bunch of chains.
    /// Handy for initial setup.
    function setCostPerChains(
        uint256[] memory _dstChainIds,
        uint256[] memory _gasUnitPrices,
        uint256[] memory _gasTokenPrices
    ) external onlyOwner {
        require(
            _dstChainIds.length == _gasUnitPrices.length && _dstChainIds.length == _gasTokenPrices.length,
            "!arrays"
        );
        for (uint256 i = 0; i < _dstChainIds.length; ++i) {
            _updateDstChainInfo(_dstChainIds[i], _gasUnitPrices[i], _gasTokenPrices[i]);
        }
    }

    /// @dev Update config (gasLimit for sending messages to chain, max gas airdrop) for a dst chain.
    function setDstChainConfig(
        uint256 _dstChainId,
        uint256 _gasAmountNeeded,
        uint256 _maxGasDrop
    ) external onlyOwner {
        _updateDstChainConfig(_dstChainId, _gasAmountNeeded, _maxGasDrop);
    }

    /// @dev Update config (gasLimit for sending messages to chain, max gas airdrop) for a bunch of chains.
    function setDstChainConfigs(
        uint256[] memory _dstChainIds,
        uint256[] memory _gasAmountsNeeded,
        uint256[] memory _maxGasDrops
    ) external onlyOwner {
        require(
            _dstChainIds.length == _gasAmountsNeeded.length && _dstChainIds.length == _maxGasDrops.length,
            "!arrays"
        );
        for (uint256 i = 0; i < _dstChainIds.length; ++i) {
            _updateDstChainConfig(_dstChainIds[i], _gasAmountsNeeded[i], _maxGasDrops[i]);
        }
    }

    /// @notice Update GasFeePricing addresses on a bunch of dst chains. Needed for cross-chain setups.
    function setGasFeePricingAddresses(uint256[] memory _dstChainIds, address[] memory _dstGasFeePricing)
        external
        onlyOwner
    {
        require(_dstChainIds.length == _dstGasFeePricing.length, "!arrays");
        for (uint256 i = 0; i < _dstChainIds.length; ++i) {
            dstGasFeePricing[_dstChainIds[i]] = _addressToBytes32(_dstGasFeePricing[i]);
        }
    }

    /// @notice Update the minimum fee for gas usage on message delivery. Quoted in src chain wei.
    function setMinGasUsageFee(uint256 _minGasUsageFee) external onlyOwner {
        minGasUsageFee = _minGasUsageFee;
    }

    /// @notice Update the minimum fee for gas usage on message delivery. Quoted in USD.
    function setMinGasUsageFeeUsd(uint256 _minGasUsageFeeUsd) external onlyOwner {
        minGasUsageFee = _calculateMinGasUsageFee(_minGasUsageFeeUsd, srcInfo.gasTokenPrice);
    }

    /// @notice Update information about source chain config:
    /// amount of gas needed to do _updateDstChainInfo()
    /// and maximum airdrop available on this chain
    function updateChainConfig(uint256 _gasAmountNeeded, uint256 _maxGasDrop) external payable onlyOwner {
        _sendUpdateMessages(CHAIN_CONFIG_UPDATED, _gasAmountNeeded, _maxGasDrop);
        srcConfig = ChainConfig({gasAmountNeeded: uint128(_gasAmountNeeded), maxGasDrop: uint128(_maxGasDrop)});
    }

    /// @notice Update information about source chain gas token/unit price on all configured dst chains,
    /// as well as on the source chain itself.
    function updateChainInfo(uint256 _gasTokenPrice, uint256 _gasUnitPrice) external payable onlyOwner {
        // send messages before updating the values, so that it's possible to use
        // estimateUpdateFees() to calculate the needed fee for the update
        _sendUpdateMessages(CHAIN_INFO_UPDATED, _gasTokenPrice, _gasUnitPrice);
        _updateSrcChainInfo(_gasTokenPrice, _gasUnitPrice);
    }

    /// @notice Updates markups, that are used for determining how much fee
    //  to charge on top of "projected gas cost" of delivering the message
    function updateMarkups(uint128 _markupGasDrop, uint128 _markupGasUsage) external onlyOwner {
        _updateMarkups(_markupGasDrop, _markupGasUsage);
    }

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                          UPDATE STATE LOGIC                          │
      └──────────────────────────────────────────────────────────────────────┘*/

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
        uint256 _gasAmountNeeded,
        uint256 _maxGasDrop
    ) internal {
        dstConfig[_dstChainId] = ChainConfig({
            gasAmountNeeded: uint128(_gasAmountNeeded),
            maxGasDrop: uint128(_maxGasDrop)
        });
    }

    /// @dev Updates information about dst chain gas token/unit price.
    /// Dst chain ratios are updated as well.
    function _updateDstChainInfo(
        uint256 _dstChainId,
        uint256 _gasUnitPrice,
        uint256 _gasTokenPrice
    ) internal {
        require(_gasUnitPrice != 0 && _gasTokenPrice != 0, "Can't set to zero");
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

    /// @dev Updates the markups.
    /// Markup = 100% means exactly the "projected gas cost" will be charged.
    /// Thus, markup can't be lower than 100%.
    function _updateMarkups(uint128 _markupGasDrop, uint128 _markupGasUsage) internal {
        require(
            _markupGasDrop >= MARKUP_DENOMINATOR && _markupGasUsage >= MARKUP_DENOMINATOR,
            "Markup can not be lower than 1"
        );
        (markupGasDrop, markupGasUsage) = (_markupGasDrop, _markupGasUsage);
        emit MarkupsUpdated(_markupGasDrop, _markupGasUsage);
    }

    /*┌──────────────────────────────────────────────────────────────────────┐
      │                           MESSAGING LOGIC                            │
      └──────────────────────────────────────────────────────────────────────┘*/

    /// @dev Sends "something updated" messages to all registered dst chains
    function _sendUpdateMessages(
        uint8 _msgType,
        uint256 _newValueA,
        uint256 _newValueB
    ) internal {
        (uint256 totalFee, uint256[] memory fees) = _estimateUpdateFees();
        require(msg.value >= totalFee, "msg.value doesn't cover all the fees");

        bytes memory message = _encodeMessage(_msgType, uint128(_newValueA), uint128(_newValueB));
        uint256[] memory chainIds = dstChainIds;
        bytes32[] memory receivers = new bytes32[](chainIds.length);
        bytes[] memory options = new bytes[](chainIds.length);

        for (uint256 i = 0; i < chainIds.length; ++i) {
            uint256 chainId = chainIds[i];
            uint256 gasLimit = dstConfig[chainId].gasAmountNeeded;
            if (gasLimit == 0) gasLimit = DEFAULT_GAS_LIMIT;

            receivers[i] = dstGasFeePricing[chainId];
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
        (uint8 msgType, uint128 newValueA, uint128 newValueB) = _decodeMessage(_message);
        if (msgType == CHAIN_CONFIG_UPDATED) {
            _updateDstChainConfig(_srcChainId, newValueA, newValueB);
        } else if (msgType == CHAIN_INFO_UPDATED) {
            _updateDstChainInfo(_srcChainId, newValueA, newValueB);
        } else {
            revert("Unknown message type");
        }
    }

    /// @dev Encodes "something updated" message. We're taking advantage that
    /// whether it's chain config or info, it's always two uint128 values that were updated.
    function _encodeMessage(
        uint8 _msgType,
        uint128 _newValueA,
        uint128 _newValueB
    ) internal pure returns (bytes memory) {
        return abi.encode(_msgType, _newValueA, _newValueB);
    }

    /// @dev Decodes "something updated" message.
    function _decodeMessage(bytes memory _message)
        internal
        pure
        returns (
            uint8 msgType,
            uint128 newValueA,
            uint128 newValueB
        )
    {
        (msgType, newValueA, newValueB) = abi.decode(_message, (uint8, uint128, uint128));
    }
}
