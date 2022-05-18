// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../utils/DefaultBridgeTest.t.sol";
import {IBridgeConfig} from "src-vault/interfaces/IBridgeConfig.sol";

contract BridgeConfigSingleChainTest is DefaultBridgeTest {
    mapping(uint256 => address) public dstTokenAddress;
    string public nonEvmAddress;

    uint256 public constant MIN_FEE = 10**16;
    uint256 public constant MAX_ID_EVM = 10;
    IERC20 public token;

    function setUp() public virtual override {
        super.setUp();

        _setupTestToken();
    }

    /**
     * @notice Checks all access restricted functions.
     */
    function testAccessControl() public {
        address _bc = address(bridgeConfig);

        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(bridgeConfig.addNewToken.selector, address(0), address(0), false, 0, 0, 0, 0, 0),
            bridgeConfig.GOVERNANCE_ROLE()
        );
        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(bridgeConfig.updateTokenSetup.selector, address(0), address(0), false),
            bridgeConfig.GOVERNANCE_ROLE()
        );
        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(bridgeConfig.updateTokenFees.selector, address(0), 0, 0, 0, 0, 0),
            bridgeConfig.GOVERNANCE_ROLE()
        );

        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(bridgeConfig.addNewMap.selector, new uint256[](0), new address[](0), 0, ""),
            bridgeConfig.GOVERNANCE_ROLE()
        );
        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(
                bridgeConfig.addChainsToMap.selector,
                address(0),
                new uint256[](0),
                new address[](0),
                0,
                ""
            ),
            bridgeConfig.GOVERNANCE_ROLE()
        );
        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(bridgeConfig.changeTokenStatus.selector, address(0), false),
            bridgeConfig.GOVERNANCE_ROLE()
        );
        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(bridgeConfig.deleteTokenEVM.selector, address(0)),
            bridgeConfig.GOVERNANCE_ROLE()
        );
        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(bridgeConfig.removeGlobalTokenEVM.selector, 0, address(0)),
            bridgeConfig.GOVERNANCE_ROLE()
        );

        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(bridgeConfig.updateMap.selector, new uint256[](0), new address[](0), 0, ""),
            bridgeConfig.NODEGROUP_ROLE()
        );
        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(bridgeConfig.updateTokenStatus.selector, 0, address(0), false),
            bridgeConfig.NODEGROUP_ROLE()
        );
        utils.checkAccessControl(
            _bc,
            abi.encodeWithSelector(bridgeConfig.removeTokenEVM.selector, 0, address(0)),
            bridgeConfig.NODEGROUP_ROLE()
        );
    }

    /**
     * @notice Checks that bridge fee is calculated correctly.
     */
    function testCalculateBridgeFee(
        uint128 amount,
        bool gasdropRequested,
        bool isSwapPresent
    ) public {
        // amountOfSwaps is [0..4]
        uint256 amountOfSwaps = isSwapPresent ? 1 + (amount % 4) : 0;

        uint256 expectedFee = _calculateBridgeFee(amount, gasdropRequested, isSwapPresent);
        (uint256 actualFee, address bridgeToken, bool isEnabled, bool isMintBurn) = bridgeConfig.calculateBridgeFee(
            address(token),
            amount,
            gasdropRequested,
            amountOfSwaps
        );

        assertEq(actualFee, expectedFee, "Wrong fee");
        assertEq(address(bridgeToken), address(token), "Wrong bridge token");
        assertTrue(isEnabled, "Wrong isEnabled status");
        assertTrue(isMintBurn, "Wrong isMintBurn status");
    }

    /**
     * @notice Checks that bridge wrapper is returned correctly.
     */
    function testGetBridgeToken() public {
        IERC20 test = _deployERC20("XMG");
        address wrapper = utils.bytes32ToAddress(keccak256("wrapper"));

        hoax(governance);
        bridgeConfig.addNewToken(address(test), wrapper, true, 0, 0, 0, 0, 0);

        (address bridgeToken, bool isEnabled, bool isMintBurn) = bridgeConfig.getBridgeToken(address(test));

        assertEq(bridgeToken, wrapper, "Failed to report wrapper contract");
        // set two booleans opposite to check correct order
        assertFalse(isEnabled, "Failed to report isEnabled");
        assertTrue(isMintBurn, "Failed to report isMintBurn");

        (bridgeToken, isEnabled, ) = bridgeConfig.getBridgeToken(wrapper);
        assertEq(bridgeToken, address(0), "Reported non-existent bridge token");
        assertFalse(isEnabled, "Reported inactive token");
    }

    /**
     * @notice Checks that token address on dst EVM chain is reported correctly.
     */
    function testGetTokenAddressEVM() public {
        for (uint256 id = 1; id <= MAX_ID_EVM; ++id) {
            (address dstToken, bool isEnabled) = bridgeConfig.getTokenAddressEVM(address(token), id);
            assertEq(dstToken, dstTokenAddress[id], "Failed to report token address on dst chain");
            assertTrue(isEnabled, "Failed to report isEnabled");
        }
        {
            (address dstToken, bool isEnabled) = bridgeConfig.getTokenAddressEVM(address(token), MAX_ID_EVM + 1);
            assertEq(dstToken, address(0), "Reported non-existent dst token");
            assertFalse(isEnabled, "Reported inactive token");
        }
    }

    /**
     * @notice Checks that token address on dst non-EVM chain is reported correctly.
     */
    function testGetTokenAddressNonEVM() public {
        (string memory dstToken, bool isEnabled) = bridgeConfig.getTokenAddressNonEVM(address(token), ID_NON_EVM);
        assertEq(dstToken, nonEvmAddress, "Failed to report token address on dst chain");
        assertTrue(isEnabled, "Failed to report isEnabled");

        (dstToken, isEnabled) = bridgeConfig.getTokenAddressNonEVM(address(token), ID_NON_EVM + 1);
        assertEq(dstToken, "", "Reported non-existent dst token");
        assertFalse(isEnabled, "Reported inactive token");
    }

    /**
     * @notice Checks that src token is reported correctly for given token on dst EVM chain.
     */
    function testFindTokenEVM() public {
        for (uint256 id = 1; id <= MAX_ID_EVM; ++id) {
            address srcToken = bridgeConfig.findTokenEVM(id, dstTokenAddress[id]);
            assertEq(srcToken, address(token), "Failed to find src token");
        }
        for (uint256 id = 1; id <= MAX_ID_EVM; ++id) {
            for (uint256 _id = 1; _id <= MAX_ID_EVM; ++_id) {
                if (id != _id) {
                    address srcToken = bridgeConfig.findTokenEVM(id, dstTokenAddress[_id]);
                    assertEq(srcToken, address(0), "Reported non-existent token");
                }
            }
        }
    }

    /**
     * @notice Checks that src token is reported correctly for given token on dst non-EVM chain.
     */
    function testFindTokenNonEVM() public {
        address srcToken = bridgeConfig.findTokenNonEVM(ID_NON_EVM, nonEvmAddress);
        assertEq(srcToken, address(token), "Failed to find src token");

        srcToken = bridgeConfig.findTokenNonEVM(ID_NON_EVM - 1, nonEvmAddress);
        assertEq(srcToken, address(0), "Reported non-existent token");

        srcToken = bridgeConfig.findTokenNonEVM(ID_NON_EVM, string(abi.encodePacked(nonEvmAddress, " ")));
        assertEq(srcToken, address(0), "Reported non-existent token");
    }

    /**
     * @notice Checks that a list of tokens existing on this and given dst EVM chain is reported correctly.
     */
    function testGetAllBridgeTokensEVM() public {
        // Parent contract has three bridge tokens setup between this chain, EVM (chainId = 1) and non-EVM
        // This contract has a single bridge token between this chain, EVMs (ids = 1..10) and non-EVM
        {
            uint256 id = 1;
            (address[] memory tokensSrc, address[] memory tokensDst) = bridgeConfig.getAllBridgeTokensEVM(id);
            assertEq(tokensSrc.length, tokensDst.length, "Failed to report equal sized arrays");
            assertEq(tokensSrc.length, bridgeTokens.length + 1, "Wrong amount of bridge tokens for ID=1");

            for (uint256 t = 0; t < tokensSrc.length; ++t) {
                if (tokensSrc[t] == address(token)) {
                    assertEq(tokensDst[t], dstTokenAddress[id], "Failed to report dst token for ID=1");
                } else {
                    assertTrue(tokensSrc[t] != address(0), "Reported zero src token address");
                    assertEq(tokensDst[t], tokenAddressEVM[tokensSrc[t]], "Failed to report dst token for ID=1");
                }
            }
        }

        for (uint256 id = 2; id <= 10; ++id) {
            (address[] memory tokensSrc, address[] memory tokensDst) = bridgeConfig.getAllBridgeTokensEVM(id);
            assertEq(tokensSrc.length, tokensDst.length, "Failed to report equal sized arrays");
            assertEq(tokensSrc.length, 1, "Wrong amount of bridge tokens for ID>1");

            assertEq(tokensSrc[0], address(token), "Failed to report src token address");
            assertEq(tokensDst[0], dstTokenAddress[id], "Failed to report dst token for ID>1");
        }

        {
            (address[] memory tokensSrc, address[] memory tokensDst) = bridgeConfig.getAllBridgeTokensEVM(ID_NON_EVM);
            assertEq(tokensSrc.length, 0, "Reported non-existent tokens");
            assertEq(tokensDst.length, 0, "Reported non-existent tokens");
        }
    }

    /**
     * @notice Checks that a list of tokens existing on this and given dst non-EVM chain is reported correctly.
     */
    function testGetAllBridgeTokensNonEVM() public {
        // Parent contract has three bridge tokens setup between this chain, EVM (chainId = 1) and non-EVM
        // This contract has a single bridge token between this chain, EVMs (ids = 1..10) and non-EVM
        {
            (address[] memory tokensSrc, string[] memory tokensDst) = bridgeConfig.getAllBridgeTokensNonEVM(ID_NON_EVM);
            assertEq(tokensSrc.length, tokensDst.length, "Failed to report equal sized arrays");
            assertEq(tokensSrc.length, bridgeTokens.length + 1, "Wrong amount of bridge tokens");

            for (uint256 t = 0; t < tokensSrc.length; ++t) {
                if (tokensSrc[t] == address(token)) {
                    assertEq(tokensDst[t], nonEvmAddress, "Failed to report dst token");
                } else {
                    assertTrue(tokensSrc[t] != address(0), "Reported zero src token address");
                    assertEq(tokensDst[t], tokenAddressNonEVM[tokensSrc[t]], "Failed to report dst token");
                }
            }
        }

        {
            (address[] memory tokensSrc, string[] memory tokensDst) = bridgeConfig.getAllBridgeTokensNonEVM(ID_EVM);
            assertEq(tokensSrc.length, 0, "Reported non-existent tokens");
            assertEq(tokensDst.length, 0, "Reported non-existent tokens");
        }
    }

    /**
     * @notice Checks that token isEnabled status is reported correctly.
     */
    function testIsTokenEnabled() public {
        for (uint256 index = 0; index < allTokens.length; index++) {
            address t = allTokens[index];
            bool isEnabled = bridgeConfig.isTokenEnabled(t);
            assertEq(
                isEnabled,
                t == address(token) ||
                    t == address(_tokens.nETH) ||
                    t == address(_tokens.nUSD) ||
                    t == address(_tokens.syn),
                "Failed to report isEnabled"
            );
            (, , bool _isEnabled, , , , , , , ) = bridgeConfig.tokenConfigs(t);
            assertEq(
                _isEnabled,
                t == address(token) ||
                    t == address(_tokens.nETH) ||
                    t == address(_tokens.nUSD) ||
                    t == address(_tokens.syn),
                "Failed to store isEnabled"
            );
        }
    }

    /**
     * @notice Checks that it's not possible to "incorrectly" add token to BridgeConfig:
     * 1. Duplicate token via addNewToken
     * 2. Update setup for non-existent token via updateTokenSetup
     * 3. Update fees for non-existent token via updateTokenFees
     */
    function testIncorrectAddToken() public {
        address _bc = address(bridgeConfig);
        // Should not be able to add existing token
        utils.checkRevert(
            governance,
            _bc,
            abi.encodeWithSelector(bridgeConfig.addNewToken.selector, token, address(0), false, 0, 0, 0, 0, 0),
            "Token already added"
        );
        address fake = address(1337);
        // Should not be able to update non-existing token
        utils.checkRevert(
            governance,
            _bc,
            abi.encodeWithSelector(bridgeConfig.updateTokenSetup.selector, fake, fake, false),
            "Token not added"
        );
        utils.checkRevert(
            governance,
            _bc,
            abi.encodeWithSelector(bridgeConfig.updateTokenFees.selector, fake, 0, 0, 0, 0, 0),
            "Token not added"
        );
    }

    /**
     * @notice Checks that updateTokenSetup does in fact update token setup:
     * - its "bridge token wrapper"
     * - whether token is minted or withdrawn
     */
    function testUpdateTokenSetup() public {
        hoax(governance);
        bridgeConfig.addNewToken(address(420), address(1337), false, 1, 2, 3, 4, 5);
        _checkTokenSetup(address(420), IBridgeConfig.TokenType.DEPOSIT_WITHDRAW, address(1337), false);

        hoax(governance);
        bridgeConfig.updateTokenSetup(address(420), address(69), true);
        _checkTokenSetup(address(420), IBridgeConfig.TokenType.MINT_BURN, address(69), false);
    }

    /**
     * @notice Checks that updateTokenFees does in fact update all token fees.
     */
    function testUpdateTokenFees() public {
        hoax(governance);
        bridgeConfig.addNewToken(address(420), address(1337), false, 1, 2, 3, 4, 5);
        _checkTokenFees(address(420), 1, 2, 3, 4, 5);

        hoax(governance);
        bridgeConfig.updateTokenFees(address(420), 10, 20, 30, 40, 50);
        _checkTokenFees(address(420), 10, 20, 30, 40, 50);
    }

    /**
     * @notice Adds tokens and makes sure all params are assigned correctly.
     */
    function testAddToken() public {
        hoax(governance);
        bridgeConfig.addNewToken(address(420), address(1337), false, 1, 2, 3, 4, 5);

        _checkTokenSetup(address(420), IBridgeConfig.TokenType.DEPOSIT_WITHDRAW, address(1337), false);
        _checkTokenFees(address(420), 1, 2, 3, 4, 5);

        hoax(governance);
        bridgeConfig.addNewToken(address(42), address(69), true, 5, 4, 3, 2, 1);

        _checkTokenSetup(address(42), IBridgeConfig.TokenType.MINT_BURN, address(69), false);
        _checkTokenFees(address(42), 5, 4, 3, 2, 1);
    }

    function _checkTokenSetup(
        address _token,
        IBridgeConfig.TokenType tokenType,
        address bridgeToken,
        bool isEnabled
    ) internal {
        (IBridgeConfig.TokenType _tokenType, address _bridgeToken, bool _isEnabled, , , , , , , ) = bridgeConfig
        .tokenConfigs(_token);

        assertEq(uint8(_tokenType), uint8(tokenType), "Wrong token type");
        assertEq(_bridgeToken, bridgeToken, "Wrong bridge token");
        assertEq(_isEnabled, isEnabled, "Wrong isEnabled status");
    }

    function _checkTokenFees(
        address _token,
        uint256 synapseFee,
        uint256 maxTotalFee,
        uint256 minBridgeFee,
        uint256 minGasDropFee,
        uint256 minSwapFee
    ) internal {
        (
            ,
            ,
            ,
            uint256 _synapseFee,
            uint256 _maxTotalFee,
            uint256 _minBridgeFee,
            uint256 _minGasDropFee,
            uint256 _minSwapFee,
            ,

        ) = bridgeConfig.tokenConfigs(_token);
        assertEq(_synapseFee, synapseFee, "Wrong Synapse Fee");
        assertEq(_maxTotalFee, maxTotalFee, "Wrong Total Fee");
        assertEq(_minBridgeFee, minBridgeFee, "Wrong Min Bridge Fee");
        assertEq(_minGasDropFee, minGasDropFee, "Wrong Min GasDrop Fee");
        assertEq(_minSwapFee, minSwapFee, "Wrong Min Swap Fee");
    }

    function _calculateBridgeFee(
        uint256 amount,
        bool gasdropRequested,
        bool isSwapPresent
    ) internal pure returns (uint256 fee) {
        uint256 minFee = MIN_FEE;
        if (gasdropRequested) {
            minFee += 2 * MIN_FEE;
        }
        if (isSwapPresent) {
            minFee += 4 * MIN_FEE;
        }
        fee = (amount * FEE) / FEE_DENOMINATOR;
        if (fee < minFee) {
            fee = minFee;
        } else if (fee > MAX_FEE * MIN_FEE) {
            fee = MAX_FEE * MIN_FEE;
        }
    }

    function _setupTestToken() internal {
        token = _deployERC20("TEST");
        nonEvmAddress = "test";
        uint256[] memory chainIds = new uint256[](MAX_ID_EVM + 1);
        address[] memory tokenAddresses = new address[](MAX_ID_EVM + 1);

        chainIds[0] = block.chainid;
        tokenAddresses[0] = address(token);

        for (uint256 id = 1; id <= MAX_ID_EVM; ++id) {
            chainIds[id] = id;
            address tokenDst = utils.bytes32ToAddress(keccak256(abi.encode("TEST", id)));
            tokenAddresses[id] = tokenDst;
            dstTokenAddress[id] = tokenDst;
        }

        startHoax(governance);
        // 0.1% fee with maxTotalFee = 100 * minFee, bridgeFee = minFee, gasDropFee = 2*minFee, swapFee = 4*minFee
        bridgeConfig.addNewToken(
            address(token),
            address(token),
            true,
            FEE,
            MAX_FEE * MIN_FEE,
            MIN_FEE,
            2 * MIN_FEE,
            4 * MIN_FEE
        );
        bridgeConfig.addNewMap(chainIds, tokenAddresses, ID_NON_EVM, nonEvmAddress);
        bridgeConfig.changeTokenStatus(address(token), true);
        vm.stopPrank();
    }
}
