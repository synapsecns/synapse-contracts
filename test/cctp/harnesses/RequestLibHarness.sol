// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Request, RequestLib} from "../../../contracts/cctp/libs/Request.sol";

contract RequestLibHarness {
    function formatBaseRequest(
        uint32 originDomain_,
        uint64 nonce_,
        address originBurnToken_,
        uint256 amount_,
        address recipient_
    ) public pure returns (bytes memory formattedRequest) {
        formattedRequest = RequestLib.formatBaseRequest(originDomain_, nonce_, originBurnToken_, amount_, recipient_);
    }

    function formatSwapParams(
        address pool_,
        uint8 tokenIndexFrom_,
        uint8 tokenIndexTo_,
        uint80 deadline_,
        uint256 minAmountOut_
    ) public pure returns (bytes memory formattedSwapParams) {
        formattedSwapParams = RequestLib.formatSwapParams(
            pool_,
            tokenIndexFrom_,
            tokenIndexTo_,
            deadline_,
            minAmountOut_
        );
    }

    function formatRequest(
        uint32 requestVersion,
        bytes memory baseRequest_,
        bytes memory swapParams_
    ) public pure returns (bytes memory formattedRequest) {
        formattedRequest = RequestLib.formatRequest(requestVersion, baseRequest_, swapParams_);
    }

    function wrapRequest(uint32 requestVersion, bytes memory request) public pure {
        RequestLib.wrapRequest(requestVersion, request);
    }

    function originData(uint32 requestVersion, bytes memory formattedRequest)
        public
        pure
        returns (
            uint32 originDomain,
            uint64 nonce,
            address originBurnToken,
            uint256 amount
        )
    {
        Request request = RequestLib.wrapRequest(requestVersion, formattedRequest);
        return request.originData();
    }

    function recipient(uint32 requestVersion, bytes memory formattedRequest) public pure returns (address) {
        Request request = RequestLib.wrapRequest(requestVersion, formattedRequest);
        return request.recipient();
    }

    function swapParams(uint32 requestVersion, bytes memory formattedRequest)
        public
        pure
        returns (
            address pool,
            uint8 tokenIndexFrom,
            uint8 tokenIndexTo,
            uint80 deadline,
            uint256 minAmountOut
        )
    {
        Request request = RequestLib.wrapRequest(requestVersion, formattedRequest);
        return request.swapParams();
    }
}
