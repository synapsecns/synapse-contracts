// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts-4.5.0/utils/Address.sol";
import {EnumerableMap} from "@openzeppelin/contracts-4.5.0/utils/structs/EnumerableMap.sol";

import {DefaultRouter} from "./DefaultRouter.sol";
import {Arrays} from "./libs/Arrays.sol";
import {ActionLib, BridgeToken, DestRequest, LimitedToken, Pool, SwapQuery} from "./libs/Structs.sol";
import {UniversalTokenLib} from "./libs/UniversalToken.sol";

import {ISwapQuoterV2} from "./interfaces/ISwapQuoterV2.sol";
import {IBridgeModule} from "./interfaces/IBridgeModule.sol";
import {IRouterV2} from "./interfaces/IRouterV2.sol";

contract SynapseRouterV2 is IRouterV2, DefaultRouter, Ownable {
    using Address for address;
    using Arrays for BridgeToken[][];
    using Arrays for address[][];
    using Arrays for address[];
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    /// @notice swap quoter
    ISwapQuoterV2 public swapQuoter;

    /// @notice Enumerable map of all connected bridge modules
    EnumerableMap.UintToAddressMap internal _bridgeModules;

    event QuoterSet(address oldSwapQuoter, address newSwapQuoter);
    event ModuleConnected(bytes32 indexed moduleId, address bridgeModule);
    event ModuleUpdated(bytes32 indexed moduleId, address oldBridgeModule, address newBridgeModule);
    event ModuleDisconnected(bytes32 indexed moduleId);

    error SynapseRouterV2__ModuleExists();
    error SynapseRouterV2__ModuleNotExists();
    error SynapseRouterV2__ModuleInvalid();
    error SynapseRouterV2__QueryEmpty();

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

        // pull (and possibly swap) token into router
        if (originQuery.hasAdapter()) {
            (token, amount) = _doSwap(address(this), token, amount, originQuery);
        } else {
            amount = _pullToken(address(this), token, amount);
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
        bridgeModule.functionDelegateCall(payload); // bubbles up the error, but nothing to be returned
    }

    /// @inheritdoc IRouterV2
    function swap(
        address to,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) external payable returns (uint256 amountOut) {
        if (!query.hasAdapter()) revert SynapseRouterV2__QueryEmpty();

        address tokenOut;
        (tokenOut, amountOut) = _doSwap(to, token, amount, query);
    }

    /// @inheritdoc IRouterV2
    function setSwapQuoter(ISwapQuoterV2 _swapQuoter) external onlyOwner {
        emit QuoterSet(address(swapQuoter), address(_swapQuoter));
        swapQuoter = _swapQuoter;
    }

    /// @inheritdoc IRouterV2
    function connectBridgeModule(bytes32 moduleId, address bridgeModule) external onlyOwner {
        if (moduleId == bytes32(0) || bridgeModule == address(0)) revert SynapseRouterV2__ModuleInvalid();
        if (_hasModule(moduleId)) revert SynapseRouterV2__ModuleExists();

        _bridgeModules.set(uint256(moduleId), bridgeModule);
        emit ModuleConnected(moduleId, bridgeModule);
    }

    /// @inheritdoc IRouterV2
    function updateBridgeModule(bytes32 moduleId, address bridgeModule) external onlyOwner {
        if (bridgeModule == address(0)) revert SynapseRouterV2__ModuleInvalid();
        if (!_hasModule(moduleId)) revert SynapseRouterV2__ModuleNotExists();

        address module = _bridgeModules.get(uint256(moduleId));
        _bridgeModules.set(uint256(moduleId), bridgeModule);

        emit ModuleUpdated(moduleId, module, bridgeModule);
    }

    /// @inheritdoc IRouterV2
    function disconnectBridgeModule(bytes32 moduleId) external onlyOwner {
        if (!_hasModule(moduleId)) revert SynapseRouterV2__ModuleNotExists();

        _bridgeModules.remove(uint256(moduleId));
        emit ModuleDisconnected(moduleId);
    }

    /// @inheritdoc IRouterV2
    function idToModule(bytes32 moduleId) public view returns (address bridgeModule) {
        if (!_hasModule(moduleId)) revert SynapseRouterV2__ModuleNotExists();
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
        if (moduleId == bytes32(0)) revert SynapseRouterV2__ModuleNotExists();
    }

    /// @inheritdoc IRouterV2
    function getDestinationBridgeTokens(address tokenOut) external view returns (BridgeToken[] memory destTokens) {
        destTokens = _getConnectedBridgeTokens(tokenOut, false);
    }

    /// @inheritdoc IRouterV2
    function getOriginBridgeTokens(address tokenIn) external view returns (BridgeToken[] memory originTokens) {
        originTokens = _getConnectedBridgeTokens(tokenIn, true);
    }

    /// @inheritdoc IRouterV2
    function getSupportedTokens() external view returns (address[] memory supportedTokens) {
        // get all possible bridge tokens from supported bridge modules
        BridgeToken[] memory bridgeTokens = _getBridgeTokens();

        // get tokens in each quoter pool
        Pool[] memory pools = swapQuoter.allPools();
        address[][] memory unflattened = new address[][](pools.length + 1);

        // supported should include all bridge tokens and any pool tokens paired with a bridge token
        // @dev fill pool tokens first then last index of unflattened dedicated to bridge tokens
        uint256 count;
        for (uint256 i = 0; i < pools.length; ++i) {
            Pool memory pool = pools[i];
            unflattened[i] = new address[](pool.tokens.length);

            bool does; // whether pool.tokens does contain a bridge token
            for (uint256 j = 0; j < pool.tokens.length; ++j) {
                // optimistically add pool token to list
                unflattened[i][j] = pool.tokens[j].token;

                // check whether pool token is a bridge token if haven't found one prior
                for (uint256 k = 0; k < bridgeTokens.length; ++k) {
                    if (does) break;
                    does = (bridgeTokens[k].token == pool.tokens[j].token);
                }
            }

            if (!does)
                delete unflattened[i]; // zero out if no bridge token
            else count += pool.tokens.length;
        }

        // fill in bridge tokens in last row of unflattened
        unflattened[pools.length] = new address[](bridgeTokens.length);
        for (uint256 i = 0; i < bridgeTokens.length; ++i) {
            unflattened[pools.length][i] = bridgeTokens[i].token;
        }
        count += bridgeTokens.length;

        // flatten into supported tokens and filter out duplicates
        supportedTokens = unflattened.flatten(count).unique();

        // add native weth if in supported list
        if (supportedTokens.contains(swapQuoter.weth())) {
            return supportedTokens.append(UniversalTokenLib.ETH_ADDRESS);
        }
    }

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
            bool isSwap = !(token == tokenOut ||
                (tokenOut == UniversalTokenLib.ETH_ADDRESS && token == swapQuoter.weth()));
            uint256 amountIn = _calculateBridgeAmountIn(bridgeModule, token, request.amountIn, isSwap);
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

    /// @notice Gets all connected bridge tokens to the given token
    /// @param token The token to connect bridge tokens with
    /// @param origin Whether gathering on origin or destination chain
    /// @param connected The connected bridge tokens. If origin == True, then returns origin bridge tokens. If origin == False, returns dest bridge tokens.
    function _getConnectedBridgeTokens(address token, bool origin)
        internal
        view
        returns (BridgeToken[] memory connected)
    {
        uint256 len = _bridgeModules.length();
        BridgeToken[][] memory unflattened = new BridgeToken[][](len);

        uint256 count;
        for (uint256 i = 0; i < len; ++i) {
            (, address bridgeModule) = _bridgeModules.at(i);
            BridgeToken[] memory bridgeTokens = IBridgeModule(bridgeModule).getBridgeTokens();

            // assemble limited token format for quoter call
            uint256 amountFound;
            bool[] memory isConnected = new bool[](bridgeTokens.length);
            for (uint256 j = 0; j < bridgeTokens.length; ++j) {
                LimitedToken memory _tokenIn = origin
                    ? LimitedToken({actionMask: ActionLib.allActions(), token: token}) // origin bridge tokens
                    : LimitedToken({
                        actionMask: IBridgeModule(bridgeModule).tokenToActionMask(bridgeTokens[j].token),
                        token: bridgeTokens[j].token
                    }); // dest bridge tokens
                address _tokenOut = origin ? bridgeTokens[j].token : token;
                isConnected[j] = swapQuoter.areConnectedTokens(_tokenIn, _tokenOut);
                if (isConnected[j]) amountFound++;
            }

            // push to unflattened tokens if bridge token connected to given token
            unflattened[i] = new BridgeToken[](amountFound);
            count += amountFound;

            uint256 k;
            for (uint256 j = 0; j < bridgeTokens.length; ++j) {
                if (isConnected[j]) {
                    unflattened[i][k] = bridgeTokens[j];
                    k++;
                }
            }
        }

        // flatten into connected tokens
        connected = unflattened.flatten(count);
    }

    /// @notice Gets all bridge tokens for supported bridge modules
    function _getBridgeTokens() internal view returns (BridgeToken[] memory) {
        uint256 len = _bridgeModules.length();
        BridgeToken[][] memory unflattened = new BridgeToken[][](len);

        uint256 count;
        for (uint256 i = 0; i < len; ++i) {
            (, address bridgeModule) = _bridgeModules.at(i);
            BridgeToken[] memory tokens = IBridgeModule(bridgeModule).getBridgeTokens();

            // push to unflattened
            unflattened[i] = new BridgeToken[](tokens.length);
            count += tokens.length;

            for (uint256 j = 0; j < tokens.length; ++j) {
                unflattened[i][j] = tokens[j];
            }
        }

        // flatten into bridge tokens array
        return unflattened.flatten(count);
    }

    /// @notice Calculates amount of bridge token in accounting for bridge fees
    /// @param token    Address of the bridging token
    /// @param amount   Amount in before fees
    /// @param isSwap   Whether the user provided swap details for converting the bridge token
    ///                 to the final token on this chain
    function _calculateBridgeAmountIn(
        address bridgeModule,
        address token,
        uint256 amount,
        bool isSwap
    ) internal view returns (uint256 amount_) {
        uint256 feeAmount = IBridgeModule(bridgeModule).calculateFeeAmount(token, amount, isSwap);
        if (feeAmount < amount) amount_ = amount - feeAmount;
    }
}
