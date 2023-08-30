// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IBridgeModule} from "../../../contracts/router/interfaces/IBridgeModule.sol";
import {BridgeToken, LimitedToken, SwapQuery} from "../../../contracts/router/libs/Structs.sol";
import {MockFailedBridge} from "./MockFailedBridge.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract MockFailedBridgeModule is IBridgeModule {
    using SafeERC20 for IERC20;

    uint256 private constant FEE_DENOMINATOR = 10**10;

    BridgeToken[] internal _bridgeTokens;
    mapping(address => uint256) internal _maxBridgedAmounts;
    mapping(address => uint256) internal _fees;

    MockFailedBridge public immutable bridge;

    mapping(string => address) public symbolToToken;
    mapping(address => string) public tokenToSymbol;
    mapping(address => uint256) public tokenToActionMask;

    constructor(BridgeToken[] memory bridgeTokens_, LimitedToken[] memory limitedTokens_) {
        bridge = new MockFailedBridge();

        require(bridgeTokens_.length == limitedTokens_.length, "token arrays not same len");
        for (uint256 i = 0; i < bridgeTokens_.length; i++) {
            BridgeToken memory b = bridgeTokens_[i];
            LimitedToken memory l = limitedTokens_[i];
            require(b.token == l.token, "token array addresses not same");

            _bridgeTokens.push(b);
            symbolToToken[b.symbol] = b.token;
            tokenToSymbol[b.token] = b.symbol;
            tokenToActionMask[l.token] = l.actionMask;
        }
    }

    function delegateBridge(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory destQuery
    ) external payable virtual {
        IERC20(token).safeApprove(address(bridge), amount);
        bridge.deposit(to, chainId, token, amount, formatQuery(destQuery));
    }

    function formatQuery(SwapQuery memory query) public view returns (bytes memory) {
        return abi.encode(query.routerAdapter, query.tokenOut, query.minAmountOut, query.deadline, query.rawParams);
    }

    function getMaxBridgedAmount(address token) external view returns (uint256 amount) {
        amount = _maxBridgedAmounts[token];
    }

    function setMaxBridgedAmount(address token, uint256 amount) external {
        _maxBridgedAmounts[token] = amount;
    }

    function calculateFeeAmount(
        address token,
        uint256 amount,
        bool isSwap
    ) external view returns (uint256 fee) {
        uint256 rate = _fees[token];
        fee = (rate * amount) / FEE_DENOMINATOR;
    }

    function setFeeRate(address token, uint256 rate) external {
        _fees[token] = rate;
    }

    function getBridgeTokens() external view returns (BridgeToken[] memory bridgeTokens) {
        bridgeTokens = new BridgeToken[](_bridgeTokens.length);
        for (uint256 i = 0; i < _bridgeTokens.length; i++) {
            bridgeTokens[i] = _bridgeTokens[i];
        }
    }
}
