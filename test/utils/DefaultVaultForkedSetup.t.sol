// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./DefaultVaultTest.t.sol";

import {IAdapter} from "src-router/interfaces/IAdapter.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";

import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

abstract contract DefaultVaultForkedSetup is DefaultVaultTest {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public minTokenAmount;
    mapping(address => uint256) public maxTokenAmount;

    uint256[] public dstChainIdsEVM;
    address[] public bridgeTokens;
    mapping(address => string) public tokenNames;

    address[] public routeTokens;

    address[] public adapters;
    mapping(address => bool) public canUnderquote;
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

    function _deployAdapter(
        string memory contractName,
        string memory name,
        bytes memory args,
        bytes memory tokens
    ) internal {
        _deployAdapter(contractName, name, args, tokens, false);
    }

    function _deployAdapter(
        string memory contractName,
        string memory name,
        bytes memory args,
        bytes memory tokens,
        bool _canUnderquote
    ) internal {
        address _adapter = deployCode(
            string(abi.encodePacked("./artifacts/", contractName, ".sol/", contractName, ".json")),
            args
        );
        adapters.push(_adapter);
        if (_canUnderquote) {
            canUnderquote[_adapter] = true;
        }
        vm.label(_adapter, name);
        adapterTestTokens[_adapter] = abi.decode(tokens, (address[]));
        adaptersByName[name] = _adapter;
    }

    function _getTokenDstAddress(address token, uint256 chainId) internal view returns (address dstAddress) {
        dstAddress = utils.bytes32ToAddress(keccak256(abi.encode(token, chainId)));
    }
}
