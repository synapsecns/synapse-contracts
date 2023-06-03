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

    struct RawSwapRequest {
        address pool;
        uint8 tokenIndexFrom;
        uint8 tokenIndexTo;
        uint80 deadline;
        uint256 minAmountOut;
    }

    RequestLibHarness public libHarness;

    uint256 public constant EXPECTED_BASE_REQUEST_LENGTH = 84;
    uint256 public constant EXPECTED_SWAP_PARAMS_LENGTH = 64;
    uint256 public constant EXPECTED_SWAP_REQUEST_LENGTH = 148;

    function setUp() public {
        libHarness = new RequestLibHarness();
    }

    function testFormatBaseRequest(RawBaseRequest memory rbr) public {
        bytes memory formattedRequest = libHarness.formatBaseRequest(
            rbr.originDomain,
            rbr.nonce,
            rbr.originBurnToken,
            rbr.amount,
            rbr.recipient
        );
        assertEq(
            formattedRequest,
            abi.encodePacked(rbr.originDomain, rbr.nonce, rbr.originBurnToken, rbr.amount, rbr.recipient)
        );
        assertEq(formattedRequest, libHarness.formatRequest(RequestLib.REQUEST_BASE, formattedRequest, ""));
        (uint32 originDomain, uint64 nonce, address originBurnToken, uint256 amount) = libHarness.originData(
            0,
            formattedRequest
        );
        assertEq(originDomain, rbr.originDomain);
        assertEq(nonce, rbr.nonce);
        assertEq(originBurnToken, rbr.originBurnToken);
        assertEq(amount, rbr.amount);
        assertEq(libHarness.recipient(0, formattedRequest), rbr.recipient);
    }

    function testFormatSwapRequest(RawBaseRequest memory rbr, RawSwapRequest memory rsr) public {
        bytes memory formattedBaseRequest = libHarness.formatBaseRequest(
            rbr.originDomain,
            rbr.nonce,
            rbr.originBurnToken,
            rbr.amount,
            rbr.recipient
        );
        bytes memory formattedSwapParams = libHarness.formatSwapParams(
            rsr.pool,
            rsr.tokenIndexFrom,
            rsr.tokenIndexTo,
            rsr.deadline,
            rsr.minAmountOut
        );
        bytes memory formattedRequest = libHarness.formatRequest(
            RequestLib.REQUEST_SWAP,
            formattedBaseRequest,
            formattedSwapParams
        );
        assertEq(
            formattedSwapParams,
            abi.encodePacked(rsr.pool, rsr.tokenIndexFrom, rsr.tokenIndexTo, rsr.deadline, rsr.minAmountOut)
        );
        assertEq(
            formattedRequest,
            abi.encodePacked(
                rbr.originDomain,
                rbr.nonce,
                rbr.originBurnToken,
                rbr.amount,
                rbr.recipient,
                rsr.pool,
                rsr.tokenIndexFrom,
                rsr.tokenIndexTo,
                rsr.deadline,
                rsr.minAmountOut
            )
        );
        (uint32 originDomain, uint64 nonce, address originBurnToken, uint256 amount) = libHarness.originData(
            1,
            formattedRequest
        );
        assertEq(originDomain, rbr.originDomain);
        assertEq(nonce, rbr.nonce);
        assertEq(originBurnToken, rbr.originBurnToken);
        assertEq(amount, rbr.amount);
        assertEq(libHarness.recipient(1, formattedRequest), rbr.recipient);
        (address pool, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint80 deadline, uint256 minAmountOut) = libHarness
            .swapParams(1, formattedRequest);
        assertEq(pool, rsr.pool);
        assertEq(tokenIndexFrom, rsr.tokenIndexFrom);
        assertEq(tokenIndexTo, rsr.tokenIndexTo);
        assertEq(deadline, rsr.deadline);
        assertEq(minAmountOut, rsr.minAmountOut);
    }

    function testFormatBaseRequestIncorrectBaseRequestLength(uint8 length) public {
        vm.assume(length != EXPECTED_BASE_REQUEST_LENGTH); // See RequestLib.sol
        bytes memory baseRequest = new bytes(length);
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.formatRequest(0, baseRequest, "");
    }

    function testFormatSwapRequestIncorrectBaseRequestLength(uint8 length) public {
        vm.assume(length != EXPECTED_BASE_REQUEST_LENGTH); // See RequestLib.sol
        bytes memory baseRequest = new bytes(length);
        bytes memory swapParams = new bytes(64);
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.formatRequest(1, baseRequest, swapParams);
    }

    function testFormatBaseRequestIncorrectSwapParamsLength(uint8 length) public {
        vm.assume(length != 0);
        bytes memory baseRequest = new bytes(EXPECTED_BASE_REQUEST_LENGTH);
        bytes memory swapParams = new bytes(length);
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.formatRequest(0, baseRequest, swapParams);
    }

    function testFormatSwapRequestIncorrectSwapParamsLength(uint8 length) public {
        vm.assume(length != EXPECTED_SWAP_PARAMS_LENGTH);
        bytes memory baseRequest = new bytes(EXPECTED_BASE_REQUEST_LENGTH);
        bytes memory swapParams = new bytes(length);
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.formatRequest(1, baseRequest, swapParams);
    }

    function testFormatRequestIncorrectVersion(uint32 version) public {
        vm.assume(version > RequestLib.REQUEST_SWAP);
        bytes memory baseRequest = new bytes(EXPECTED_BASE_REQUEST_LENGTH);
        bytes memory swapParams = new bytes(EXPECTED_SWAP_PARAMS_LENGTH);
        vm.expectRevert(UnknownRequestVersion.selector);
        libHarness.formatRequest(version, baseRequest, swapParams);
    }

    function testWrapBaseRequestIncorrectLength(uint8 length) public {
        vm.assume(length != EXPECTED_BASE_REQUEST_LENGTH); // See RequestLib.sol
        bytes memory request = new bytes(length);
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.wrapRequest(RequestLib.REQUEST_BASE, request);
    }

    function testWrapSwapRequestIncorrectLength(uint8 length) public {
        vm.assume(length != EXPECTED_SWAP_REQUEST_LENGTH); // See RequestLib.sol
        bytes memory request = new bytes(length);
        vm.expectRevert(IncorrectRequestLength.selector);
        libHarness.wrapRequest(RequestLib.REQUEST_SWAP, request);
    }

    function testWrapRequestUnknownVersion(uint32 version) public {
        vm.assume(version > RequestLib.REQUEST_SWAP);
        bytes memory request = new bytes(EXPECTED_BASE_REQUEST_LENGTH);
        vm.expectRevert(UnknownRequestVersion.selector);
        libHarness.wrapRequest(version, request);
    }
}
