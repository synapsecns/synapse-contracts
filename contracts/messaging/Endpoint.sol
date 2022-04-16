// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import "./EndpointSender.sol";
import "./EndpointReceiver.sol";

contract Endpoint is EndpointSender, EndpointReceiver {}
