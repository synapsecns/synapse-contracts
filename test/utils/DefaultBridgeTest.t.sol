// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./DefaultRouterTest.t.sol";

import {IBridge} from "src-vault/interfaces/IBridge.sol";

contract DefaultBridgeTest is DefaultRouterTest {
    mapping(address => address) public tokenAddressEVM;
    mapping(address => string) public tokenAddressNonEVM;

    uint256 public constant ID_EVM = 1;
    uint256 public constant ID_NON_EVM = 121014925;

    uint256 public constant MAX_FEE = 100;
    uint256 public constant FEE = 10**7;
    uint256 public constant FEE_DENOMINATOR = 10**10;

    function setUp() public virtual override {
        super.setUp();

        for (uint256 i = 0; i < bridgeTokens.length; i++) {
            _setupBridgeToken(bridgeTokens[i]);
        }
    }

    function _setupBridgeToken(address token) internal {
        string memory tokenNonEVM = string(abi.encode(token));
        address tokenEVM = utils.bytes32ToAddress(keccak256(abi.encode(token, 420)));

        tokenAddressEVM[token] = tokenEVM;
        tokenAddressNonEVM[token] = tokenNonEVM;

        uint256 minFee = _getMinFee(token);
        require(minFee > 0, "Fee is not set up for token");
        // 0.1% fee with maxTotalFee = 100 * minFee, bridgeFee = minFee, gasDropFee = 2*minFee, swapFee = 4*minFee

        uint256[] memory chainIdsEVM = new uint256[](2);
        chainIdsEVM[0] = block.chainid;
        chainIdsEVM[1] = ID_EVM;

        address[] memory bridgeTokensEVM = new address[](2);
        bridgeTokensEVM[0] = token;
        bridgeTokensEVM[1] = tokenEVM;

        startHoax(governance);
        bridgeConfig.addNewToken(token, token, true, FEE, MAX_FEE * minFee, minFee, 2 * minFee, 4 * minFee);
        bridgeConfig.addNewMap(chainIdsEVM, bridgeTokensEVM, ID_NON_EVM, tokenNonEVM);
        bridgeConfig.changeTokenStatus(token, true);
        vm.stopPrank();
    }

    function _constructDestinationSwapParams(address bridgeToken)
        internal
        view
        returns (IBridge.SwapParams memory params)
    {
        params = _constructEmptySwapParams(tokenAddressEVM[bridgeToken]);
    }

    function _constructEmptySwapParams(address token) internal pure returns (IBridge.SwapParams memory params) {
        require(token != address(0), "Unknown bridge token");
        params.path = new address[](1);
        params.path[0] = token;
    }
}
