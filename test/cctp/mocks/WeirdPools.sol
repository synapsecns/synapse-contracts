// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract WeirdPoolBase {
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256 amountOut) {}

    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut) {}
}

contract WeirdPoolGetTokenNull is WeirdPoolBase {
    function getToken(uint8 index) external view {}
}

contract WeirdPoolGetTokenNonView {
    string private _gm;

    function getToken(uint8 index) external {
        _gm = "GM";
    }
}

contract WeirdPoolGetTokenReturnsBytes32 {
    function getToken(uint8 index) external pure returns (bytes32) {
        return bytes32(type(uint256).max);
    }
}

contract WeirdPoolGetTokenReturnsTwoAddresses {
    function getToken(uint8 index) external pure returns (address, address) {
        return (address(42), address(420));
    }
}

contract WeirdPoolGetTokenReturnsZero {
    function getToken(uint8 index) external pure returns (address) {
        return address(0);
    }
}
