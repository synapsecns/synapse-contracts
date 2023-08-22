// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

import {DefaultRouter} from "./DefaultRouter.sol";
import {BridgeFailed, ModuleExists, ModuleNotExists, ModuleInvalid, QueryEmpty} from "./libs/Errors.sol";
import {Action, BridgeToken, DestRequest, LimitedToken, Module, SwapQuery} from "./libs/Structs.sol";

import {ISwapQuoterV1} from "./interfaces/ISwapQuoterV1.sol";
import {IBridgeModule} from "./interfaces/IBridgeModule.sol";
import {IRouterV2} from "./interfaces/IRouterV2.sol";

contract SynapseRouterV2 is IRouterV2, DefaultRouter, Ownable {
    /// @notice swap quoter
    ISwapQuoterV1 public immutable swapQuoter;

    /// @notice List of all connected bridge modules
    Module[] internal _bridgeModules;

    /// @notice Mapping from unique bridge module ID to index in bridge modules array
    mapping(bytes32 => uint256) private _idToModulesIndex;

    /// @notice Mapping from bridge module address to index in bridge modules array
    mapping(address => uint256) private _moduleToModulesIndex;

    event ModuleConnected(bytes32 indexed moduleId, address bridgeModule);
    event ModuleUpdated(bytes32 indexed moduleId, address oldBridgeModule, address newBridgeModule);
    event ModuleDisconnected(bytes32 indexed moduleId);

    constructor(address _swapQuoter) {
        swapQuoter = ISwapQuoterV1(_swapQuoter);

        // start at idx=1 so idx=0 can be used for zero element
        _bridgeModules.push();
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
        if (moduleId == bytes32(0)) revert ModuleInvalid();
        if (_hasModule(moduleId)) revert ModuleExists();

        uint256 idx = _bridgeModules.length;
        _bridgeModules.push(Module({id: moduleId, module: bridgeModule}));

        _idToModulesIndex[moduleId] = idx;
        _moduleToModulesIndex[bridgeModule] = idx;

        emit ModuleConnected(moduleId, bridgeModule);
    }

    /// @inheritdoc IRouterV2
    function updateBridgeModule(bytes32 moduleId, address bridgeModule) external onlyOwner {
        if (!_hasModule(moduleId)) revert ModuleNotExists();
        uint256 idx = _idToModulesIndex[moduleId];

        address module = _bridgeModules[idx].module;
        _bridgeModules[idx].module = bridgeModule;
        _moduleToModulesIndex[module] = 0;
        _moduleToModulesIndex[bridgeModule] = idx;

        emit ModuleUpdated(moduleId, module, bridgeModule);
    }

    /// @inheritdoc IRouterV2
    function disconnectBridgeModule(bytes32 moduleId) external onlyOwner {
        if (!_hasModule(moduleId)) revert ModuleNotExists();
        uint256 idx = _idToModulesIndex[moduleId];

        address module = _bridgeModules[idx].module;
        _bridgeModules[idx].module = address(0);
        _moduleToModulesIndex[module] = 0;

        emit ModuleDisconnected(moduleId);
    }

    /// @inheritdoc IRouterV2
    function idToModule(bytes32 moduleId) public view returns (address bridgeModule) {
        uint256 idx = _idToModulesIndex[moduleId];
        bridgeModule = _bridgeModules[idx].module;
    }

    /// @inheritdoc IRouterV2
    function moduleToId(address bridgeModule) public view returns (bytes32 moduleId) {
        uint256 idx = _moduleToModulesIndex[bridgeModule];
        moduleId = _bridgeModules[idx].id;
    }

    /// @inheritdoc IRouterV2
    function getDestinationBridgeTokens(address tokenOut) external view returns (BridgeToken[] memory destTokens) {
        BridgeToken[][] memory unflattenedDestTokens = new BridgeToken[][](_bridgeModules.length);
        uint256 destTokensLength;

        for (uint256 i = 0; i < _bridgeModules.length; ++i) {
            BridgeToken[] memory bridgeTokens = IBridgeModule(_bridgeModules[i].module).getBridgeTokens();

            // assemble limited token format for quoter call
            LimitedToken[] memory bridgeTokensIn = new LimitedToken[](bridgeTokens.length);
            for (uint256 j = 0; j < bridgeTokens.length; ++j) {
                bridgeTokensIn[j] = LimitedToken({actionMask: uint256(Action.Swap), token: bridgeTokens[j].token});
            }

            // push to dest tokens if connected to tokenOut
            // TODO: test bridgeTokens.length == isConnected.length
            (uint256 amountFound, bool[] memory isConnected) = swapQuoter.findConnectedTokens(bridgeTokensIn, tokenOut);
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
    function getOriginBridgeTokens(address tokenIn) external view returns (BridgeToken[] memory originTokens) {}

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
            address token = _getTokenFromSymbol(request.symbol);

            // query the quoter
            LimitedToken memory tokenIn = LimitedToken({actionMask: uint256(Action.Swap), token: token});
            destQueries[i] = swapQuoter.getAmountOut(tokenIn, tokenOut, request.amountIn);
        }
    }

    /// @inheritdoc IRouterV2
    function getOriginAmountOut(
        address tokenIn,
        string[] memory tokenSymbols,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries) {}

    /// @notice Checks whether the router adapter was specified in the query.
    /// Query without a router adapter specifies that no action needs to be taken.
    function _hasAdapter(SwapQuery memory query) internal pure returns (bool) {
        return query.routerAdapter != address(0);
    }

    /// @notice Checks whether module ID has already been connected to router
    function _hasModule(bytes32 moduleId) internal view returns (bool) {
        return _idToModulesIndex[moduleId] > 0;
    }

    /// @notice Searches all bridge modules to get the token address from the unique bridge symbol
    /// @param symbol Symbol of the supported bridge token
    function _getTokenFromSymbol(string memory symbol) internal view returns (address token) {
        for (uint256 i = 0; i < _bridgeModules.length; ++i) {
            token = IBridgeModule(_bridgeModules[i].module).symbolToToken(symbol);
            if (token != address(0)) break;
        }
    }
}
