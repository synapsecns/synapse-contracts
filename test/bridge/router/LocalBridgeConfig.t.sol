// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../utils/Utilities06.sol";
import "../../../contracts/bridge/router/LocalBridgeConfig.sol";

// Harness for the abstract contract
contract LocalBridgeConfigHarness is LocalBridgeConfig {
    function calculateBridgeAmountOut(address token, uint256 amount) external view returns (uint256 amountOut) {
        return _calculateBridgeAmountOut(token, amount);
    }
} // solhint-disable-line no-empty-blocks

// solhint-disable func-name-mixedcase
contract LocalBridgeConfigTest is Utilities06 {
    address internal constant OWNER = address(123456);

    LocalBridgeConfigHarness internal bridgeConfig;

    function setUp() public override {
        super.setUp();
        bridgeConfig = new LocalBridgeConfigHarness();
        bridgeConfig.transferOwnership(OWNER);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          TESTS: ONLY OWNER                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_addToken_revert_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        expectOnlyOwnerRevert();
        vm.prank(caller);
        bridgeConfig.addToken("a", address(1), LocalBridgeConfig.TokenType.Redeem, address(1), 0, 0, 0);
    }

    function test_setTokenConfig_revert_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        expectOnlyOwnerRevert();
        vm.prank(caller);
        bridgeConfig.setTokenConfig(address(1), LocalBridgeConfig.TokenType.Redeem, address(1));
    }

    function test_setTokenFee_revert_onlyOwner(address caller) public {
        vm.assume(caller != OWNER);
        expectOnlyOwnerRevert();
        vm.prank(caller);
        bridgeConfig.setTokenFee(address(1), 0, 0, 0);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           TESTS: ADD TOKEN                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_addToken(
        string memory symbol,
        address token,
        uint8 tokenType_,
        address bridgeToken,
        uint40 bridgeFee,
        uint104 minFee,
        uint112 maxFee
    ) public {
        LocalBridgeConfig.TokenType tokenType = _castToTokenType(tokenType_);
        // token can not be zero
        vm.assume(token != address(0) && bridgeToken != address(0));
        // bridgeFee should be under 10**10
        vm.assume(bridgeFee < 10**10);
        // minFee should not be higher than maxFee
        vm.assume(minFee <= maxFee);
        vm.assume(bytes(symbol).length != 0);
        vm.prank(OWNER);
        assertTrue(bridgeConfig.addToken(symbol, token, tokenType, bridgeToken, bridgeFee, minFee, maxFee), "!added");
        _checkSymbol(symbol, token);
        _checkConfig(token, tokenType, bridgeToken);
        _checkFee(token, bridgeFee, minFee, maxFee);
    }

    function test_addToken_revert_zeroToken(address token, uint8 tokenType_) public {
        vm.expectRevert("Token can't be zero address");
        vm.prank(OWNER);
        bridgeConfig.addToken("a", token, _castToTokenType(tokenType_), address(0), 0, 0, 0);
        vm.expectRevert("Token can't be zero address");
        vm.prank(OWNER);
        bridgeConfig.addToken("a", address(0), _castToTokenType(tokenType_), token, 0, 0, 0);
    }

    function test_addToken_revert_incorrectBridgeFee(uint256 bridgeFee) public {
        vm.assume(bridgeFee >= 10**10);
        address token = address(1);
        vm.expectRevert("bridgeFee >= 100%");
        vm.prank(OWNER);
        bridgeConfig.addToken("a", token, LocalBridgeConfig.TokenType.Redeem, token, bridgeFee, 0, 0);
    }

    function test_addToken_revert_incorrectMinFee(uint104 minFee, uint112 maxFee) public {
        vm.assume(minFee > maxFee);
        address token = address(1);
        vm.expectRevert("minFee > maxFee");
        vm.prank(OWNER);
        bridgeConfig.addToken("a", token, LocalBridgeConfig.TokenType.Redeem, token, 0, minFee, maxFee);
    }

    function test_addToken_revert_emptySymbol() public {
        vm.expectRevert("Empty symbol");
        vm.prank(OWNER);
        bridgeConfig.addToken("", address(1), LocalBridgeConfig.TokenType.Redeem, address(1), 0, 0, 0);
    }

    function test_addToken_revert_symbolTaken(string memory symbol) public {
        vm.assume(bytes(symbol).length != 0);
        vm.prank(OWNER);
        bridgeConfig.addToken(symbol, address(1), LocalBridgeConfig.TokenType.Redeem, address(1), 0, 0, 0);
        vm.expectRevert("Symbol already in use");
        vm.prank(OWNER);
        bridgeConfig.addToken(symbol, address(2), LocalBridgeConfig.TokenType.Redeem, address(2), 0, 0, 0);
    }

    function test_addToken_twice(
        string memory symbol,
        address token,
        uint8 tokenType_,
        address bridgeToken,
        uint40 bridgeFee,
        uint104 minFee,
        uint112 maxFee
    ) public {
        LocalBridgeConfig.TokenType tokenType = _castToTokenType(tokenType_);
        test_addToken(symbol, token, tokenType_, bridgeToken, bridgeFee, minFee, maxFee);
        // Derive different values for every parameter
        LocalBridgeConfig.TokenType _tokenType = _castToTokenType(tokenType_ ^ 1);
        address _bridgeToken = bridgeToken == address(1) ? address(2) : address(1);
        uint40 _bridgeFee = bridgeFee == 1 ? 2 : 1;
        uint40 _minFee = minFee == 1 ? 2 : 1;
        uint40 _maxFee = maxFee == 10 ? 20 : 10;
        vm.prank(OWNER);
        assertFalse(
            bridgeConfig.addToken(symbol, token, _tokenType, _bridgeToken, _bridgeFee, _minFee, _maxFee),
            "Added twice"
        );
        // Check that the old values were not changed
        _checkConfig(token, tokenType, bridgeToken);
        _checkFee(token, bridgeFee, minFee, maxFee);
    }

    function test_removeToken(string memory symbol, address token) public {
        test_addToken(symbol, token, 1, address(1), 1, 1, 1);
        vm.prank(OWNER);
        assertTrue(bridgeConfig.removeToken(token), "!removed");
        _checkSymbolRemoved(symbol, token);
        _checkConfig(token, LocalBridgeConfig.TokenType(0), address(0));
        _checkFee(token, 0, 0, 0);
    }

    function test_removeToken_twice(address token) public {
        test_removeToken("a", token);
        vm.prank(OWNER);
        assertFalse(bridgeConfig.removeToken(token), "Removed twice");
    }

    function test_removeTokens() public {
        test_addToken("a", address(1), 0, address(1), 1, 1, 1);
        test_addToken("b", address(2), 1, address(2), 2, 2, 2);
        address[] memory tokens = new address[](2);
        tokens[0] = address(1);
        tokens[1] = address(2);
        vm.prank(OWNER);
        bridgeConfig.removeTokens(tokens);
        _checkSymbolRemoved("a", address(1));
        _checkConfig(address(1), LocalBridgeConfig.TokenType(0), address(0));
        _checkFee(address(1), 0, 0, 0);
        _checkSymbolRemoved("b", address(2));
        _checkConfig(address(2), LocalBridgeConfig.TokenType(0), address(0));
        _checkFee(address(2), 0, 0, 0);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TESTS: SET CONFIG / FEE                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_setTokenConfig(
        address token,
        uint8 tokenType_,
        address bridgeToken
    ) public {
        test_addToken("a", token, tokenType_, bridgeToken, 0, 0, 0);
        // Derive different values for every parameter
        LocalBridgeConfig.TokenType _tokenType = _castToTokenType(tokenType_ ^ 1);
        address _bridgeToken = bridgeToken == address(1) ? address(2) : address(1);
        vm.prank(OWNER);
        bridgeConfig.setTokenConfig(token, _tokenType, _bridgeToken);
        // Check that new values were applied
        _checkConfig(token, _tokenType, _bridgeToken);
    }

    function test_setTokenConfig_revert_unknownToken(
        address token,
        uint8 tokenType_,
        address bridgeToken
    ) public {
        // Add and remove a token to make it unknown
        test_removeToken("a", token);
        vm.expectRevert("Unknown token");
        vm.prank(OWNER);
        bridgeConfig.setTokenConfig(token, _castToTokenType(tokenType_), bridgeToken);
    }

    function test_setTokenConfig_revert_zeroToken(address token, uint8 tokenType_) public {
        test_addToken("a", token, tokenType_, token, 0, 0, 0);
        vm.expectRevert("Token can't be zero address");
        vm.prank(OWNER);
        bridgeConfig.setTokenConfig(token, _castToTokenType(tokenType_), address(0));
    }

    function test_setTokenFee(
        address token,
        uint40 bridgeFee,
        uint104 minFee,
        uint112 maxFee
    ) public {
        test_addToken("a", token, 0, token, bridgeFee, minFee, maxFee);
        // Derive different values for every parameter
        uint40 _bridgeFee = bridgeFee == 1 ? 2 : 1;
        uint40 _minFee = minFee == 1 ? 2 : 1;
        uint40 _maxFee = maxFee == 10 ? 20 : 10;
        vm.prank(OWNER);
        bridgeConfig.setTokenFee(token, _bridgeFee, _minFee, _maxFee);
        // Check that new values were applied
        _checkFee(token, _bridgeFee, _minFee, _maxFee);
    }

    function test_setTokenFee_revert_unknownToken(
        address token,
        uint40 bridgeFee,
        uint104 minFee,
        uint112 maxFee
    ) public {
        // Add and remove a token to make it unknown
        test_removeToken("a", token);
        vm.expectRevert("Unknown token");
        vm.prank(OWNER);
        bridgeConfig.setTokenFee(token, bridgeFee, minFee, maxFee);
    }

    function test_setTokenFee_revert_incorrectBridgeFee(uint256 bridgeFee) public {
        vm.assume(bridgeFee >= 10**10);
        address token = address(1);
        test_addToken("a", token, 0, token, 0, 0, 0);
        vm.expectRevert("bridgeFee >= 100%");
        vm.prank(OWNER);
        bridgeConfig.setTokenFee(token, bridgeFee, 0, 0);
    }

    function test_setTokenFee_revert_incorrectMinFee(uint104 minFee, uint112 maxFee) public {
        vm.assume(minFee > maxFee);
        address token = address(1);
        test_addToken("a", token, 0, token, 0, 0, 0);
        vm.expectRevert("minFee > maxFee");
        vm.prank(OWNER);
        bridgeConfig.setTokenFee(token, 0, minFee, maxFee);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        TESTS: FEE CALCULATION                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_bridgeFee(uint40 bridgeFee, uint256 amount) public {
        bridgeFee = bridgeFee % 10**10;
        // Values under 10**30 are fine for the testing
        amount = amount % 10**30;
        address token = address(1);
        uint104 minFee = 10**3;
        uint112 maxFee = 10**20;
        test_addToken("a", token, 0, token, bridgeFee, minFee, maxFee);
        uint256 expectedFee = (amount * bridgeFee) / 10**10;
        uint256 fee = bridgeConfig.calculateBridgeFee(token, amount);
        if (fee == expectedFee) {
            assertTrue(fee >= minFee, "under minFee");
            assertTrue(fee <= maxFee, "over maxFee");
        } else if (fee < expectedFee) {
            assertEq(fee, maxFee, "not a maxFee");
        } else {
            // fee > expectedFee
            assertEq(fee, minFee, "not a minFee");
        }

        uint256 amountOut = bridgeConfig.calculateBridgeAmountOut(token, amount);
        if (amountOut + fee == amount) {
            assertTrue(amount >= fee, "amount under fee");
        } else {
            assertTrue(amount < fee, "amount not under fee");
            assertEq(amountOut, 0, "bridgeAmountOut not zero");
        }
    }

    function test_bridgeFee_revert_unknownToken() public {
        address token = address(1);
        // Add and remove a token to make it unknown
        test_removeToken("a", token);
        vm.expectRevert("Token not supported");
        bridgeConfig.calculateBridgeFee(token, 0);
        vm.expectRevert("Token not supported");
        bridgeConfig.calculateBridgeAmountOut(token, 0);
    }

    function _checkSymbol(string memory symbol, address token) internal {
        assertEq(bridgeConfig.tokenToSymbol(token), symbol, "!symbol");
        assertEq(bridgeConfig.symbolToToken(symbol), token, "!token");
    }

    function _checkSymbolRemoved(string memory symbol, address token) internal {
        assertEq(bridgeConfig.tokenToSymbol(token), "", "!symbol");
        assertEq(bridgeConfig.symbolToToken(symbol), address(0), "!token");
    }

    function _checkConfig(
        address token,
        LocalBridgeConfig.TokenType tokenType,
        address bridgeToken
    ) internal {
        (LocalBridgeConfig.TokenType _tokenType, address _bridgeToken) = bridgeConfig.config(token);
        assertTrue(_tokenType == tokenType, "!tokenType");
        assertEq(_bridgeToken, bridgeToken, "!bridgeToken");
    }

    function _checkFee(
        address token,
        uint40 bridgeFee,
        uint104 minFee,
        uint112 maxFee
    ) internal {
        (uint40 _bridgeFee, uint104 _minFee, uint112 _maxFee) = bridgeConfig.fee(token);
        assertEq(_bridgeFee, uint256(bridgeFee), "!bridgeFee");
        assertEq(_minFee, uint256(minFee), "!minFee");
        assertEq(_maxFee, uint256(maxFee), "!maxFee");
    }

    function _castToTokenType(uint8 tokenType_) internal pure returns (LocalBridgeConfig.TokenType tokenType) {
        // type(enum).max is not available in 0.6.12
        tokenType = LocalBridgeConfig.TokenType(tokenType_ % 2);
    }
}
