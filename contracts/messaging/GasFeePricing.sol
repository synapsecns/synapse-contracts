// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract GasFeePricing is Ownable {
    // DstChainId => The estimated current gas price in wei of the destination chain
    mapping(uint256 => uint256) public dstGasPriceInWei;
    // DstChainId => USD gas ratio of dstGasToken / srcGasToken
    mapping(uint256 => uint256) public dstGasTokenRatio;

    constructor() public {}

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
    function estimateGasFee(uint256 _dstChainId, bytes calldata _options)
        external
        view
        returns (uint256)
    {
        // temporary gas limit set
        uint256 gasLimit = 200000;
        return ((dstGasPriceInWei[_dstChainId] *
            dstGasTokenRatio[_dstChainId] *
            gasLimit) / 10**18);
    }
}
