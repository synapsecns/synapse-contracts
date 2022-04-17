pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../contracts/messaging/EndpointReceiver.sol";

contract EndpointReceiverTest is Test {
    EndpointReceiver public endpointReceiver;

    function setUp() public {
        endpointReceiver = new EndpointReceiver();
    }
}
