// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./framework/SynMessagingReceiverUpgradeable.sol";
import "./interfaces/IGasFeePricing.sol";
import "./libraries/Options.sol";

contract GasFeePricingUpgradeable is SynMessagingReceiverUpgradeable, IGasFeePricing {
    /*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                                      STRUCTS                                   
    __________________________________________________________________________*/

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

    /*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                                       EVENTS                                   
    __________________________________________________________________________*/

    event ChainInfoUpdated(uint256 indexed chainId, uint256 gasTokenPrice, uint256 gasUnitPrice);

    event MarkupsUpdated(uint256 markupGasDrop, uint256 markupGasUsage);

    /*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                             DESTINATION CHAINS STORAGE                         
    __________________________________________________________________________*/

    // dstChainId => Info
    mapping(uint256 => ChainInfo) public dstInfo;
    // dstChainId => Ratios
    mapping(uint256 => ChainRatios) public dstRatios;
    // dstChainId => Config
    mapping(uint256 => ChainConfig) public dstConfig;

    /*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                                SOURCE CHAIN STORAGE                            
    __________________________________________________________________________*/

    ChainInfo public srcInfo;

    // how much message sender is paying, multiple of "estimated price"
    // markup of 100% means user is paying exactly the projected price
    // set this more than 100% to make sure messaging fees cover the expenses to deliver the msg
    uint128 public markupGasDrop;
    uint128 public markupGasUsage;

    /*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                                     CONSTANTS                                  
    __________________________________________________________________________*/

    uint256 public constant DEFAULT_GAS_LIMIT = 200000;
    uint256 public constant MARKUP_DENOMINATOR = 100;

    /*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                                    INITIALIZER                                 
    __________________________________________________________________________*/

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

    /*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                                       VIEWS                                    
    __________________________________________________________________________*/

    /// @notice Get the fee for sending a message to dst chain with given options
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

    /*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                                     ONLY OWNER                                 
    __________________________________________________________________________*/

    /// @dev Update information about gas unit/token price for a dst chain.
    function setCostPerChain(
        uint256 _dstChainId,
        uint256 _gasUnitPrice,
        uint256 _gasTokenPrice
    ) external onlyOwner {
        _setCostPerChain(_dstChainId, _gasUnitPrice, _gasTokenPrice);
    }

    /// @notice Updates markups, that are used for determining how much fee
    //  to charge on top of "projected gas cost" of delivering the message
    function updateMarkups(uint128 _markupGasDrop, uint128 _markupGasUsage) external onlyOwner {
        _updateMarkups(_markupGasDrop, _markupGasUsage);
    }

    /*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                                 UPDATE STATE LOGIC                             
    __________________________________________________________________________*/

    /// @dev Updates information about dst chain gas token/unit price.
    /// Dst chain ratios are updated as well.
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

    /*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                                  MESSAGING LOGIC                               
    __________________________________________________________________________*/

    /// @dev Handles the received message.
    function _handleMessage(
        bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes memory _message,
        address _executor
    ) internal override {}
}
