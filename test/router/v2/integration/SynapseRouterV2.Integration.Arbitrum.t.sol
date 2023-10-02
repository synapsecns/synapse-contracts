// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SwapQuery} from "../../../../contracts/router/libs/Structs.sol";
import {SynapseRouterV2IntegrationTest} from "./SynapseRouterV2.Integration.t.sol";

contract SynapseRouterV2ArbitrumIntegrationTest is SynapseRouterV2IntegrationTest {
    string private constant ARB_ENV_RPC = "ARBITRUM_API";
    // 2023-10-02
    uint256 public constant ARB_BLOCK_NUMBER = 136866865;

    address private constant ARB_SWAP_QUOTER = 0xE402cC7826dD835FCe5E3cFb61D56703fEbc2642;

    constructor() SynapseRouterV2IntegrationTest(ARB_ENV_RPC, ARB_BLOCK_NUMBER, ARB_SWAP_QUOTER) {}

    // TODO: implement
    function afterBlockchainForked() public virtual override {}

    function addExpectedChainIds() public virtual override {}

    function addExpectedTokens() public virtual override {}

    /// @dev no additional modules. only testing CCIP, Bridge
    function addExpectedModules() public virtual override {}

    /// @dev no additional bridge events to look for given no additional modules
    function checkExpectedBridgeEvent(
        uint256 chainId,
        bytes32 moduleId,
        address token,
        uint256 amount,
        SwapQuery memory destQuery
    ) public virtual override {}
}
