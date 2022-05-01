// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../utils/DefaultVaultTest.t.sol";

contract BasicQuoterTest is DefaultVaultTest {
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
        address _q = address(quoter);
        utils.checkAccess(
            _q,
            abi.encodeWithSelector(quoter.addTrustedAdapter.selector, address(0)),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _q,
            abi.encodeWithSelector(quoter.removeAdapter.selector, address(0)),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _q,
            abi.encodeWithSelector(quoter.removeAdapterByIndex.selector, 0),
            "Ownable: caller is not the owner"
        );

        utils.checkAccess(
            _q,
            abi.encodeWithSelector(quoter.addTrustedToken.selector, address(0)),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _q,
            abi.encodeWithSelector(quoter.removeToken.selector, address(0)),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _q,
            abi.encodeWithSelector(quoter.removeTokenByIndex.selector, 0),
            "Ownable: caller is not the owner"
        );

        utils.checkAccess(
            _q,
            abi.encodeWithSelector(quoter.setAdapters.selector, new address[](1)),
            "Ownable: caller is not the owner"
        );
        utils.checkAccess(
            _q,
            abi.encodeWithSelector(quoter.setTokens.selector, new address[](1)),
            "Ownable: caller is not the owner"
        );

        utils.checkAccess(
            _q,
            abi.encodeWithSelector(quoter.setMaxSwaps.selector, 0),
            "Ownable: caller is not the owner"
        );
    }

    // -- CHECK GENERAL SETTERS --

    function testSetMaxSwaps() public {
        utils.checkRevert(
            governance,
            address(quoter),
            abi.encodeWithSelector(quoter.setMaxSwaps.selector, 0),
            "Can't set maxSwaps to 0",
            "Amount of swaps can't be zero"
        );

        startHoax(governance);
        for (uint8 i = 1; i < 5; i++) {
            quoter.setMaxSwaps(i);
            assertEq(quoter.MAX_SWAPS(), i, "Failed to set maxSwaps");
        }
        vm.stopPrank();
    }

    // -- ADD | REMOVE ADAPTERS --

    function testAddTrustedAdapter() public {
        address[] memory adapters = utils.createEmptyUsers(5);

        _addAdapters(adapters);

        for (uint256 i = 0; i < adapters.length; ++i) {
            utils.checkRevert(
                governance,
                address(quoter),
                abi.encodeWithSelector(quoter.addTrustedAdapter.selector, adapters[i]),
                "Should not be able to add duplicate adapter",
                "Adapter already added"
            );
        }
    }

    function testRemoveAdapter() public {
        address[] memory adapters = utils.createEmptyUsers(5);
        _addAdapters(adapters);

        for (uint256 i = 0; i < adapters.length; ++i) {
            hoax(governance);
            quoter.removeAdapter(adapters[i]);
            assertTrue(!router.isTrustedAdapter(adapters[i]), "Failed to remove adapter");
            for (uint256 j = i + 1; j < adapters.length; ++j) {
                assertTrue(router.isTrustedAdapter(adapters[j]), "Removed more than one adapter");
            }
        }
    }

    function testRemoveAdapterByIndex() public {
        address[] memory adapters = utils.createEmptyUsers(5);
        _addAdapters(adapters); // [0, 1, 2, 3, 4]

        _removeAdapterByIndex(adapters, 1, 1); // [0, 4, 2, 3]
        _removeAdapterByIndex(adapters, 0, 0); // [3, 4, 2]
        _removeAdapterByIndex(adapters, 1, 4); // [3, 2]
        _removeAdapterByIndex(adapters, 0, 3); // [2]
        _removeAdapterByIndex(adapters, 0, 2);
    }

    function testSetAdapters() public {
        address[] memory adapters = utils.createEmptyUsers(5);
        _setAdapters(adapters);

        address[] memory newAdapters = utils.createEmptyUsers(10);
        _setAdapters(newAdapters);

        for (uint256 i = 0; i < adapters.length; ++i) {
            assertTrue(!router.isTrustedAdapter(adapters[i]), "Failed to remove old adapter");
        }
    }

    function _removeAdapterByIndex(
        address[] memory adapters,
        uint8 indexToRemove,
        uint8 indexToCheck
    ) internal {
        assertTrue(router.isTrustedAdapter(adapters[indexToCheck]), "Adapter removed too early");
        hoax(governance);
        quoter.removeAdapterByIndex(indexToRemove);
        assertTrue(!router.isTrustedAdapter(adapters[indexToCheck]), "Adapter not removed");
    }

    function _addAdapters(address[] memory adapters) internal {
        startHoax(governance);
        for (uint256 i = 0; i < adapters.length; ++i) {
            quoter.addTrustedAdapter(adapters[i]);
            assertTrue(router.isTrustedAdapter(adapters[i]), "Failed to add adapter");
            assertEq(quoter.trustedAdaptersCount(), i + 1, "Wrong amount of adapters");
        }
        vm.stopPrank();
    }

    function _setAdapters(address[] memory adapters) internal {
        hoax(governance);
        quoter.setAdapters(adapters);
        for (uint256 i = 0; i < adapters.length; ++i) {
            assertTrue(router.isTrustedAdapter(adapters[i]), "Failed to add adapter");
        }
        assertEq(quoter.trustedAdaptersCount(), adapters.length, "Wrong amount of adapters");
    }

    // -- ADD | REMOVE TOKENS --

    function testAddTrustedToken() public {
        address[] memory tokens = utils.createEmptyUsers(5);

        _addTokens(tokens);
        _checkAddDuplicateTokens(tokens);
    }

    function testRemoveToken() public {
        address[] memory tokens = utils.createEmptyUsers(5);
        _addTokens(tokens);

        for (uint256 i = 0; i < tokens.length; ++i) {
            hoax(governance);
            quoter.removeToken(tokens[i]);

            assertEq(quoter.trustedTokensCount(), tokens.length - i - 1, "Wrong amount of tokens");
            _checkIfTokenAbsent(tokens[i]);
        }
    }

    function testRemoveTokenByIndex() public {
        address[] memory tokens = utils.createEmptyUsers(5);
        _addTokens(tokens);

        _removeTokenByIndex(tokens, 1, 1); // [0, 4, 2, 3]
        _removeTokenByIndex(tokens, 0, 0); // [3, 4, 2]
        _removeTokenByIndex(tokens, 1, 4); // [3, 2]
        _removeTokenByIndex(tokens, 0, 3); // [2]
        _removeTokenByIndex(tokens, 0, 2);
    }

    function testSetTokens() public {
        address[] memory tokens = utils.createEmptyUsers(5);

        _setTokens(tokens);

        address[] memory newTokens = utils.createEmptyUsers(10);

        _setTokens(newTokens);
        // should be able to add old tokens
        _addTokens(tokens);
    }

    function _checkAddDuplicateTokens(address[] memory tokens) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            _checkIfTokenPresent(tokens[i]);
        }
    }

    function _checkIfTokenPresent(address token) internal {
        utils.checkRevert(
            governance,
            address(quoter),
            abi.encodeWithSelector(quoter.addTrustedToken.selector, token),
            "Should not be able to add duplicate token",
            "Token already added"
        );
    }

    function _checkIfTokenAbsent(address token) internal {
        startHoax(governance);
        quoter.addTrustedToken(token);
        quoter.removeToken(token);
        vm.stopPrank();
    }

    function _addTokens(address[] memory tokens) internal {
        uint256 amount = quoter.trustedTokensCount();
        startHoax(governance);
        for (uint256 i = 0; i < tokens.length; ++i) {
            quoter.addTrustedToken(tokens[i]);
            assertEq(quoter.trustedTokensCount(), amount + i + 1, "Wrong amount of tokens");
        }
        vm.stopPrank();
    }

    function _setTokens(address[] memory tokens) internal {
        hoax(governance);
        quoter.setTokens(tokens);
        _checkAddDuplicateTokens(tokens);
    }

    function _removeTokenByIndex(
        address[] memory tokens,
        uint8 indexToRemove,
        uint8 indexToCheck
    ) internal {
        _checkIfTokenPresent(tokens[indexToCheck]);
        hoax(governance);
        quoter.removeTokenByIndex(indexToRemove);
        _checkIfTokenAbsent(tokens[indexToCheck]);
    }
}
