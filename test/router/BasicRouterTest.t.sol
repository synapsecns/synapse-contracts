// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../utils/DefaultVaultTest.t.sol";

contract BasicRouterTest is DefaultVaultTest {
    IERC20 public syn;

    constructor() DefaultVaultTest(defaultConfig) {
        this;
    }

    function setUp() public override {
        super.setUp();
        syn = _deployERC20("SYN");
    }

    /**
     * @notice Check all access restricted functions
     */
    function testAccessControl() public {
        address _r = address(router);
        utils.checkAccessControl(
            _r,
            abi.encodeWithSelector(router.addTrustedAdapter.selector, address(0)),
            router.ADAPTERS_STORAGE_ROLE()
        );
        utils.checkAccessControl(
            _r,
            abi.encodeWithSelector(router.removeAdapter.selector, address(0)),
            router.ADAPTERS_STORAGE_ROLE()
        );
        utils.checkAccessControl(
            _r,
            abi.encodeWithSelector(router.setAdapters.selector, new address[](1), false),
            router.ADAPTERS_STORAGE_ROLE()
        );

        utils.checkAccessControl(
            _r,
            abi.encodeWithSelector(router.recoverERC20.selector, address(0)),
            router.GOVERNANCE_ROLE()
        );
        utils.checkAccessControl(_r, abi.encodeWithSelector(router.recoverGAS.selector), router.GOVERNANCE_ROLE());
    }

    /**
     * @notice Check that governance can rescue GAS from contract
     */
    function testRecoverGAS() public {
        uint256 amount = TEST_AMOUNT;
        uint256 pre = governance.balance;
        deal(address(router), amount);

        hoax(governance);
        router.recoverGAS();
        assertEq(governance.balance, pre + amount, "Failed to recover gas");
    }

    /**
     * @notice Check that governance can rescue ERC20 from contract
     */
    function testRecoverERC20() public {
        uint256 amount = TEST_AMOUNT;
        uint256 pre = syn.balanceOf(governance);
        deal(address(syn), address(router), amount, true);

        hoax(governance);
        router.recoverERC20(syn);
        assertEq(syn.balanceOf(governance), pre + amount, "Failed to recover ERC20");
    }

    function testReceiveEther() public {
        deal(address(this), 42);
        payable(router).transfer(21);
        (bool success, ) = address(router).call{value: 21}("");
        assertTrue(success, "ETH transfer failed");
    }
}
