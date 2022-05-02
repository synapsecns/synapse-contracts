// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../utils/DefaultBridgeTest.t.sol";

contract BridgeQuoterTest is DefaultBridgeTest {
    /**
     * @notice Checks that BridgeQuoter correctly finds best path between tokens on source chain,
     * when given chainId & bridge token address on dst EVM chain as tokenOut
     */
    function testBestPathToBridgeEVM(
        uint8 indexFrom,
        uint8 _indexTo,
        uint64 _amountIn
    ) public {
        vm.assume(indexFrom < allTokens.length);
        vm.assume(_indexTo < bridgeTokens.length);
        (address bridgeToken, uint8 indexTo) = _getBridgeToken(_indexTo);
        vm.assume(indexFrom != indexTo);

        uint256 amountIn = uint256(_amountIn) << 20;
        Offers.FormattedOffer memory offerA = quoter.bestPathToBridgeEVM(
            address(allTokens[indexFrom]),
            amountIn,
            ID_EVM,
            tokenAddressEVM[bridgeToken]
        );

        Offers.FormattedOffer memory offerB = quoter.findBestPath(
            address(allTokens[indexFrom]),
            amountIn,
            bridgeToken,
            _config.maxSwaps
        );

        _checkOffers(offerA, offerB);
    }

    /**
     * @notice Checks that BridgeQuoter correctly finds best path between tokens on source chain,
     * when given chainId & bridge token address on dst non-EVM chain as tokenOut
     */
    function testBestPathToBridgeNonEVM(
        uint8 indexFrom,
        uint8 _indexTo,
        uint64 _amountIn
    ) public {
        vm.assume(indexFrom < allTokens.length);
        vm.assume(_indexTo < bridgeTokens.length);
        (address bridgeToken, uint8 indexTo) = _getBridgeToken(_indexTo);
        vm.assume(indexFrom != indexTo);

        uint256 amountIn = uint256(_amountIn) << 20;
        Offers.FormattedOffer memory offerA = quoter.bestPathToBridgeNonEVM(
            address(allTokens[indexFrom]),
            amountIn,
            ID_NON_EVM,
            tokenAddressNonEVM[bridgeToken]
        );

        Offers.FormattedOffer memory offerB = quoter.findBestPath(
            address(allTokens[indexFrom]),
            amountIn,
            bridgeToken,
            _config.maxSwaps
        );

        _checkOffers(offerA, offerB);
    }

    /**
     * @notice Checks that BridgeQuoter correctly finds best path between two tokens on destination chains,
     * taking bridge fee into account.
     */
    function testBestPathFromBridge(
        uint8 _indexFrom,
        uint8 indexTo,
        uint64 _amountIn,
        bool gasdropRequested
    ) public {
        vm.assume(indexTo < allTokens.length);
        vm.assume(_indexFrom < bridgeTokens.length);
        (address bridgeToken, uint8 indexFrom) = _getBridgeToken(_indexFrom);
        vm.assume(indexFrom != indexTo);

        // use at least minTotalFee: (1+4)*minFee w/o gasDrop, (1+2+4)*minFee w/ gasDrop
        uint256 amountIn = _getMinFee(bridgeToken) * (gasdropRequested ? 7 : 5) + _amountIn + 1;
        uint8 amountOfSwaps = _config.bridgeMaxSwaps;
        (uint256 fee, , , ) = bridgeConfig.calculateBridgeFee(bridgeToken, amountIn, gasdropRequested, amountOfSwaps);

        Offers.FormattedOffer memory offerA = quoter.bestPathFromBridge(
            bridgeToken,
            amountIn,
            address(allTokens[indexTo]),
            gasdropRequested
        );

        Offers.FormattedOffer memory offerB = quoter.findBestPath(
            bridgeToken,
            amountIn - fee,
            address(allTokens[indexTo]),
            amountOfSwaps
        );

        _checkOffers(offerA, offerB);
    }

    /**
     * @notice Checks that BridgeQuoter correctly finds best path between two tokens on destination chains,
     * when given chainId & bridge token address on src EVM chain, taking bridge fee into account.
     */
    function testBestPathFromBridgeEVM(
        uint8 _indexFrom,
        uint8 indexTo,
        uint64 _amountIn,
        bool gasdropRequested
    ) public {
        vm.assume(indexTo < allTokens.length);
        vm.assume(_indexFrom < bridgeTokens.length);
        (address bridgeToken, uint8 indexFrom) = _getBridgeToken(_indexFrom);
        vm.assume(indexFrom != indexTo);

        // use at least minTotalFee: (1+4)*minFee w/o gasDrop, (1+2+4)*minFee w/ gasDrop
        uint256 amountIn = _getMinFee(bridgeToken) * (gasdropRequested ? 7 : 5) + _amountIn + 1;
        uint8 amountOfSwaps = _config.bridgeMaxSwaps;
        (uint256 fee, , , ) = bridgeConfig.calculateBridgeFee(bridgeToken, amountIn, gasdropRequested, amountOfSwaps);

        Offers.FormattedOffer memory offerA = quoter.bestPathFromBridgeEVM(
            ID_EVM,
            tokenAddressEVM[bridgeToken],
            amountIn,
            address(allTokens[indexTo]),
            gasdropRequested
        );

        Offers.FormattedOffer memory offerB = quoter.findBestPath(
            bridgeToken,
            amountIn - fee,
            address(allTokens[indexTo]),
            amountOfSwaps
        );

        _checkOffers(offerA, offerB);
    }

    /**
     * @notice Checks that BridgeQuoter correctly finds best path between two tokens on destination chains,
     * when given chainId & bridge token address on src non-EVM chain, taking bridge fee into account.
     */
    function testBestPathFromBridgeNonEVM(
        uint8 _indexFrom,
        uint8 indexTo,
        uint64 _amountIn,
        bool gasdropRequested
    ) public {
        vm.assume(indexTo < allTokens.length);
        vm.assume(_indexFrom < bridgeTokens.length);
        (address bridgeToken, uint8 indexFrom) = _getBridgeToken(_indexFrom);
        vm.assume(indexFrom != indexTo);

        // use at least minTotalFee: (1+4)*minFee w/o gasDrop, (1+2+4)*minFee w/ gasDrop
        uint256 amountIn = _getMinFee(bridgeToken) * (gasdropRequested ? 7 : 5) + _amountIn + 1;
        uint8 amountOfSwaps = _config.bridgeMaxSwaps;
        (uint256 fee, , , ) = bridgeConfig.calculateBridgeFee(bridgeToken, amountIn, gasdropRequested, amountOfSwaps);

        Offers.FormattedOffer memory offerA = quoter.bestPathFromBridgeNonEVM(
            ID_NON_EVM,
            tokenAddressNonEVM[bridgeToken],
            amountIn,
            address(allTokens[indexTo]),
            gasdropRequested
        );

        Offers.FormattedOffer memory offerB = quoter.findBestPath(
            bridgeToken,
            amountIn - fee,
            address(allTokens[indexTo]),
            amountOfSwaps
        );

        _checkOffers(offerA, offerB);
    }

    /**
     * @notice Checks that BridgeQuoter correctly gives bridged token amount,
     * when given chainId & bridge token address on src EVM chain, taking bridge fee into account.
     */
    function testBestPathFromBridgeNonEVMNoSwap(uint8 _indexFrom, uint64 _amountIn) public {
        vm.assume(_indexFrom < bridgeTokens.length);
        (address bridgeToken, ) = _getBridgeToken(_indexFrom);

        // use at least minTotalFee: (1+4)*minFee w/o gasDrop, (1+2+4)*minFee w/ gasDrop
        uint256 amountIn = _getMinFee(bridgeToken) * 5 + _amountIn + 1;
        uint8 amountOfSwaps = 0;
        (uint256 fee, , , ) = bridgeConfig.calculateBridgeFee(bridgeToken, amountIn, true, amountOfSwaps);

        Offers.FormattedOffer memory offerA = quoter.bestPathFromBridgeNonEVM(
            ID_NON_EVM,
            tokenAddressNonEVM[bridgeToken],
            amountIn
        );

        Offers.FormattedOffer memory offerB;

        offerB.path = new address[](1);
        offerB.path[0] = bridgeToken;

        offerB.amounts = new uint256[](1);
        offerB.amounts[0] = amountIn - fee;

        _checkOffers(offerA, offerB);
    }

    function _checkOffers(Offers.FormattedOffer memory offerA, Offers.FormattedOffer memory offerB) internal {
        assertEq(keccak256(abi.encode(offerA)), keccak256(abi.encode(offerB)), "Wrong path found");
    }
}
