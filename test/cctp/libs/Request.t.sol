// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IncorrectRequestLength, UnknownRequestVersion} from "../../../contracts/cctp/libs/Errors.sol";
import {RequestLibHarness, RequestLib} from "../harnesses/RequestLibHarness.sol";
import {Test} from "forge-std/Test.sol";

contract RequestLibraryTest is Test {
    // TODO: move outside of this contract
    struct RawBaseRequest {
        uint32 originDomain;
        uint64 nonce;
        address originBurnToken;
        uint256 amount;
        address recipient;
    }

    struct RawSwapParams {
        address pool;
        uint8 tokenIndexFrom;
        uint8 tokenIndexTo;
        uint256 deadline;
        uint256 minAmountOut;
    }

    RequestLibHarness public libHarness;

    uint256 public constant EXPECTED_BASE_REQUEST_LENGTH = 160;
    uint256 public constant EXPECTED_SWAP_PARAMS_LENGTH = 160;

    function setUp() public {
        libHarness = new RequestLibHarness();
    }

    function testFormatBaseRequest(RawBaseRequest memory rbr) public {
        bytes memory baseRequest = libHarness.formatBaseRequest(
            rbr.originDomain,
            rbr.nonce,
            rbr.originBurnToken,
            rbr.amount,
            rbr.recipient
        );
        assertEq(baseRequest, abi.encode(rbr.originDomain, rbr.nonce, rbr.originBurnToken, rbr.amount, rbr.recipient));
        assertEq(baseRequest.length, RequestLib.REQUEST_BASE_LENGTH);
        bytes memory fullRequest = libHarness.formatRequest(RequestLib.REQUEST_BASE, baseRequest, "");
        assertEq(fullRequest, baseRequest);
        (bytes memory baseRequest_, bytes memory swapParams_) = libHarness.decodeRequest(
            RequestLib.REQUEST_BASE,
            fullRequest
        );
        assertEq(baseRequest_, baseRequest);
        assertEq(swapParams_, "");
    }

    function testFormatSwapRequest(RawBaseRequest memory rbr, RawSwapParams memory rsp) public {
        bytes memory baseRequest = libHarness.formatBaseRequest(
            rbr.originDomain,
            rbr.nonce,
            rbr.originBurnToken,
            rbr.amount,
            rbr.recipient
        );
        bytes memory swapParams = libHarness.formatSwapParams(
            rsp.pool,
            rsp.tokenIndexFrom,
            rsp.tokenIndexTo,
            rsp.deadline,
            rsp.minAmountOut
        );
        bytes memory fullRequest = libHarness.formatRequest(RequestLib.REQUEST_SWAP, baseRequest, swapParams);
        assertEq(
            swapParams,
            abi.encode(rsp.pool, rsp.tokenIndexFrom, rsp.tokenIndexTo, rsp.deadline, rsp.minAmountOut)
        );
        assertEq(swapParams.length, RequestLib.SWAP_PARAMS_LENGTH);
        assertEq(
            fullRequest,
            abi.encode(
                abi.encode(rbr.originDomain, rbr.nonce, rbr.originBurnToken, rbr.amount, rbr.recipient),
                abi.encode(rsp.pool, rsp.tokenIndexFrom, rsp.tokenIndexTo, rsp.deadline, rsp.minAmountOut)
            )
        );
        (bytes memory baseRequest_, bytes memory swapParams_) = libHarness.decodeRequest(
            RequestLib.REQUEST_SWAP,
            fullRequest
        );
        assertEq(baseRequest_, baseRequest);
        assertEq(swapParams_, swapParams);
    }

    function testFormatRequestRevertsWhenIncorrectBaseRequestLength(uint8 length) public {
        vm.assume(length != EXPECTED_BASE_REQUEST_LENGTH); // See RequestLib.sol
        bytes memory baseRequest = new bytes(length);
        bytes memory swapParams = new bytes(EXPECTED_SWAP_PARAMS_LENGTH);
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.formatRequest(0, baseRequest, "");
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.formatRequest(1, baseRequest, swapParams);
    }

    function testFormatRequestRevertsWhenIncorrectSwapParamsLength(uint8 length) public {
        bytes memory baseRequest = new bytes(EXPECTED_BASE_REQUEST_LENGTH);
        bytes memory swapParams = new bytes(length);
        if (length != 0) {
            vm.expectRevert(IncorrectRequestLength.selector);
            libHarness.formatRequest(0, baseRequest, swapParams);
        }
        if (length != EXPECTED_SWAP_PARAMS_LENGTH) {
            vm.expectRevert(IncorrectRequestLength.selector);
            libHarness.formatRequest(1, baseRequest, swapParams);
        }
    }

    function testFormatRequestRevertsWhenUnknownVersion(uint32 version) public {
        vm.assume(version > RequestLib.REQUEST_SWAP);
        bytes memory baseRequest = new bytes(EXPECTED_BASE_REQUEST_LENGTH);
        bytes memory swapParams = new bytes(EXPECTED_SWAP_PARAMS_LENGTH);
        vm.expectRevert(UnknownRequestVersion.selector);
        libHarness.formatRequest(version, baseRequest, swapParams);
    }

    // ═════════════════════════════════════════════════ DECODING ══════════════════════════════════════════════════════

    function testDecodeBaseRequest(RawBaseRequest memory rbr) public {
        bytes memory baseRequest = libHarness.formatBaseRequest(
            rbr.originDomain,
            rbr.nonce,
            rbr.originBurnToken,
            rbr.amount,
            rbr.recipient
        );
        (uint32 originDomain, uint64 nonce, address originBurnToken, uint256 amount, address recipient) = libHarness
            .decodeBaseRequest(baseRequest);
        assertEq(originDomain, rbr.originDomain);
        assertEq(nonce, rbr.nonce);
        assertEq(originBurnToken, rbr.originBurnToken);
        assertEq(amount, rbr.amount);
        assertEq(recipient, rbr.recipient);
    }

    function testDecodeSwapParams(RawSwapParams memory rsp) public {
        bytes memory swapParams = libHarness.formatSwapParams(
            rsp.pool,
            rsp.tokenIndexFrom,
            rsp.tokenIndexTo,
            rsp.deadline,
            rsp.minAmountOut
        );
        (address pool, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 deadline, uint256 minAmountOut) = libHarness
            .decodeSwapParams(swapParams);
        assertEq(pool, rsp.pool);
        assertEq(tokenIndexFrom, rsp.tokenIndexFrom);
        assertEq(tokenIndexTo, rsp.tokenIndexTo);
        assertEq(deadline, rsp.deadline);
        assertEq(minAmountOut, rsp.minAmountOut);
    }
}
