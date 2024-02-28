// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFastBridge} from "../../contracts/rfq/interfaces/IFastBridge.sol";

contract MockFastBridge is IFastBridge {
    function bridge(BridgeParams memory params) external payable {}

    function relay(bytes memory request) external payable {}

    function prove(bytes memory request, bytes32 destTxHash) external {}

    function claim(bytes memory request, address to) external {}

    function dispute(bytes32 transactionId) external {}

    function refund(bytes memory request, address to) external {}

    function getBridgeTransaction(bytes memory request) external pure returns (BridgeTransaction memory) {}

    function canClaim(bytes32 transactionId, address relayer) external view returns (bool) {}
}
