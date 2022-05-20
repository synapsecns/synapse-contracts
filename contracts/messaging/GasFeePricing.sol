// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract GasFeePricing is Ownable {
    // DstChainId => (estimated gas price of the destination chain) * (USD gas ratio of dstGasToken / srcGasToken)
    // both multiples are in wei, so their multiple would be the gas price on dst chain,
    // expressed in source chain's 10^(-18) wei = attoWei
    mapping(uint256 => uint256) public dstGasPriceInSrcAttoWei;

    constructor() {}

    /**
     * @notice Permissioned method to allow an off-chain party to set what each dstChain's
     * gas cost is priced in the srcChain's native gas currency.
     * Example: call on ETH, setCostPerChain(43114, 30000000000, 25180000000000000)
     * chain ID 43114
     * Average of 30 gwei cost to transaction on 43114
     * AVAX/ETH = 0.02518, scaled to gas in wei = 25180000000000000
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     * @param _gasUnitPrice The estimated current gas price in wei of the destination chain
     * @param _gasTokenPriceRatio USD gas ratio of dstGasToken / srcGasToken
     */
    // Example:
    // DstChainId = 1666600000
    // Harmony set gwei to 200000000000
    // ONE / JEWEL = 0.05 == 50000000000000000

    // DstChainId = 53935
    // DFK Chain set 1 gwei = 1000000000
    // JEWEL / ONE = 20000000000000000000
    function setCostPerChain(
        uint256 _dstChainId,
        uint256 _gasUnitPrice,
        uint256 _gasTokenPriceRatio
    ) external onlyOwner {
        require(_gasUnitPrice != 0 && _gasTokenPriceRatio != 0, "Can't set to zero");
        dstGasPriceInSrcAttoWei[_dstChainId] = _gasUnitPrice * _gasTokenPriceRatio;
    }

    /**
     * @notice Returns srcGasToken fee to charge in wei for the cross-chain message based on the gas limit
     * @param _options Versioned struct used to instruct relayer on how to proceed with gas limits. Contains data on gas limit to submit tx with.
     */
    function estimateGasFee(uint256 _dstChainId, bytes memory _options) external view returns (uint256) {
        uint256 gasLimit;
        // temporary gas limit set
        if (_options.length != 0) {
            (uint16 _txType, uint256 _gasLimit, uint256 _dstAirdrop, bytes32 _dstAddress) = decodeOptions(_options);
            gasLimit = _gasLimit;
        } else {
            gasLimit = 200000;
        }

        // divide by 10**18 to convert attoWei into wei
        uint256 minFee = (dstGasPriceInSrcAttoWei[_dstChainId] * gasLimit) / 10**18;

        return minFee;
    }

    function encodeOptions(uint16 txType, uint256 gasLimit) public pure returns (bytes memory) {
        return abi.encodePacked(txType, gasLimit);
    }

    function encodeOptions(
        uint16 txType,
        uint256 gasLimit,
        uint256 dstNativeAmt,
        bytes32 dstAddress
    ) public pure returns (bytes memory) {
        return abi.encodePacked(txType, gasLimit, dstNativeAmt, dstAddress);
    }

    function decodeOptions(bytes memory _options)
        public
        pure
        returns (
            uint16 txType,
            uint256 gasLimit,
            uint256 dstNativeAmt,
            bytes32 dstNativeAddress
        )
    {
        // decoding the _options - reverts if type 2 and there is no dstNativeAddress
        require(_options.length == 34 || _options.length > 66, "Wrong _options size");
        // solhint-disable-next-line
        assembly {
            txType := mload(add(_options, 2))
            gasLimit := mload(add(_options, 34))
        }

        if (txType == 2) {
            // solhint-disable-next-line
            assembly {
                dstNativeAmt := mload(add(_options, 66))
                dstNativeAddress := mload(add(_options, 98))
            }
            require(dstNativeAmt != 0, "dstNativeAmt empty");
            require(dstNativeAddress != bytes32(0), "dstNativeAddress empty");
        }
    }
}
