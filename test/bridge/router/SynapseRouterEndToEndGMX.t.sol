// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./SynapseRouterSuite.t.sol";
import "../../../contracts/bridge/wrappers/GMXWrapper.sol";

contract GMX is ERC20 {
    address internal minter;

    constructor() public ERC20("GMX", "GMX") {}

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "!minter");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        // it is what it is
        require(msg.sender == minter, "!minter");
        _burn(from, amount);
    }

    function setMinter(address _minter) external {
        minter = _minter;
    }
}

// solhint-disable func-name-mixedcase
contract SynapseRouterEndToEndGMXTest is SynapseRouterSuite {
    GMXWrapper internal avaGmxWrapper;

    GMX internal arbGMX;
    GMX internal avaGMX;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       OVERRIDES FOR GMX SETUP                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function setUp() public virtual override {
        avaGmxWrapper = new GMXWrapper();
        vm.label(address(avaGmxWrapper), "AVA GMX Wrapper");
        super.setUp();
    }

    function deployTestArbitrum() public virtual override returns (ChainSetup memory chain) {
        chain = super.deployTestArbitrum();
        arbGMX = new GMX();
        vm.label(address(arbGMX), "ARB GMX");
        chain.bridgeTokenGmx = address(arbGMX);
        _addDepositToken(chain.router, SYMBOL_GMX, chain.bridgeTokenGmx);
        correlatedBridgeToken[chain.chainId][arbGMX] = chain.bridgeTokenGmx;
        // Setup initial GMX locked in Bridge
        dealToken(chain, address(chain.bridge), arbGMX, 10**24);
    }

    function deployTestAvalanche() public virtual override returns (ChainSetup memory chain) {
        chain = super.deployTestAvalanche();
        // Prepare GMX mock on the same address GMX is deployed on Avalanche
        avaGMX = GMX(avaGmxWrapper.gmx());
        {
            // Deploy contract to copy the "mock" bytecode to GMX address
            vm.etch(address(avaGMX), codeAt(address(new GMX())));
        }
        // GMX Bridge Wrapper is set as minter for GMX
        avaGMX.setMinter(address(avaGmxWrapper));
        vm.label(address(avaGMX), "AVA GMX");
        // For the end user the bridge token is actual GMX
        chain.bridgeTokenGmx = address(avaGMX);
        _addToken(
            chain.router,
            SYMBOL_GMX,
            chain.bridgeTokenGmx,
            LocalBridgeConfig.TokenType.Redeem,
            address(avaGmxWrapper)
        );
        correlatedBridgeToken[chain.chainId][avaGMX] = chain.bridgeTokenGmx;
    }

    function deployChainBridge(ChainSetup memory chain) public virtual override {
        if (equals(chain.name, "AVA")) {
            // Deploy bridge at the same address it is deployed on Avalanche
            chain.bridge = deployBridge(avaGmxWrapper.bridge());
            chain.bridge.grantRole(chain.bridge.NODEGROUP_ROLE(), address(validator));
            chain.bridge.setWethAddress(payable(address(chain.wgas)));
        } else {
            super.deployChainBridge(chain);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              TESTS: GMX                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_arbitrumToAvalanche_inGMX_outGMX() public {
        // Prepare test parameters: Arbitrum GMX -> Avalanche GMX
        // Wrapper address should be abstracted away from UI completely
        ChainSetup memory origin = chains[ARB_CHAINID];
        ChainSetup memory destination = chains[AVA_CHAINID];
        IERC20 tokenIn = arbGMX;
        IERC20 tokenOut = avaGMX;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(avaGMX);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenDeposit(TO, AVA_CHAINID, address(arbGMX), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_avalancheToArbitrum_inGMX_outGMX() public {
        // Prepare test parameters: Avalanche GMX -> Arbitrum GMX
        // Wrapper address should be abstracted away from UI completely
        ChainSetup memory origin = chains[AVA_CHAINID];
        ChainSetup memory destination = chains[ARB_CHAINID];
        IERC20 tokenIn = avaGMX;
        IERC20 tokenOut = arbGMX;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(arbGMX);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Expect Bridge event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ARB_CHAINID, address(avaGmxWrapper), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }
}
