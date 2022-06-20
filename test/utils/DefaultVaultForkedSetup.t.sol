// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./DefaultVaultTest.t.sol";

import {Adapter} from "src-router/adapters/Adapter.sol";
import {IAdapter} from "src-router/interfaces/IAdapter.sol";
import {IWETH9} from "src-bridge/interfaces/IWETH9.sol";

import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {Strings} from "@openzeppelin/contracts-4.5.0/utils/Strings.sol";

abstract contract DefaultVaultForkedSetup is DefaultVaultTest {
    using SafeERC20 for IERC20;

    struct AdapterData {
        string contractName;
        string adapterName;
        bytes constructorParams;
        string[] tokens;
        bool isUnderquoting;
    }

    mapping(address => uint256) public minTokenAmount;
    mapping(address => uint256) public maxTokenAmount;

    uint256[] public dstChainIdsEVM;
    address[] public bridgeTokens;
    mapping(address => string) public tokenNames;
    mapping(string => address) public tokensByName;

    address[] public routeTokens;

    address[] public adapters;
    mapping(address => bool) public isUnderquoting;
    mapping(address => address[]) public adapterTestTokens;
    mapping(string => address) public adaptersByName;

    // nUSD, if chainId == 1
    address public tokenFixedTotalSupply;

    struct BasicTokens {
        address payable wgas;
        address weth;
        address neth;
        address nusd;
        address syn;
    }

    constructor(TestSetup memory config) DefaultVaultTest(config) {
        this;
    }

    function setUp() public virtual override {
        super.setUp();
        _setupTokens();
        _setupAdapters();
        _configQuoter();
    }

    function _setupAdapters() internal virtual;

    function _setupTokens() internal virtual;

    function _configQuoter() internal virtual {
        startHoax(governance);
        quoter.setAdapters(adapters);
        quoter.setTokens(routeTokens);
        vm.stopPrank();
    }

    function _addToken(
        address token,
        string memory name,
        uint256 minAmount,
        uint256 maxAmount,
        bool isRouteToken
    ) internal {
        _addToken(token);
        vm.label(token, name);
        minTokenAmount[token] = minAmount;
        maxTokenAmount[token] = maxAmount * 10**IERC20(token).decimals();
        tokenNames[token] = name;
        tokensByName[name] = token;
        if (isRouteToken) {
            routeTokens.push(token);
        }
    }

    function _addSimpleBridgeToken(
        address token,
        string memory name,
        uint256 minAmount,
        uint256 maxAmount,
        bool isMintBurn,
        uint256 feeBP,
        uint256 minBridgeFee,
        uint256 minGasDropFee,
        uint256 minSwapFee,
        uint256 chainIdNonEVM,
        bool isRouteToken
    ) internal {
        _addToken(token, name, minAmount, maxAmount, isRouteToken);

        _addBridgeToken(token, token, isMintBurn, feeBP * 10**6, MAX_UINT, minBridgeFee, minGasDropFee, minSwapFee);
        _addBridgeMap(token, chainIdNonEVM, name);
    }

    function _addBridgeToken(
        address token,
        address bridgeToken,
        bool isMintBurn,
        uint256 synapseFee,
        uint256 maxTotalFee,
        uint256 minBridgeFee,
        uint256 minGasDropFee,
        uint256 minSwapFee
    ) internal virtual {
        bridgeTokens.push(token);

        hoax(governance);
        bridgeConfig.addNewToken(
            token,
            bridgeToken,
            isMintBurn,
            synapseFee,
            maxTotalFee,
            minBridgeFee,
            minGasDropFee,
            minSwapFee
        );
    }

    function _addBridgeMap(
        address token,
        uint256 nonEvmChainId,
        string memory tokenName
    ) internal virtual {
        uint256 amount = dstChainIdsEVM.length;
        uint256[] memory chainIdsEVM = new uint256[](amount + 1);
        address[] memory bridgeTokensEVM = new address[](amount + 1);

        chainIdsEVM[0] = block.chainid;
        bridgeTokensEVM[0] = token;

        for (uint256 i = 0; i < amount; ++i) {
            uint256 chainId = dstChainIdsEVM[i];
            chainIdsEVM[i + 1] = chainId;
            // use fake address that can be later verified
            bridgeTokensEVM[i + 1] = _getTokenDstAddress(token, chainId);
        }

        startHoax(governance);
        bridgeConfig.addNewMap(chainIdsEVM, bridgeTokensEVM, nonEvmChainId, tokenName);
        bridgeConfig.changeTokenStatus(token, true);
        vm.stopPrank();
    }

    function _deployAdapter(AdapterData memory data) internal {
        address _adapter = deployCode(
            string(abi.encodePacked("./artifacts/", data.contractName, ".sol/", data.contractName, ".json")),
            data.constructorParams
        );
        require(_adapter != address(0), "Failed to deploy");
        adapters.push(_adapter);
        if (data.isUnderquoting) {
            isUnderquoting[_adapter] = true;
        }
        vm.label(_adapter, data.adapterName);
        adaptersByName[data.adapterName] = _adapter;
        adapterTestTokens[_adapter] = _extractTokens(data.tokens);
    }

    function _extractTokens(bytes memory encodedTokens) internal view returns (address[] memory tokens) {
        string[] memory names = abi.decode(encodedTokens, (string[]));
        tokens = _extractTokens(names);
    }

    function _extractTokens(string[] memory names) internal view returns (address[] memory tokens) {
        tokens = new address[](names.length);
        for (uint256 i = 0; i < names.length; ++i) {
            tokens[i] = tokensByName[names[i]];
        }
    }

    function _getTokenDstAddress(address token, uint256 chainId) internal view returns (address dstAddress) {
        dstAddress = utils.bytes32ToAddress(keccak256(abi.encode(token, chainId)));
    }

    function _deployAdapters() internal {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "scripts/adapters.js";
        inputs[2] = "1";
        inputs[3] = "test/adapters.json";
        bytes memory res = vm.ffi(inputs);

        bytes[] memory rawData = abi.decode(res, (bytes[]));

        for (uint256 i = 0; i < rawData.length; ++i) {
            AdapterData memory data;
            (data.contractName, data.adapterName, data.constructorParams, data.tokens, data.isUnderquoting) = abi
            .decode(rawData[i], (string, string, bytes, string[], bool));
            _deployAdapter(data);
        }
    }
}
