// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Quoter} from "./Quoter.sol";

import {IBridgeRouter} from "./interfaces/IBridgeRouter.sol";
import {IBridgeQuoter} from "./interfaces/IBridgeQuoter.sol";

import {Offers} from "./libraries/LibOffers.sol";

contract BridgeQuoter is Quoter, IBridgeQuoter {
    /// @dev Setup flow:
    /// 1. Create BridgeRouter contract
    /// 2. Create BridgeQuoter contract
    /// 3. Give BridgeQuoter ADAPTERS_STORAGE_ROLE in BridgeRouter contract
    /// 4. Add tokens and adapters

    /// PS. If the migration from one BridgeQuoter to another is needed (w/0 changing BridgeRouter):
    /// 1. call oldBridgeQuoter.setAdapters([]), this will clear the adapters in BridgeRouter
    /// 2. revoke ADAPTERS_STORAGE_ROLE from oldBridgeQuoter
    /// 3. Do (2-4) from setup flow as usual
    constructor(address payable _router, uint8 _maxSwaps)
        Quoter(_router, _maxSwaps)
    {
        this;
    }

    function findBestPathDestinationChain(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) external view returns (Offers.FormattedOffer memory _bestOffer) {
        // Relayer pays for gas, so:
        // use maximum swaps permitted for bridge+swap transaction
        return
            findBestPath(
                _amountIn,
                _tokenIn,
                _tokenOut,
                IBridgeRouter(router).bridgeMaxSwaps()
            );
    }
}
