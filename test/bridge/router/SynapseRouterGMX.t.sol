// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../utils/Utilities06.sol";

import "../../../contracts/bridge/wrappers/GMXWrapper.sol";
import "../../../contracts/bridge/router/SwapQuoter.sol";
import "../../../contracts/bridge/router/SynapseRouter.sol";

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
// solhint-disable not-rely-on-time
contract SynapseRouterGMXTest is Utilities06 {
    address internal constant OWNER = address(1337);
    address internal constant USER = address(4242);
    address internal constant TO = address(2424);

    uint256 internal constant ARB_CHAINID = 42161;

    SynapseBridge internal bridge;
    SwapQuoter internal quoter;
    SynapseRouter internal router;

    GMXWrapper internal gmxWrapper;
    GMX internal gmx;

    function setUp() public override {
        super.setUp();

        gmxWrapper = new GMXWrapper();
        // Deploy bridge at the same address it is deployed on Avalanche
        bridge = deployBridge(gmxWrapper.bridge());
        // Prepare GMX mock on the same address GMX is deployed on Avalanche
        gmx = GMX(gmxWrapper.gmx());
        {
            // Deploy contract to copy the "mock" bytecode to GMX address
            vm.etch(address(gmx), codeAt(address(new GMX())));
        }

        // No WETH address is required for testing
        router = new SynapseRouter(address(0), address(bridge));
        quoter = new SwapQuoter(address(router));

        router.setSwapQuoter(quoter);

        // GMX Bridge Wrapper is set as minter for GMX
        gmx.setMinter(address(gmxWrapper));

        _dealAndApprove(address(gmx));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TESTS: BRIDGE, NO SWAPS                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/
    /// @notice Bridge tests (no swaps) are prefixed test_b

    function test_b_gmx() public {
        uint256 amount = 10**18;
        router.addToken({
            token: address(gmx),
            tokenType: LocalBridgeConfig.TokenType.Redeem,
            bridgeToken: address(gmxWrapper),
            bridgeFee: 0,
            minFee: 0,
            maxFee: 0
        });
        // Even though it is a swapper token, no extra allowances are required here
        SwapQuery memory emptyQuery;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ARB_CHAINID, address(gmxWrapper), amount);
        vm.prank(USER);
        router.bridge({
            to: TO,
            chainId: ARB_CHAINID,
            token: address(gmx),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: emptyQuery
        });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _dealAndApprove(address token) internal {
        // update total supply
        deal(token, USER, 10**20, true);
        vm.prank(USER);
        IERC20(token).approve(address(router), type(uint256).max);
    }

    function _castToArray(address token) internal pure returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = token;
    }
}
