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
        bytes memory result = RequestLib.formatBaseRequest(originDomain, nonce, originBurnToken, amount, recipient);
        return result;
    }

    function formatSwapParams(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 deadline,
        uint256 minAmountOut
    ) public pure returns (bytes memory) {
        bytes memory result = RequestLib.formatSwapParams(pool, tokenIndexFrom, tokenIndexTo, deadline, minAmountOut);
        return result;
    }

    function formatRequest(
        uint32 requestVersion,
        bytes memory baseRequest,
        bytes memory swapParams
    ) public pure returns (bytes memory) {
        bytes memory result = RequestLib.formatRequest(requestVersion, baseRequest, swapParams);
        return result;
    }

    function decodeBaseRequest(bytes memory baseRequest)
        public
        pure
        returns (
            uint32,
            uint64,
            address,
            uint256,
            address
        )
    {
        (uint32 originDomain, uint64 nonce, address originBurnToken, uint256 amount, address recipient) = RequestLib
            .decodeBaseRequest(baseRequest);
        return (originDomain, nonce, originBurnToken, amount, recipient);
    }

    function decodeSwapParams(bytes memory swapParams)
        public
        pure
        returns (
            address,
            uint8,
            uint8,
            uint256,
            uint256
        )
    {
        (address pool, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 deadline, uint256 minAmountOut) = RequestLib
            .decodeSwapParams(swapParams);
        return (pool, tokenIndexFrom, tokenIndexTo, deadline, minAmountOut);
    }

    function decodeRequest(uint32 requestVersion, bytes memory request)
        public
        pure
        returns (bytes memory, bytes memory)
    {
        (bytes memory baseRequest, bytes memory swapParams) = RequestLib.decodeRequest(requestVersion, request);
        return (baseRequest, swapParams);
    }
}
