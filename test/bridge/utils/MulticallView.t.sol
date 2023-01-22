// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../utils/Utilities06.sol";
import "../../../contracts/bridge/utils/MulticallView.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

contract MulticallHarness is MulticallView {
    using SafeMath for uint256;

    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a.add(b);
    }

    function mul(uint256 a, uint256 b) external pure returns (uint256) {
        return a.mul(b);
    }
}

// solhint-disable func-name-mixedcase
contract MulticallViewTest is Utilities06 {
    MulticallHarness internal mc;

    function setUp() public override {
        super.setUp();
        mc = new MulticallHarness();
    }

    function test_successCalls() public {
        bytes[] memory calls = new bytes[](4);
        calls[0] = _addCalldata(1, 2);
        calls[1] = _mulCalldata(1, 2);
        calls[2] = _addCalldata(21, 2);
        calls[3] = _mulCalldata(4, 8);
        MulticallView.Result[] memory results = mc.multicallView(calls);
        assertEq(results.length, 4, "!length");
        _checkResultSuccess(results[0], 1 + 2);
        _checkResultSuccess(results[1], 1 * 2);
        _checkResultSuccess(results[2], 21 + 2);
        _checkResultSuccess(results[3], 4 * 8);
    }

    function test_failCalls() public {
        bytes[] memory calls = new bytes[](4);
        calls[0] = _addCalldata(type(uint256).max, type(uint256).max);
        calls[1] = _addCalldata(60, 9);
        calls[2] = _mulCalldata(type(uint256).max, type(uint256).max);
        calls[3] = _mulCalldata(105, 4);
        MulticallView.Result[] memory results = mc.multicallView(calls);
        assertEq(results.length, 4, "!length");
        _checkResultFail(results[0], "SafeMath: addition overflow");
        _checkResultSuccess(results[1], 60 + 9);
        _checkResultFail(results[2], "SafeMath: multiplication overflow");
        _checkResultSuccess(results[3], 105 * 4);
    }

    function _checkResultFail(MulticallView.Result memory result, string memory revertMsg) internal {
        assertFalse(result.success, "!fail");
        assertEq(getRevertMsg(result.returnData), revertMsg, "!revertMessage");
    }

    function _checkResultSuccess(MulticallView.Result memory result, uint256 expectedValue) internal {
        assertTrue(result.success, "!success");
        // Should be exactly one uint256
        assertEq(result.returnData.length, 32, "!returnData.length");
        uint256 value = abi.decode(result.returnData, (uint256));
        assertEq(value, expectedValue, "!returnData");
    }

    function _addCalldata(uint256 a, uint256 b) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(MulticallHarness.add.selector, a, b);
    }

    function _mulCalldata(uint256 a, uint256 b) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(MulticallHarness.mul.selector, a, b);
    }
}
