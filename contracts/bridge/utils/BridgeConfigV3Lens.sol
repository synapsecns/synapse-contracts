// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {LocalBridgeConfig} from "../router/LocalBridgeConfig.sol";
import {BridgeConfigV3} from "../BridgeConfigV3.sol";

interface IMulticall3 {
    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData);
}

/**
 * @notice Contract to introspect BridgeConfigV3, which is deployed on Mainnet.
 * A test or a script contract could inherit from BridgeConfigV3Lens in order to
 * batch fetch information about the bridge tokens.
 */
contract BridgeConfigV3Lens {
    /**
     * @notice Struct defining a supported bridge token. This is not supposed to be stored on-chain,
     * so this is not optimized in terms of storage words.
     * @param id            ID for token used in BridgeConfigV3
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param tokenType     Method of bridging used for the token: Redeem or Deposit.
     * @param bridgeToken   Actual token used for bridging `token`. This is the token bridge is burning/locking.
     *                      Might differ from `token`, if `token` does not conform to bridge-supported interface.
     * @param bridgeFee     Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
     * @param minFee        Minimum fee for bridging a token to this chain, in token decimals
     * @param maxFee        Maximum fee for bridging a token to this chain, in token decimals
     */
    struct BridgeToken {
        string id;
        address token;
        LocalBridgeConfig.TokenType tokenType;
        address bridgeToken;
        uint256 bridgeFee;
        uint256 minFee;
        uint256 maxFee;
    }

    bytes1 private constant ZERO = bytes1("0");
    bytes1 private constant NINE = bytes1("9");
    bytes1 private constant A_LOWER = bytes1("a");
    bytes1 private constant A_UPPER = bytes1("A");
    bytes1 private constant F_LOWER = bytes1("f");
    bytes1 private constant F_UPPER = bytes1("F");

    /// @dev Constants for a special case: Avalanche wrapper token for GMX
    uint256 private constant CHAIN_ID_AVA = 43114;
    address private constant GMX = 0x62edc0692BD897D2295872a9FFCac5425011c661;
    address private constant GMX_WRAPPER = 0x20A9DC684B4d0407EF8C9A302BEAaA18ee15F656;

    /// @dev BridgeConfig deployment on Ethereum Mainnet
    BridgeConfigV3 internal constant BRIDGE_CONFIG = BridgeConfigV3(0x5217c83ca75559B1f8a8803824E5b7ac233A12a1);
    /// @dev Multicall3 deployment on Ethereum Mainnet (and everywhere else).
    IMulticall3 internal constant MULTI_CALL = IMulticall3(0xcA11bde05977b3631167028862bE2a173976CA11);

    /// @notice Returns a list of supported bridge tokens and their liquidity pools for a given chain.
    function getChainConfig(uint256 chainId) public returns (BridgeToken[] memory tokens, address[] memory pools) {
        tokens = _getChainTokens(chainId);
        pools = _getChainPools(chainId, tokens);
    }

    /// @notice Returns address value for a string containing 0x prefixed address.
    function stringToAddress(string memory str) public pure returns (address addr) {
        bytes memory bStr = bytes(str);
        uint256 length = bStr.length;
        require(length == 42, "Not a 0x address");
        uint256 val = 0;
        for (uint256 i = 0; i < 40; ++i) {
            // Shift left 4 bits and apply 4 bits derived from the string character
            val <<= 4;
            val = val | _charToInt(bStr[2 + i]);
        }
        addr = address(uint160(val));
    }

    /// @dev Returns all bridge tokens supported for a given chain.
    function _getChainTokens(uint256 chainId) internal returns (BridgeToken[] memory tokens) {
        string[] memory ids = BRIDGE_CONFIG.getAllTokenIDs();
        uint256 amount = ids.length;
        // Allocate memory for all token IDs, even though some of them are not supported on given chain
        tokens = new BridgeToken[](amount);
        // Form a multicall query
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            calls[i] = IMulticall3.Call3({
                target: address(BRIDGE_CONFIG),
                allowFailure: false,
                callData: abi.encodeWithSelector(BRIDGE_CONFIG.getTokenByID.selector, ids[i], chainId)
            });
        }
        IMulticall3.Result[] memory data = MULTI_CALL.aggregate3(calls);
        uint256 tokensFound = 0;
        for (uint256 i = 0; i < amount; ++i) {
            require(data[i].success, "Multicall failed");
            BridgeConfigV3.Token memory token = abi.decode(data[i].returnData, (BridgeConfigV3.Token));
            if (bytes(token.tokenAddress).length == 0) continue;
            (address tokenAddress, address bridgeToken) = _decodeStringAddress(chainId, token.tokenAddress);
            if (tokenAddress == address(0)) continue;
            tokens[tokensFound++] = BridgeToken({
                id: ids[i],
                token: tokenAddress,
                tokenType: token.isUnderlying
                    ? LocalBridgeConfig.TokenType.Deposit
                    : LocalBridgeConfig.TokenType.Redeem,
                bridgeToken: bridgeToken,
                bridgeFee: token.swapFee,
                minFee: token.minSwapFee,
                maxFee: token.maxSwapFee
            });
        }
        // Shrink array by writing a smaller length directly in memory
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(tokens, tokensFound)
        }
        require(tokens.length == tokensFound, "Assembly magic did't work");
    }

    function _decodeStringAddress(uint256 chainId, string memory str)
        internal
        pure
        returns (address tokenAddress, address bridgeToken)
    {
        bridgeToken = stringToAddress(str);
        if (chainId == CHAIN_ID_AVA && bridgeToken == GMX_WRAPPER) {
            // Special case for GMX on Avalanche
            tokenAddress = GMX;
        } else {
            // Literally every other token doesn't need a wrapper
            tokenAddress = bridgeToken;
        }
    }

    /// @dev Returns all liquidity pools for destination swap on a given chain.
    function _getChainPools(uint256 chainId, BridgeToken[] memory tokens) internal returns (address[] memory pools) {
        uint256 amount = tokens.length;
        // Allocate memory for all tokens, even though some of them don't require a liquidity pool
        pools = new address[](amount);
        // Form a multicall query
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            calls[i] = IMulticall3.Call3({
                target: address(BRIDGE_CONFIG),
                allowFailure: false,
                callData: abi.encodeWithSelector(BRIDGE_CONFIG.getPoolConfig.selector, tokens[i].bridgeToken, chainId)
            });
        }
        IMulticall3.Result[] memory data = MULTI_CALL.aggregate3(calls);
        uint256 poolsFound = 0;
        for (uint256 i = 0; i < amount; ++i) {
            require(data[i].success, "Multicall failed");
            BridgeConfigV3.Pool memory pool = abi.decode(data[i].returnData, (BridgeConfigV3.Pool));
            if (pool.poolAddress == address(0)) continue;
            pools[poolsFound++] = pool.poolAddress;
        }
        // Shrink array by writing a smaller length directly in memory
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(pools, poolsFound)
        }
        require(pools.length == poolsFound, "Assembly magic did't work");
    }

    /// @dev Returns integer value denoted by a character (1 for "1", 15 for "F" or "f").
    function _charToInt(bytes1 b) internal pure returns (uint8 val) {
        if (b >= ZERO && b <= NINE) {
            // This never underflows
            val = uint8(b) - uint8(ZERO);
        } else if (b >= A_LOWER && b <= F_LOWER) {
            // This never underflows; A = 10
            val = uint8(b) - uint8(A_LOWER) + 10;
        } else if (b >= A_UPPER && b <= F_UPPER) {
            // This never underflows; A = 10
            val = uint8(b) - uint8(A_UPPER) + 10;
        }
    }
}
