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

    /**
     * @notice Checks that maxSwaps can be set by governance
     */
    function testSetMaxSwaps() public {
        utils.checkRevert(
            governance,
            address(quoter),
            abi.encodeWithSelector(quoter.setMaxSwaps.selector, 0),
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

    /**
     * @notice Checks addTrustedAdapter adds Adapter to both Quoter and Router.
     * Also checks that it's not possible to add duplicate adapters.
     */
    function testAddTrustedAdapter() public {
        address[] memory adapters = utils.createEmptyUsers(5);

        _addAdapters(adapters);

        for (uint256 i = 0; i < adapters.length; ++i) {
            utils.checkRevert(
                governance,
                address(quoter),
                abi.encodeWithSelector(quoter.addTrustedAdapter.selector, adapters[i]),
                "Adapter already added"
            );
        }
    }

    /**
     * @notice Checks removeAdapter removes Adapter from both Quoter and Router.
     */
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

    /**
     * @notice Checks removeAdapterByIndex removes Adapter from both Quoter and Router.
     */
    function testRemoveAdapterByIndex() public {
        address[] memory adapters = utils.createEmptyUsers(5);
        _addAdapters(adapters); // [0, 1, 2, 3, 4]

        _removeAdapterByIndex(adapters, 1, 1); // [0, 4, 2, 3]
        _removeAdapterByIndex(adapters, 0, 0); // [3, 4, 2]
        _removeAdapterByIndex(adapters, 1, 4); // [3, 2]
        _removeAdapterByIndex(adapters, 0, 3); // [2]
        _removeAdapterByIndex(adapters, 0, 2);
    }

    /**
     * @notice Checks that setAdapters sets a list of adapters.
     * Also checks that setAdapters removes all old adapters.
     */
    function testSetAdapters() public {
        address[] memory adapters = utils.createEmptyUsers(5);
        _setAdapters(adapters);

        address[] memory newAdapters = utils.createEmptyUsers(10);
        _setAdapters(newAdapters);

        for (uint256 i = 0; i < adapters.length; ++i) {
            assertTrue(!router.isTrustedAdapter(adapters[i]), "Failed to remove old adapter");
        }
    }

    /**
     * @notice Removes adapter by its index. Checks that adapter hasn't been mistakenly removed
     * earlier, and that it was removed afterwards.
     */
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

    /**
     * @notice Adds adapters one by one, using addTrustedAdapter.
     * Checks that Adapter was added both to Quoter and Router.
     */
    function _addAdapters(address[] memory adapters) internal {
        startHoax(governance);
        for (uint256 i = 0; i < adapters.length; ++i) {
            quoter.addTrustedAdapter(adapters[i]);
            assertTrue(router.isTrustedAdapter(adapters[i]), "Failed to add adapter");
            assertEq(quoter.trustedAdaptersCount(), i + 1, "Wrong amount of adapters");
        }
        vm.stopPrank();
    }

    /**
     * @notice Replaces adapters with the new list.
     * Checks that new adapters have been added to both Router and Quoter.
     */
    function _setAdapters(address[] memory adapters) internal {
        hoax(governance);
        quoter.setAdapters(adapters);
        for (uint256 i = 0; i < adapters.length; ++i) {
            assertTrue(router.isTrustedAdapter(adapters[i]), "Failed to add adapter");
        }
        assertEq(quoter.trustedAdaptersCount(), adapters.length, "Wrong amount of adapters");
    }

    // -- ADD | REMOVE TOKENS --

    /**
     * @notice Adds a few tokens to Quoter one by one using addTrustedToken.
     * Checks that all tokens were added afterwards.
     */
    function testAddTrustedToken() public {
        address[] memory tokens = utils.createEmptyUsers(5);

        _addTokens(tokens);
        _checkAddDuplicateTokens(tokens);
    }

    /**
     * @notice Removes tokens from Quoter using removeToken.
     * Checks that the tokens were correctly removed.
     */
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

    /**
     * @notice Removes tokens from Quoter using removeTokenByIndex.
     * Checks that the tokens were correctly removed.
     */
    function testRemoveTokenByIndex() public {
        address[] memory tokens = utils.createEmptyUsers(5);
        _addTokens(tokens);

        _removeTokenByIndex(tokens, 1, 1); // [0, 4, 2, 3]
        _removeTokenByIndex(tokens, 0, 0); // [3, 4, 2]
        _removeTokenByIndex(tokens, 1, 4); // [3, 2]
        _removeTokenByIndex(tokens, 0, 3); // [2]
        _removeTokenByIndex(tokens, 0, 2);
    }

    /**
     * @notice Checks that setTokens sets a list of tokens.
     * Also checks that setTokens removes all old tokens from Quoter.
     */
    function testSetTokens() public {
        address[] memory tokens = utils.createEmptyUsers(5);

        _setTokens(tokens);

        address[] memory newTokens = utils.createEmptyUsers(10);

        _setTokens(newTokens);
        // should be able to add old tokens
        _addTokens(tokens);
    }

    /**
     * @notice Checks that provided tokens have been already added to Quoter.
     */
    function _checkAddDuplicateTokens(address[] memory tokens) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            _checkIfTokenPresent(tokens[i]);
        }
    }

    /**
     * @notice Checks that provided token has been already added to Quoter.
     * addTrustedToken reverts => token has been added
     */
    function _checkIfTokenPresent(address token) internal {
        utils.checkRevert(
            governance,
            address(quoter),
            abi.encodeWithSelector(quoter.addTrustedToken.selector, token),
            "Token already added"
        );
    }

    /**
     * @notice Checks that provided token has not been already added to Quoter.
     * addTrustedToken succeeds => token has not been added
     * Removes token afterwards, so the state is unchanged.
     */
    function _checkIfTokenAbsent(address token) internal {
        startHoax(governance);
        quoter.addTrustedToken(token);
        quoter.removeToken(token);
        vm.stopPrank();
    }

    /**
     * @notice Adds token one by one and checks that the amount of tokens is updated.
     */
    function _addTokens(address[] memory tokens) internal {
        uint256 amount = quoter.trustedTokensCount();
        startHoax(governance);
        for (uint256 i = 0; i < tokens.length; ++i) {
            quoter.addTrustedToken(tokens[i]);
            assertEq(quoter.trustedTokensCount(), amount + i + 1, "Wrong amount of tokens");
        }
        vm.stopPrank();
    }

    /**
     * @notice Replaces current tokens with the new list.
     * Checks that all tokens from the list were added afterwards.
     */
    function _setTokens(address[] memory tokens) internal {
        hoax(governance);
        quoter.setTokens(tokens);
        _checkAddDuplicateTokens(tokens);
    }

    /**
     * @notice Removes token using removeTokenByIndex
     * Checks that the token hasn't been mistakenly removed earlier.
     * Checks that token was removed afterwards.
     */
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