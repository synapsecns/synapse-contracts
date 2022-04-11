// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IQuoter} from "./IQuoter.sol";
import {Offers} from "../libraries/LibOffers.sol";

interface IBridgeQuoter is IQuoter {
    function findBestPathInitialChain(
        address tokenIn,
        uint256 amountIn,
        address tokenOut
    ) external view returns (Offers.FormattedOffer memory bestOffer);

    function findBestPathDestinationChain(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bool gasdropRequested
    ) external view returns (Offers.FormattedOffer memory bestOffer);

    function getAllBridgeTokensEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, address[] memory tokensGlobal);

    function getAllBridgeTokensNonEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, string[] memory tokensGlobal);

    function getTokenAddressEVM(address tokenLocal, uint256 chainId)
        external
        view
        returns (address tokenGlobal, bool isEnabled);

    function getTokenAddressNonEVM(address tokenLocal, uint256 chainId)
        external
        view
        returns (string memory tokenGlobal, bool isEnabled);
}
