// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BytesArray, SlicerLib} from "../../../contracts/cctp/libs/Slicer.sol";

contract SlicerLibHarness {
    function sliceBytes32(bytes memory arr, uint256 index) public pure returns (bytes32) {
        BytesArray bytesArray = SlicerLib.wrapBytesArray(arr);
        return bytesArray.sliceBytes32(index);
    }

    function sliceAddress(bytes memory arr, uint256 index) public pure returns (address) {
        BytesArray bytesArray = SlicerLib.wrapBytesArray(arr);
        return bytesArray.sliceAddress(index);
    }
}
