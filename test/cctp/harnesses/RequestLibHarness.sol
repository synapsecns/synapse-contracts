// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {RequestLib} from "../../../contracts/cctp/libs/Request.sol";

contract RequestLibHarness {
    function formatBaseRequest(
        uint32 originDomain,
        uint64 nonce,
        address originBurnToken,
        uint256 amount,
        address recipient
    ) public pure returns (bytes memory) {
        return RequestLib.formatBaseRequest(originDomain, nonce, originBurnToken, amount, recipient);
    }

    function formatSwapParams(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 deadline,
        uint256 minAmountOut
    ) public pure returns (bytes memory) {
        return RequestLib.formatSwapParams(pool, tokenIndexFrom, tokenIndexTo, deadline, minAmountOut);
    }

    function formatRequest(
        uint32 requestVersion,
        bytes memory baseRequest,
        bytes memory swapParams
    ) public pure returns (bytes memory) {
        return RequestLib.formatRequest(requestVersion, baseRequest, swapParams);
    }

    function decodeBaseRequest(bytes memory baseRequest)
        public
        pure
        returns (
            uint32 originDomain,
            uint64 nonce,
            address originBurnToken,
            uint256 amount,
            address recipient
        )
    {
        return RequestLib.decodeBaseRequest(baseRequest);
    }

    function decodeSwapParams(bytes memory swapParams)
        public
        pure
        returns (
            address pool,
            uint8 tokenIndexFrom,
            uint8 tokenIndexTo,
            uint256 deadline,
            uint256 minAmountOut
        )
    {
        return RequestLib.decodeSwapParams(swapParams);
    }

    function decodeRequest(uint32 requestVersion, bytes memory request)
        public
        pure
        returns (bytes memory baseRequest, bytes memory swapParams)
    {
        return RequestLib.decodeRequest(requestVersion, request);
    }
}
