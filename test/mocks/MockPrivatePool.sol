// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PrivatePool} from "../../contracts/concentrated/PrivatePool.sol";

/// @dev exposes internal functions for testing
contract MockPrivatePool is PrivatePool {
    constructor(
        address _owner,
        address _token0,
        address _token1,
        uint256 _P,
        uint256 _fee,
        uint256 _adminFee
    ) PrivatePool(_owner, _token0, _token1, _P, _fee, _adminFee) {}

    function amountWad(uint256 dx, bool isToken0) external view returns (uint256) {
        return _amountWad(dx, isToken0);
    }

    function amountDecimals(uint256 amount, bool isToken0) external view returns (uint256) {
        return _amountDecimals(amount, isToken0);
    }
}
