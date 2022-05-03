// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

import "forge-std/Test.sol";

contract GasFeePricing is Ownable, Test {
    // DstChainId => The estimated current gas price in wei of the destination chain
    mapping(uint256 => uint256) public dstGasPriceInWei;
    // DstChainId => USD gas ratio of dstGasToken / srcGasToken
    mapping(uint256 => uint256) public dstGasTokenRatio;

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
    function setCostPerChain(
        uint256 _dstChainId,
        uint256 _gasUnitPrice,
        uint256 _gasTokenPriceRatio
    ) external onlyOwner {
        dstGasPriceInWei[_dstChainId] = _gasUnitPrice;
        dstGasTokenRatio[_dstChainId] = _gasTokenPriceRatio;
    }

    /**
     * @notice Returns srcGasToken fee to charge in wei for the cross-chain message based on the gas limit
     * @param _options Versioned struct used to instruct relayer on how to proceed with gas limits. Contains data on gas limit to submit tx with.
     */
    function estimateGasFee(uint256 _dstChainId, bytes memory _options)
        external
        view
        returns (uint256)
    {
        uint256 gasLimit;
        // temporary gas limit set
        if (_options.length != 0) {
            (
                uint16 txType,
                uint256 gasLimit,
                uint256 dstAirdrop,
                bytes32 dstAddress
            ) = decodeOptions(_options);
        } else {
            gasLimit = 200000;
        }

        uint256 minFee = ((dstGasPriceInWei[_dstChainId] *
            dstGasTokenRatio[_dstChainId] *
            gasLimit) / 10**18);

        return minFee;
    }

    function encodeOptions(uint16 txType, uint256 gasLimit)
        public
        pure
        returns (bytes memory)
    {
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
            uint16,
            uint256,
            uint256,
            bytes32
        )
    {
        // decoding the _options - reverts if type 2 and there is no dstNativeAddress
        require(
            _options.length == 34 || _options.length > 66,
            "Wrong _adapterParameters size"
        );
        uint16 txType;
        uint256 gasLimit;
        uint256 dstNativeAmt;
        bytes32 dstNativeAddress;
        assembly {
            txType := mload(add(_options, 2))
            gasLimit := mload(add(_options, 34))
        }

        if (txType == 2) {
            assembly {
                dstNativeAmt := mload(add(_options, 66))
                dstNativeAddress := mload(add(_options, 98))
            }
            require(dstNativeAmt != 0, "dstNativeAmt empty");
            require(dstNativeAddress != bytes32(0), "dstNativeAddress empty");
        }

        return (txType, gasLimit, dstNativeAmt, dstNativeAddress);
    }
}
