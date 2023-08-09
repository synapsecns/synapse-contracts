// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IBridgeConfigV3} from "../../../interfaces/IBridgeConfigV3.sol";
import {IMulticall3} from "../../../interfaces/IMulticall3.sol";

abstract contract BridgeConfigLens {
    bytes1 private constant ZERO = bytes1("0");
    bytes1 private constant NINE = bytes1("9");
    bytes1 private constant A_LOWER = bytes1("a");
    bytes1 private constant A_UPPER = bytes1("A");
    bytes1 private constant F_LOWER = bytes1("f");
    bytes1 private constant F_UPPER = bytes1("F");

    /// @dev BridgeConfig deployment on Ethereum Mainnet
    IBridgeConfigV3 internal constant BRIDGE_CONFIG = IBridgeConfigV3(0x5217c83ca75559B1f8a8803824E5b7ac233A12a1);
    /// @dev Multicall3 deployment on Ethereum Mainnet (and everywhere else).
    IMulticall3 internal constant MULTI_CALL = IMulticall3(0xcA11bde05977b3631167028862bE2a173976CA11);

    /// @notice Returns the list of tokens supported by Synapse:Bridge on the given chain.
    /// @dev Needs to be connected to Ethereum Mainnet to work.
    function getChainTokens(uint256 chainId)
        public
        returns (string[] memory tokenIDs, IBridgeConfigV3.Token[] memory tokens)
    {
        // Get the list of token IDs
        string[] memory allTokenIDs = BRIDGE_CONFIG.getAllTokenIDs();
        IBridgeConfigV3.Token[] memory allTokens = new IBridgeConfigV3.Token[](allTokenIDs.length);
        // Create a list of calls to get the token config for each token ID
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](allTokenIDs.length);
        for (uint256 i = 0; i < allTokenIDs.length; ++i) {
            calls[i] = IMulticall3.Call3({
                target: address(BRIDGE_CONFIG),
                allowFailure: false,
                callData: abi.encodeWithSelector(BRIDGE_CONFIG.getTokenByID.selector, allTokenIDs[i], chainId)
            });
        }
        // Issue a single multicall to get all token configs
        IMulticall3.Result[] memory data = MULTI_CALL.aggregate3(calls);
        // Find out how many tokens exist
        uint256 tokensFound = 0;
        for (uint256 i = 0; i < data.length; ++i) {
            require(data[i].success, "Multicall failed");
            allTokens[i] = abi.decode(data[i].returnData, (IBridgeConfigV3.Token));
            if (bytes(allTokens[i].tokenAddress).length > 0) {
                ++tokensFound;
            }
        }
        // Copy the tokens into a new array
        tokens = new IBridgeConfigV3.Token[](tokensFound);
        tokenIDs = new string[](tokensFound);
        tokensFound = 0;
        for (uint256 i = 0; i < allTokens.length; ++i) {
            if (bytes(allTokens[i].tokenAddress).length > 0) {
                tokenIDs[tokensFound] = allTokenIDs[i];
                tokens[tokensFound] = allTokens[i];
                ++tokensFound;
            }
        }
    }

    /// @notice Returns the list of tokens supported by Synapse:Bridge
    /// and their whitelisted liquidity pools on the given chain.
    /// @dev Needs to be connected to Ethereum Mainnet to work.
    function getChainConfig(uint256 chainId)
        public
        returns (
            string[] memory tokenIDs,
            IBridgeConfigV3.Token[] memory tokens,
            IBridgeConfigV3.Pool[] memory pools
        )
    {
        (tokenIDs, tokens) = getChainTokens(chainId);
        pools = new IBridgeConfigV3.Pool[](tokens.length);
        // Create a list of calls to get the pool config for each token
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            calls[i] = IMulticall3.Call3({
                target: address(BRIDGE_CONFIG),
                allowFailure: false,
                callData: abi.encodeWithSelector(
                    BRIDGE_CONFIG.getPoolConfig.selector,
                    stringToAddress(tokens[i].tokenAddress),
                    chainId
                )
            });
        }
        // Issue a single multicall to get all pool configs
        IMulticall3.Result[] memory data = MULTI_CALL.aggregate3(calls);
        for (uint256 i = 0; i < data.length; ++i) {
            require(data[i].success, "Multicall failed");
            pools[i] = abi.decode(data[i].returnData, (IBridgeConfigV3.Pool));
        }
    }

    // ══════════════════════════════════════════════ INTERNAL UTILS ═══════════════════════════════════════════════════

    /// @notice Returns address value for a string containing 0x prefixed address.
    function stringToAddress(string memory str) internal pure returns (address addr) {
        bytes memory bStr = bytes(str);
        uint256 length = bStr.length;
        require(length == 42, "Not a 0x address");
        uint256 val = 0;
        for (uint256 i = 0; i < 40; ++i) {
            // Shift left 4 bits and apply 4 bits derived from the string character
            val <<= 4;
            val = val | charToInt(bStr[2 + i]);
        }
        addr = address(uint160(val));
    }

    /// @dev Returns integer value denoted by a character (1 for "1", 15 for "F" or "f").
    function charToInt(bytes1 b) internal pure returns (uint8 val) {
        if (b >= ZERO && b <= NINE) {
            val = uint8(b) - uint8(ZERO);
        } else if (b >= A_LOWER && b <= F_LOWER) {
            val = uint8(b) - uint8(A_LOWER) + 10;
        } else if (b >= A_UPPER && b <= F_UPPER) {
            val = uint8(b) - uint8(A_UPPER) + 10;
        }
    }
}
