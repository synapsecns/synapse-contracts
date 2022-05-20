// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./framework/SynMessagingReceiverUpgradeable.sol";
import "./interfaces/IGasFeePricing.sol";
import "./libraries/Options.sol";

contract GasFeePricingUpgradeable is SynMessagingReceiverUpgradeable, IGasFeePricing {
    struct ChainConfig {
        // Amount of gas units needed to receive "update chainInfo" message
        uint128 gasAmountNeeded;
        // Maximum gas airdrop available on chain
        uint128 maxGasDrop;
    }

    struct ChainInfo {
        // Price of chain's gas token in USD, scaled to wei
        uint128 gasTokenPrice;
        // Price of chain's 1 gas unit in wei
        uint128 gasUnitPrice;
    }

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

    event ChainInfoUpdated(uint256 indexed chainId, uint256 gasTokenPrice, uint256 gasUnitPrice);

    event MarkupsUpdated(uint256 markupGasDrop, uint256 markupGasUsage);

    // dstChainId => Info
    mapping(uint256 => ChainInfo) public dstInfo;
    // dstChainId => Ratios
    mapping(uint256 => ChainRatios) public dstRatios;
    // dstChainId => Config
    mapping(uint256 => ChainConfig) public dstConfig;

    ChainInfo public srcInfo;

    // how much message sender is paying, multiple of "estimated price"
    // markup of 100% means user is paying exactly the projected price
    // set this more than 100% to make sure messaging fees cover the expenses to deliver the msg
    uint128 public markupGasDrop;
    uint128 public markupGasUsage;

    uint256 public constant DEFAULT_GAS_LIMIT = 200000;
    uint256 public constant MARKUP_DENOMINATOR = 100;

    function initialize(
        address _messageBus,
        uint256 _srcGasTokenPrice,
        uint128 _markupGasDrop,
        uint128 _markupGasUsage
    ) external initializer {
        __Ownable_init_unchained();
        messageBus = _messageBus;
        srcInfo.gasTokenPrice = uint96(_srcGasTokenPrice);
        _updateMarkups(_markupGasDrop, _markupGasUsage);
    }

    function estimateGasFee(uint256 _dstChainId, bytes calldata _options) external view returns (uint256 fee) {
        uint256 gasLimit;
        uint256 dstAirdrop;
        if (_options.length != 0) {
            (gasLimit, dstAirdrop, ) = Options.decode(_options);
            if (dstAirdrop != 0) {
                require(dstAirdrop <= dstConfig[_dstChainId].maxGasDrop, "GasDrop higher than max");
            }
        } else {
            gasLimit = DEFAULT_GAS_LIMIT;
        }

        ChainRatios memory dstRatio = dstRatios[_dstChainId];
        (uint128 _markupGasDrop, uint128 _markupGasUsage) = (markupGasDrop, markupGasUsage);

        // Calculate how much gas airdrop is worth in src chain wei
        uint256 feeGasDrop = (dstAirdrop * dstRatio.gasTokenPriceRatio) / 10**18;
        // Calculate how much gas usage is worth in src chain wei
        uint256 feeGasUsage = (gasLimit * dstRatio.gasUnitPriceRatio) / 10**18;

        // Sum up the fees multiplied by their respective markups
        fee = (feeGasDrop * _markupGasDrop + feeGasUsage * _markupGasUsage) / MARKUP_DENOMINATOR;
    }

    function setCostPerChain(
        uint256 _dstChainId,
        uint256 _gasUnitPrice,
        uint256 _gasTokenPrice
    ) external onlyOwner {
        _setCostPerChain(_dstChainId, _gasUnitPrice, _gasTokenPrice);
    }

    function updateMarkups(uint128 _markupGasDrop, uint128 _markupGasUsage) external onlyOwner {
        _updateMarkups(_markupGasDrop, _markupGasUsage);
    }

    function _setCostPerChain(
        uint256 _dstChainId,
        uint256 _gasUnitPrice,
        uint256 _gasTokenPrice
    ) internal {
        require(_gasUnitPrice != 0 && _gasTokenPrice != 0, "Can't set to zero");
        uint256 _srcGasTokenPrice = srcInfo.gasTokenPrice;
        require(_srcGasTokenPrice != 0, "Src gas token price is not set");

        dstInfo[_dstChainId] = ChainInfo({
            gasTokenPrice: uint128(_gasTokenPrice),
            gasUnitPrice: uint128(_gasUnitPrice)
        });
        dstRatios[_dstChainId] = ChainRatios({
            gasTokenPriceRatio: uint96((_gasTokenPrice * 10**18) / _srcGasTokenPrice),
            gasUnitPriceRatio: uint160((_gasUnitPrice * _gasTokenPrice * 10**18) / _srcGasTokenPrice)
        });

        emit ChainInfoUpdated(_dstChainId, _gasTokenPrice, _gasUnitPrice);
    }

    function _updateMarkups(uint128 _markupGasDrop, uint128 _markupGasUsage) internal {
        require(
            _markupGasDrop >= MARKUP_DENOMINATOR && _markupGasUsage >= MARKUP_DENOMINATOR,
            "Markup can not be lower than 1"
        );
        (markupGasDrop, markupGasUsage) = (_markupGasDrop, _markupGasUsage);
        emit MarkupsUpdated(_markupGasDrop, _markupGasUsage);
    }

    function _handleMessage(
        bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes memory _message,
        address _executor
    ) internal override {}
}
