// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import {EnumerableMap} from "@openzeppelin/contracts-4.5.0/utils/structs/EnumerableMap.sol";

import {DefaultRouter} from "./DefaultRouter.sol";
import {BridgeFailed, ModuleExists, ModuleNotExists, ModuleInvalid, QueryEmpty} from "./libs/Errors.sol";
import {ActionLib, BridgeToken, DestRequest, LimitedToken, SwapQuery} from "./libs/Structs.sol";

import {ISwapQuoterV2} from "./interfaces/ISwapQuoterV2.sol";
import {IBridgeModule} from "./interfaces/IBridgeModule.sol";
import {IRouterV2} from "./interfaces/IRouterV2.sol";

contract SynapseRouterV2 is IRouterV2, DefaultRouter, Ownable {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    /// @notice swap quoter
    ISwapQuoterV2 public immutable swapQuoter;

    /// @notice Enumerable map of all connected bridge modules
    EnumerableMap.UintToAddressMap internal _bridgeModules;

    event ModuleConnected(bytes32 indexed moduleId, address bridgeModule);
    event ModuleUpdated(bytes32 indexed moduleId, address oldBridgeModule, address newBridgeModule);
    event ModuleDisconnected(bytes32 indexed moduleId);

    constructor(address _swapQuoter) {
        swapQuoter = ISwapQuoterV2(_swapQuoter);
    }

    /// @inheritdoc IRouterV2
    function bridgeViaSynapse(
        address to,
        uint256 chainId,
        bytes32 moduleId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable {
        address bridgeModule = idToModule(moduleId);
        if (bridgeModule == address(0)) revert ModuleNotExists();

        // pull (and possibly swap) token into router
        if (_hasAdapter(originQuery)) {
            (token, amount) = _doSwap(address(this), token, amount, originQuery);
        } else {
            _pullToken(address(this), token, amount);
        }

        // delegate bridge call to module
        // @dev delegatecall should approve to spend
        bytes memory payload = abi.encodeWithSelector(
            IBridgeModule.delegateBridge.selector,
            to,
            chainId,
            token,
            amount,
            destQuery
        );
        (bool success, ) = bridgeModule.delegatecall(payload);
        if (!success) revert BridgeFailed();
    }

    /// @inheritdoc IRouterV2
    function swap(
        address to,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) external payable returns (uint256 amountOut) {
        if (!_hasAdapter(query)) revert QueryEmpty();

        address tokenOut;
        (tokenOut, amountOut) = _doSwap(to, token, amount, query);
    }

    /// @inheritdoc IRouterV2
    function connectBridgeModule(bytes32 moduleId, address bridgeModule) external onlyOwner {
        if (moduleId == bytes32(0) || bridgeModule == address(0)) revert ModuleInvalid();
        if (_hasModule(moduleId)) revert ModuleExists();

        _bridgeModules.set(uint256(moduleId), bridgeModule);
        emit ModuleConnected(moduleId, bridgeModule);
    }

    /// @inheritdoc IRouterV2
    function updateBridgeModule(bytes32 moduleId, address bridgeModule) external onlyOwner {
        if (bridgeModule == address(0)) revert ModuleInvalid();
        if (!_hasModule(moduleId)) revert ModuleNotExists();

        address module = _bridgeModules.get(uint256(moduleId));
        _bridgeModules.set(uint256(moduleId), bridgeModule);

        emit ModuleUpdated(moduleId, module, bridgeModule);
    }

    /// @inheritdoc IRouterV2
    function disconnectBridgeModule(bytes32 moduleId) external onlyOwner {
        if (!_hasModule(moduleId)) revert ModuleNotExists();

        _bridgeModules.remove(uint256(moduleId));
        emit ModuleDisconnected(moduleId);
    }

    /// @inheritdoc IRouterV2
    function idToModule(bytes32 moduleId) public view returns (address bridgeModule) {
        bridgeModule = _bridgeModules.get(uint256(moduleId));
    }

    /// @inheritdoc IRouterV2
    function moduleToId(address bridgeModule) public view returns (bytes32 moduleId) {
        uint256 len = _bridgeModules.length();
        for (uint256 i = 0; i < len; ++i) {
            (uint256 key, address module) = _bridgeModules.at(i);
            if (module == bridgeModule) {
                moduleId = bytes32(key);
                break;
            }
        }
    }

    /// @inheritdoc IRouterV2
    function getDestinationBridgeTokens(address tokenOut) external view returns (BridgeToken[] memory destTokens) {
        uint256 len = _bridgeModules.length();
        BridgeToken[][] memory unflattenedDestTokens = new BridgeToken[][](len);
        uint256 destTokensLength;

        for (uint256 i = 0; i < len; ++i) {
            (, address bridgeModule) = _bridgeModules.at(i);
            BridgeToken[] memory bridgeTokens = IBridgeModule(bridgeModule).getBridgeTokens();

            // assemble limited token format for quoter call
            uint256 amountFound;
            bool[] memory isConnected = new bool[](bridgeTokens.length);
            for (uint256 j = 0; j < bridgeTokens.length; ++j) {
                uint256 actionMask = IBridgeModule(bridgeModule).tokenToActionMask(bridgeTokens[j].token);
                LimitedToken memory bridgeTokenIn = LimitedToken({
                    actionMask: actionMask,
                    token: bridgeTokens[j].token
                });
                isConnected[j] = swapQuoter.areConnectedTokens(bridgeTokenIn, tokenOut);
                if (isConnected[j]) amountFound++;
            }

            // push to dest tokens if connected to tokenOut
            unflattenedDestTokens[i] = new BridgeToken[](amountFound);
            destTokensLength += amountFound;

            uint256 k;
            for (uint256 j = 0; j < bridgeTokens.length; ++j) {
                if (isConnected[j]) {
                    unflattenedDestTokens[i][k] = bridgeTokens[j];
                    k++;
                }
            }
        }

        // flatten into dest tokens
        destTokens = new BridgeToken[](destTokensLength);
        uint256 m;
        for (uint256 i = 0; i < unflattenedDestTokens.length; ++i) {
            for (uint256 j = 0; j < unflattenedDestTokens[i].length; ++j) {
                destTokens[m] = unflattenedDestTokens[i][j];
                m++;
            }
        }
    }

    /// @inheritdoc IRouterV2
    function getOriginBridgeTokens(address tokenIn) external view returns (BridgeToken[] memory originTokens) {
        uint256 len = _bridgeModules.length();
        BridgeToken[][] memory unflattenedOriginTokens = new BridgeToken[][](len);
        uint256 originTokensLength;

        // assemble limited token format for quoter calls
        LimitedToken memory _tokenIn = LimitedToken({actionMask: ActionLib.allActions(), token: tokenIn});

        for (uint256 i = 0; i < len; ++i) {
            (, address bridgeModule) = _bridgeModules.at(i);
            BridgeToken[] memory bridgeTokens = IBridgeModule(bridgeModule).getBridgeTokens();

            // query quoter if bridge token connected to token in
            uint256 amountFound;
            bool[] memory isConnected = new bool[](bridgeTokens.length);
            for (uint256 j = 0; j < bridgeTokens.length; ++j) {
                isConnected[j] = swapQuoter.areConnectedTokens(_tokenIn, bridgeTokens[j].token);
                if (isConnected[j]) amountFound++;
            }

            // push to origin tokens if connected to tokenIn
            unflattenedOriginTokens[i] = new BridgeToken[](amountFound);
            originTokensLength += amountFound;

            uint256 k;
            for (uint256 j = 0; j < bridgeTokens.length; ++j) {
                if (isConnected[j]) {
                    unflattenedOriginTokens[i][k] = bridgeTokens[j];
                    k++;
                }
            }
        }

        // flatten into origin tokens
        originTokens = new BridgeToken[](originTokensLength);
        uint256 m;
        for (uint256 i = 0; i < unflattenedOriginTokens.length; ++i) {
            for (uint256 j = 0; j < unflattenedOriginTokens[i].length; ++j) {
                originTokens[m] = unflattenedOriginTokens[i][j];
                m++;
            }
        }
    }

    /// @inheritdoc IRouterV2
    function getSupportedTokens() external view returns (address[] memory supportedTokens) {}

    /// @inheritdoc IRouterV2
    function getDestinationAmountOut(DestRequest[] memory requests, address tokenOut)
        external
        view
        returns (SwapQuery[] memory destQueries)
    {
        destQueries = new SwapQuery[](requests.length);
        for (uint256 i = 0; i < requests.length; ++i) {
            DestRequest memory request = requests[i];
            (address token, uint256 actionMask, address bridgeModule) = _getTokenAndActionMaskFromSymbol(
                request.symbol
            );
            if (token == address(0)) continue;

            // account for bridge fees in amountIn
            uint256 amountIn = _calculateBridgeAmountIn(bridgeModule, token, request.amountIn);
            if (amountIn == 0) continue;

            // query the quoter
            LimitedToken memory tokenIn = LimitedToken({actionMask: actionMask, token: token});
            destQueries[i] = swapQuoter.getAmountOut(tokenIn, tokenOut, amountIn);
        }
    }

    /// @inheritdoc IRouterV2
    function getOriginAmountOut(
        address tokenIn,
        string[] memory tokenSymbols,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries) {
        originQueries = new SwapQuery[](tokenSymbols.length);
        for (uint256 i = 0; i < tokenSymbols.length; ++i) {
            (address tokenOut, , address bridgeModule) = _getTokenAndActionMaskFromSymbol(tokenSymbols[i]);
            if (tokenOut == address(0)) continue;

            // query the quoter
            LimitedToken memory _tokenIn = LimitedToken({actionMask: ActionLib.allActions(), token: tokenIn});
            SwapQuery memory query = swapQuoter.getAmountOut(_tokenIn, tokenOut, amountIn);

            // check max amount can bridge
            uint256 maxAmountOut = IBridgeModule(bridgeModule).getMaxBridgedAmount(tokenOut);
            if (query.minAmountOut > maxAmountOut) continue;

            // set in return array
            originQueries[i] = query;
        }
    }

    /// @notice Checks whether the router adapter was specified in the query.
    /// Query without a router adapter specifies that no action needs to be taken.
    function _hasAdapter(SwapQuery memory query) internal pure returns (bool) {
        return query.routerAdapter != address(0);
    }

    /// @notice Checks whether module ID has already been connected to router
    function _hasModule(bytes32 moduleId) internal view returns (bool) {
        return _bridgeModules.contains(uint256(moduleId));
    }

    /// @notice Searches all bridge modules to get the token address from the unique bridge symbol
    /// @param symbol Symbol of the supported bridge token
    function _getTokenAndActionMaskFromSymbol(string memory symbol)
        internal
        view
        returns (
            address token,
            uint256 actionMask,
            address bridgeModule
        )
    {
        uint256 len = _bridgeModules.length();
        for (uint256 i = 0; i < len; ++i) {
            (, address _bridgeModule) = _bridgeModules.at(i);
            token = IBridgeModule(_bridgeModule).symbolToToken(symbol);
            if (token != address(0)) {
                actionMask = IBridgeModule(_bridgeModule).tokenToActionMask(token);
                bridgeModule = _bridgeModule;
                break;
            }
        }
    }

    /// @notice Calculates amount of bridge token in accounting for bridge fees
    /// @param token    Address of the bridging token
    /// @param amount   Amount in before fees
    function _calculateBridgeAmountIn(
        address bridgeModule,
        address token,
        uint256 amount
    ) internal view returns (uint256 amount_) {
        uint256 feeAmount = IBridgeModule(bridgeModule).calculateFeeAmount(token, amount);
        if (feeAmount < amount) amount_ = amount - feeAmount;
    }
}
