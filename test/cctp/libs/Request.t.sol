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
    // Extra data is two offsets (32 bytes each) and a length (32 bytes)
    uint256 public constant EXPECTED_SWAP_REQUEST_LENGTH =
        4 * 32 + EXPECTED_BASE_REQUEST_LENGTH + EXPECTED_SWAP_PARAMS_LENGTH;

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
        bytes memory swapRequest = libHarness.formatRequest(RequestLib.REQUEST_BASE, baseRequest, "");
        assertEq(swapRequest, baseRequest);
        (bytes memory baseRequest_, bytes memory swapParams_) = libHarness.decodeRequest(
            RequestLib.REQUEST_BASE,
            swapRequest
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
        bytes memory swapRequest = libHarness.formatRequest(RequestLib.REQUEST_SWAP, baseRequest, swapParams);
        assertEq(
            swapParams,
            abi.encode(rsp.pool, rsp.tokenIndexFrom, rsp.tokenIndexTo, rsp.deadline, rsp.minAmountOut)
        );
        assertEq(swapParams.length, RequestLib.SWAP_PARAMS_LENGTH);
        assertEq(
            swapRequest,
            abi.encode(
                abi.encode(rbr.originDomain, rbr.nonce, rbr.originBurnToken, rbr.amount, rbr.recipient),
                abi.encode(rsp.pool, rsp.tokenIndexFrom, rsp.tokenIndexTo, rsp.deadline, rsp.minAmountOut)
            )
        );
        assertEq(swapRequest.length, RequestLib.REQUEST_SWAP_LENGTH);
        (bytes memory baseRequest_, bytes memory swapParams_) = libHarness.decodeRequest(
            RequestLib.REQUEST_SWAP,
            swapRequest
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

    function testDecodeBaseRequestRevertsWhenIncorrectLength(uint256 length) public {
        length = length % 1024;
        vm.assume(length != EXPECTED_BASE_REQUEST_LENGTH);
        bytes memory baseRequest = new bytes(length);
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.decodeBaseRequest(baseRequest);
    }

    function testDecodeBaseRequestWithExtraBytes() public {
        bytes memory baseRequest = abi.encodePacked(
            libHarness.formatBaseRequest(1, 2, address(3), 4, address(5)),
            type(uint256).max
        );
        // Default ABI decoding ignores extra bytes
        (uint32 originDomain, uint64 nonce, address originBurnToken, uint256 amount, address recipient) = abi.decode(
            baseRequest,
            (uint32, uint64, address, uint256, address)
        );
        assertEq(originDomain, 1);
        assertEq(nonce, 2);
        assertEq(originBurnToken, address(3));
        assertEq(amount, 4);
        assertEq(recipient, address(5));
        // Decoding library should throw an error
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.decodeBaseRequest(baseRequest);
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

    function testDecodeSwapParamsRevertsWhenIncorrectLength(uint256 length) public {
        length = length % 1024;
        vm.assume(length != EXPECTED_SWAP_PARAMS_LENGTH);
        bytes memory swapParams = new bytes(length);
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.decodeSwapParams(swapParams);
    }

    function testDecodeSwapParamsWithExtraBytes() public {
        bytes memory swapParams = abi.encodePacked(
            libHarness.formatSwapParams(address(1), 2, 3, 4, 5),
            type(uint256).max
        );
        // Default ABI decoding ignores extra bytes
        (address pool, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 deadline, uint256 minAmountOut) = abi.decode(
            swapParams,
            (address, uint8, uint8, uint256, uint256)
        );
        assertEq(pool, address(1));
        assertEq(tokenIndexFrom, 2);
        assertEq(tokenIndexTo, 3);
        assertEq(deadline, 4);
        assertEq(minAmountOut, 5);
        // Decoding library should throw an error
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.decodeSwapParams(swapParams);
    }

    function testDecodeRequestRevertsWhenIncorrectLength(uint256 length) public {
        length = length % 1024;
        bytes memory request = new bytes(length);
        if (length != EXPECTED_BASE_REQUEST_LENGTH) {
            vm.expectRevert(IncorrectRequestLength.selector);
            libHarness.decodeRequest(RequestLib.REQUEST_BASE, request);
        }
        if (length != EXPECTED_SWAP_REQUEST_LENGTH) {
            vm.expectRevert(IncorrectRequestLength.selector);
            libHarness.decodeRequest(RequestLib.REQUEST_SWAP, request);
        }
    }

    function testDecodeRequestRevertsUnknownRequestVersion(uint32 version) public {
        vm.assume(version > RequestLib.REQUEST_SWAP);
        vm.expectRevert(UnknownRequestVersion.selector);
        libHarness.decodeRequest(version, new bytes(0));
    }

    function testDecodeRequestWithExtraBytes() public {
        bytes memory baseRequest = libHarness.formatBaseRequest(1, 2, address(3), 4, address(5));
        bytes memory swapParams = libHarness.formatSwapParams(address(6), 7, 8, 9, 10);
        bytes memory swapRequest = abi.encodePacked(
            libHarness.formatRequest(1, baseRequest, swapParams),
            type(uint256).max
        );
        // Default ABI decoding ignores extra bytes
        (bytes memory baseRequest_, bytes memory swapParams_) = abi.decode(swapRequest, (bytes, bytes));
        assertEq(baseRequest_, baseRequest);
        assertEq(swapParams_, swapParams);
        // Decoding library should throw an error
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.decodeRequest(RequestLib.REQUEST_SWAP, swapRequest);
    }
}
