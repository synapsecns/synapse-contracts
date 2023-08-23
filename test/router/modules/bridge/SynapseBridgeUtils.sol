// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockSynapseBridge} from "../../mocks/MockSynapseBridge.sol";
import {ILocalBridgeConfig} from "../../../../contracts/router/interfaces/ILocalBridgeConfig.sol";

import {Test} from "forge-std/Test.sol";

abstract contract SynapseBridgeUtils is Test {
    // Default fee is 10 bps
    uint256 public constant DEFAULT_BRIDGE_FEE = 10**7;
    // Default min fee 0.0001
    uint256 public constant DEFAULT_MIN_FEE = 0.0001 ether;
    // Default max fee is 1.0
    uint256 public constant DEFAULT_MAX_FEE = 1 ether;

    address public synapseBridge;
    ILocalBridgeConfig public localBridgeConfig;

    function setUp() public virtual {
        synapseBridge = address(new MockSynapseBridge());
        // Deploy 0.6 contract
        // new SynapseRouter(synapseBridge, owner)
        address synapseRouterV1 = deployCode("SynapseRouter.sol", abi.encode(synapseBridge, address(this)));
        localBridgeConfig = ILocalBridgeConfig(synapseRouterV1);
    }

    // ════════════════════════════════════════════ ADD TOKEN SHORTCUTS ════════════════════════════════════════════════

    function addDepositToken(string memory symbol, address token) public {
        addDepositToken(symbol, token, DEFAULT_BRIDGE_FEE, DEFAULT_MIN_FEE, DEFAULT_MAX_FEE);
    }

    function addDepositToken(
        string memory symbol,
        address token,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) public {
        addDepositToken(symbol, token, token, bridgeFee, minFee, maxFee);
    }

    function addDepositToken(
        string memory symbol,
        address token,
        address bridgeToken
    ) public {
        addDepositToken(symbol, token, bridgeToken, DEFAULT_BRIDGE_FEE, DEFAULT_MIN_FEE, DEFAULT_MAX_FEE);
    }

    function addDepositToken(
        string memory symbol,
        address token,
        address bridgeToken,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) public {
        localBridgeConfig.addToken({
            symbol: symbol,
            token: token,
            tokenType: ILocalBridgeConfig.TokenType.Deposit,
            bridgeToken: bridgeToken,
            bridgeFee: bridgeFee,
            minFee: minFee,
            maxFee: maxFee
        });
    }

    function addRedeemToken(string memory symbol, address token) public {
        addRedeemToken(symbol, token, DEFAULT_BRIDGE_FEE, DEFAULT_MIN_FEE, DEFAULT_MAX_FEE);
    }

    function addRedeemToken(
        string memory symbol,
        address token,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) public {
        addRedeemToken(symbol, token, token, bridgeFee, minFee, maxFee);
    }

    function addRedeemToken(
        string memory symbol,
        address token,
        address bridgeToken
    ) public {
        addRedeemToken(symbol, token, bridgeToken, DEFAULT_BRIDGE_FEE, DEFAULT_MIN_FEE, DEFAULT_MAX_FEE);
    }

    function addRedeemToken(
        string memory symbol,
        address token,
        address bridgeToken,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) public {
        localBridgeConfig.addToken({
            symbol: symbol,
            token: token,
            tokenType: ILocalBridgeConfig.TokenType.Redeem,
            bridgeToken: bridgeToken,
            bridgeFee: bridgeFee,
            minFee: minFee,
            maxFee: maxFee
        });
    }
}
