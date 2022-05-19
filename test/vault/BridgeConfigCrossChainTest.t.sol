// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../utils/Utilities.t.sol";

import {BridgeConfig} from "src-vault/BridgeConfigV4.sol";
import {Strings} from "@openzeppelin/contracts-4.5.0/utils/Strings.sol";

contract BridgeConfigCrossChainTest is Test {
    event TokenDeleted(uint256[] chainIdsEVM, uint256 deletedChainIdEVM, address deletedTokenEVM);

    event TokenMapUpdated(
        uint256[] chainIdsEVM,
        address[] bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string bridgeTokenNonEVM
    );

    event TokenStatusUpdated(uint256[] chainIdsEVM, uint256 originChainIdEVM, address originTokenEVM, bool isEnabled);

    address payable public immutable governance;
    address payable public immutable node;

    Utilities internal immutable utils;

    uint256 public constant MAX_ID_EVM = 10;
    uint256 public constant ID_NON_EVM = 69;

    uint256 public constant TEST_TOKENS = 5;

    mapping(uint256 => BridgeConfig) public configs;

    constructor() {
        utils = new Utilities();

        address payable[] memory users = utils.createUsers(10);
        governance = users[0];
        node = users[1];
    }

    function setUp() public {
        for (uint256 id = 1; id <= MAX_ID_EVM; ++id) {
            vm.chainId(id);
            BridgeConfig bc = new BridgeConfig();
            bc.initialize();

            bc.grantRole(bc.GOVERNANCE_ROLE(), governance);
            bc.grantRole(bc.NODEGROUP_ROLE(), node);

            configs[id] = bc;

            for (uint256 t = 0; t < TEST_TOKENS; ++t) {
                address token = _getToken(id, t);
                address wrapper = _getToken(id, t + 10 * TEST_TOKENS);
                hoax(governance);
                bc.addNewToken(token, wrapper, true, 0, 0, 0, 0, 0);
            }
        }
    }

    /**
     * @notice Adds a map for a pre-configured token on one of the chains,
     * checks that token map is set up correctly on all needed chains.
     */
    function testAddNewMapOnce(
        uint8 originChainId,
        uint8 tokenIndex,
        bool includeNonEVM
    ) public {
        vm.assume(originChainId < MAX_ID_EVM);
        vm.assume(tokenIndex < TEST_TOKENS);

        _addNewMap(originChainId + 1, tokenIndex, includeNonEVM);
    }

    /**
     * @notice Adds maps for all five pre-configured tokens. Checks that all five tokens
     * are setup correctly in the end.
     */
    function testAddNewMapFull() public {
        _addNewMap(1, 0, false);
        _addNewMap(3, 1, true);
        _addNewMap(5, 2, true);
        _addNewMap(7, 3, false);
        _addNewMap(9, 4, true);

        // check that previous tokens were not rekt
        _checkMap(1, 0, 0, false);
        _checkMap(3, 1, 0, true);
        _checkMap(5, 2, 0, true);
        _checkMap(7, 3, 0, false);
    }

    /**
     * @notice Adds maps for two pre-configured tokens. Adds new chains to both maps,
     * and checks that both tokens are setup correctly.
     */
    function testAddChainsToMap() public {
        uint256[] memory newChainIdsEVM;
        // [1, 3, 5, 7, 9]
        _addNewMap(1, 1, true);

        newChainIdsEVM = new uint256[](2);
        newChainIdsEVM[0] = 4;
        newChainIdsEVM[1] = 10;
        _addChainsToMap(3, 1, newChainIdsEVM, true);

        newChainIdsEVM = new uint256[](3);
        newChainIdsEVM[0] = 2;
        newChainIdsEVM[1] = 6;
        newChainIdsEVM[2] = 8;

        uint256[] memory chainIdsEVM = _addChainsToMap(10, 1, newChainIdsEVM, true);

        // [2, 5, 8]
        _addNewMap(2, 2, false);

        newChainIdsEVM = new uint256[](1);
        newChainIdsEVM[0] = 1;
        _addChainsToMap(5, 2, newChainIdsEVM, false);

        newChainIdsEVM = new uint256[](3);
        newChainIdsEVM[0] = 3;
        newChainIdsEVM[1] = 4;
        newChainIdsEVM[2] = 6;
        _addChainsToMap(1, 2, newChainIdsEVM, true);

        // Check that first token isn't rekt
        _checkMap(chainIdsEVM, 1, 0, true);
    }

    /**
     * @notice Checks that token status can be changed back and forth
     * from any of the chains it's deployed on.
     */
    function testUpdateTokenStatus() public {
        // [1, 3, 5, 7, 9]
        _addNewMap(1, 1, true);

        // [1, 3, 7, 9]
        _deleteToken(3, 5, 1, true);

        _updateTokenStatus(3, 1, true);
        _updateTokenStatus(7, 1, false);
        _updateTokenStatus(9, 1, true);

        // [2, 5, 8]
        _addNewMap(2, 2, false);

        uint256[] memory newChainIdsEVM = new uint256[](1);
        newChainIdsEVM[0] = 1;
        // [2, 5, 8, 1]
        _addChainsToMap(5, 2, newChainIdsEVM, true);
        _updateTokenStatus(1, 2, true);
        _updateTokenStatus(5, 2, false);
        _updateTokenStatus(8, 2, true);

        // [5, 10]
        _addNewMap(5, 4, false);
        _updateTokenStatus(10, 4, true);
        _updateTokenStatus(5, 4, false);
        newChainIdsEVM[0] = 7;
        // [5, 10, 7]
        _addChainsToMap(10, 4, newChainIdsEVM, false);
        _updateTokenStatus(7, 4, true);
    }

    /**
     * @notice Adds maps for two pre-configured tokens. Deletes a few tokens on different chains from these maps,
     * submitting removal tx on chain other than removed chain.
     * Checks that the setup is correct on both remaining and removed chains.
     */
    function testRemoveTokenOtherChain() public {
        // [1, 3, 5, 7, 9]
        _addNewMap(1, 1, true);

        // [1, 3, 7, 9]
        _deleteToken(3, 5, 1, true);
        // [1, 7, 9]
        _deleteToken(1, 3, 1, true);
        // [1, 7]
        _deleteToken(7, 9, 1, true);

        // [2, 5, 8]
        _addNewMap(2, 2, false);

        // [2, 5]
        _deleteToken(5, 8, 2, false);

        // [5]
        _deleteToken(5, 2, 2, false);

        // check that first token isn't rekt
        uint256[] memory chainIds = new uint256[](3);
        chainIds[0] = 1;
        chainIds[1] = 7;
        chainIds[2] = 9; // this chain should be deleted by now
        _checkMap(chainIds, 1, 9, true);
    }

    /**
     * @notice Adds maps for two pre-configured tokens. Deletes a few tokens on different chains from these maps,
     * submitting removal tx on the removed chain.
     * Checks that the setup is correct on both remaining and removed chains.
     */
    function testRemoveTokenLocalChain() public {
        // [1, 3, 5, 7, 9]
        _addNewMap(1, 1, true);
        // [1, 5, 7, 9]
        _deleteToken(3, 3, 1, true);

        // [2, 5, 8]
        _addNewMap(2, 2, false);
        // [2, 8]
        _deleteToken(5, 5, 2, false);
        // [8]
        _deleteToken(2, 2, 2, false);

        // check that first token isn't rekt
        _checkMap(1, 1, 3, true);
    }

    function testIncorrectAddChainsToMap() public {
        // [1, 3, 5, 7, 9]
        _addNewMap(1, 1, true);

        uint256[] memory newChainIds = new uint256[](3);
        newChainIds[0] = 2;
        newChainIds[1] = 3;
        newChainIds[2] = 4;
        address[] memory newBridgeTokens = new address[](newChainIds.length);
        for (uint256 i = 0; i < newChainIds.length; ++i) {
            newBridgeTokens[i] = _getToken(newChainIds[i], 1);
        }

        address token = _getToken(1, 1);

        utils.checkRevert(
            governance,
            address(configs[1]),
            abi.encodeWithSelector(BridgeConfig.addChainsToMap.selector, token, newChainIds, newBridgeTokens, 0, ""),
            "ChainId already present in map"
        );
    }

    function testIncorrectUpdateTokenStatus() public {
        // [1, 3, 5, 7, 9]
        _addNewMap(1, 1, true);

        utils.checkRevert(
            governance,
            address(configs[2]),
            abi.encodeWithSelector(BridgeConfig.changeTokenStatus.selector, _getToken(2, 1), true),
            "Token map not created"
        );
    }

    function testIncorrectRemoveTokenOtherChain() public {
        // [1, 3, 5, 7, 9]
        _addNewMap(1, 1, true);

        utils.checkRevert(
            governance,
            address(configs[1]),
            abi.encodeWithSelector(BridgeConfig.removeGlobalTokenEVM.selector, 2, _getToken(2, 1)),
            "Token doesn't exist"
        );
    }

    function testIncorrectRemoveTokenLocalChain() public {
        // [1, 3, 5, 7, 9]
        _addNewMap(1, 1, true);

        utils.checkRevert(
            governance,
            address(configs[2]),
            abi.encodeWithSelector(BridgeConfig.deleteTokenEVM.selector, _getToken(2, 1)),
            "Token map not created"
        );
    }

    // -- TEST GENERATION --

    function _getToken(uint256 chainId, uint256 tokenIndex) internal view returns (address) {
        return utils.bytes32ToAddress(keccak256(abi.encode(chainId, tokenIndex + 1)));
    }

    function _getTokenNonEVM(uint256 tokenIndex) internal pure returns (string memory) {
        return Strings.toString(tokenIndex);
    }

    function _getTestTokenAmountOfChains(uint256 tokenIndex) internal pure returns (uint256 amount) {
        amount = MAX_ID_EVM / (tokenIndex + 1);
    }

    function _generateChainIds(uint256 originChainId, uint256 amount)
        internal
        pure
        returns (uint256[] memory chainIdsEVM)
    {
        uint256 indexStep = MAX_ID_EVM / amount;
        chainIdsEVM = new uint256[](amount);
        uint256 index = originChainId;
        for (uint256 i = 0; i < amount; ++i) {
            chainIdsEVM[i] = index;
            index = index + indexStep;
            if (index > MAX_ID_EVM) index -= MAX_ID_EVM;
        }
    }

    // -- ADD NEW MAP --

    function _addNewMap(
        uint256 originChainId,
        uint256 tokenIndex,
        bool includeNonEVM
    ) internal {
        uint256 amount = _getTestTokenAmountOfChains(tokenIndex);
        uint256[] memory chainIdsEVM = _generateChainIds(originChainId, amount);
        address[] memory bridgeTokensEVM = new address[](amount);

        for (uint256 i = 0; i < amount; ++i) {
            bridgeTokensEVM[i] = _getToken(chainIdsEVM[i], tokenIndex);
        }

        uint256 chainIdNonEVM;
        string memory bridgeTokenNonEVM;

        if (includeNonEVM) {
            chainIdNonEVM = ID_NON_EVM;
            bridgeTokenNonEVM = _getTokenNonEVM(tokenIndex);
        }

        _addNewMap(originChainId, chainIdsEVM, bridgeTokensEVM, chainIdNonEVM, bridgeTokenNonEVM);

        _checkMap(chainIdsEVM, tokenIndex, 0, includeNonEVM);
    }

    function _addNewMap(
        uint256 originChainId,
        uint256[] memory chainIdsEVM,
        address[] memory bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string memory bridgeTokenNonEVM
    ) internal {
        vm.chainId(originChainId);

        vm.expectEmit(false, false, false, true);
        emit TokenMapUpdated(chainIdsEVM, bridgeTokensEVM, chainIdNonEVM, bridgeTokenNonEVM);

        hoax(governance);
        configs[originChainId].addNewMap(chainIdsEVM, bridgeTokensEVM, chainIdNonEVM, bridgeTokenNonEVM);

        _relayUpdateMap(originChainId, chainIdsEVM, bridgeTokensEVM, chainIdNonEVM, bridgeTokenNonEVM);
    }

    // solhint-disable-next-line
    struct _MapUpdEvent {
        uint256[] chainIdsEVM;
        address[] bridgeTokensEVM;
    }

    // -- ADD NEW CHAINS TO EXISTING MAP --

    function _addChainsToMap(
        uint256 originChainId,
        uint256 tokenIndex,
        uint256[] memory newChainIdsEVM,
        bool includeNonEVM
    ) internal returns (uint256[] memory chainIdsEVM) {
        address token = _getToken(originChainId, tokenIndex);
        address[] memory newBridgeTokensEVM = new address[](newChainIdsEVM.length);
        for (uint256 i = 0; i < newChainIdsEVM.length; ++i) {
            newBridgeTokensEVM[i] = _getToken(newChainIdsEVM[i], tokenIndex);
        }

        uint256 chainIdNonEVM;
        string memory bridgeTokenNonEVM;
        if (includeNonEVM) {
            chainIdNonEVM = ID_NON_EVM;
            bridgeTokenNonEVM = _getTokenNonEVM(tokenIndex);
        }

        chainIdsEVM = _addChainsToMap(
            originChainId,
            token,
            newChainIdsEVM,
            newBridgeTokensEVM,
            chainIdNonEVM,
            bridgeTokenNonEVM
        );

        _checkMap(chainIdsEVM, tokenIndex, 0, includeNonEVM);
    }

    function _addChainsToMap(
        uint256 originChainId,
        address token,
        uint256[] memory newChainIdsEVM,
        address[] memory newBridgeTokensEVM,
        uint256 chainIdNonEVM,
        string memory bridgeTokenNonEVM
    ) internal returns (uint256[] memory allChainIdsEVM) {
        vm.chainId(originChainId);

        _MapUpdEvent memory data;

        (data.chainIdsEVM, data.bridgeTokensEVM) = _mergeMaps(originChainId, token, newChainIdsEVM, newBridgeTokensEVM);

        vm.expectEmit(false, false, false, true);
        emit TokenMapUpdated(data.chainIdsEVM, data.bridgeTokensEVM, chainIdNonEVM, bridgeTokenNonEVM);

        hoax(governance);
        configs[originChainId].addChainsToMap(
            token,
            newChainIdsEVM,
            newBridgeTokensEVM,
            chainIdNonEVM,
            bridgeTokenNonEVM
        );

        _relayUpdateMap(originChainId, data.chainIdsEVM, data.bridgeTokensEVM, chainIdNonEVM, bridgeTokenNonEVM);

        allChainIdsEVM = data.chainIdsEVM;
    }

    // -- DELETE TOKEN FROM MAP --

    function _deleteToken(
        uint256 originChainId,
        uint256 chainIdToDelete,
        uint256 tokenIndex,
        bool includeNonEVM
    ) internal {
        uint256[] memory chainIdsEVM = _deleteToken(
            originChainId,
            chainIdToDelete,
            _getToken(chainIdToDelete, tokenIndex)
        );
        _checkMap(chainIdsEVM, tokenIndex, chainIdToDelete, includeNonEVM);
    }

    function _deleteToken(
        uint256 originChainId,
        uint256 chainIdToDelete,
        address tokenToDelete
    ) internal returns (uint256[] memory chainIdsEVM) {
        vm.chainId(originChainId);
        BridgeConfig bc = configs[originChainId];
        chainIdsEVM = bc.getTokenChainIds(
            originChainId == chainIdToDelete ? tokenToDelete : bc.findTokenEVM(chainIdToDelete, tokenToDelete)
        );

        vm.expectEmit(false, false, false, true);
        emit TokenDeleted(chainIdsEVM, chainIdToDelete, tokenToDelete);

        hoax(governance);
        if (originChainId == chainIdToDelete) {
            bc.deleteTokenEVM(tokenToDelete);
        } else {
            bc.removeGlobalTokenEVM(chainIdToDelete, tokenToDelete);
        }

        _relayDeleteToken(originChainId, chainIdsEVM, chainIdToDelete, tokenToDelete);
    }

    function _mergeMaps(
        uint256 chainId,
        address token,
        uint256[] memory newChainIdsEVM,
        address[] memory newBridgeTokensEVM
    ) internal view returns (uint256[] memory chainIds, address[] memory bridgeTokensEVM) {
        BridgeConfig bc = configs[chainId];
        uint256[] memory oldChainIdsEVM = bc.getTokenChainIds(token);
        uint256 newLen = oldChainIdsEVM.length;

        for (uint256 i = 0; i < newChainIdsEVM.length; ++i) {
            (address tokenDst, ) = bc.getTokenAddressEVM(token, newChainIdsEVM[i]);
            if (tokenDst == address(0)) ++newLen;
        }

        chainIds = new uint256[](newLen);
        bridgeTokensEVM = new address[](newLen);

        for (uint256 i = 0; i < oldChainIdsEVM.length; ++i) {
            uint256 _chainId = oldChainIdsEVM[i];
            (address tokenDst, ) = bc.getTokenAddressEVM(token, _chainId);
            chainIds[i] = _chainId;
            bridgeTokensEVM[i] = tokenDst;
        }

        uint256 cur = oldChainIdsEVM.length;

        for (uint256 i = 0; i < newChainIdsEVM.length; ++i) {
            (address tokenDst, ) = bc.getTokenAddressEVM(token, newChainIdsEVM[i]);
            if (tokenDst == address(0)) {
                chainIds[cur] = newChainIdsEVM[i];
                bridgeTokensEVM[cur] = newBridgeTokensEVM[i];
                ++cur;
            }
        }
    }

    // -- UPDATE TOKEN STATUS --

    function _updateTokenStatus(
        uint256 originChainId,
        uint256 tokenIndex,
        bool isEnabled
    ) internal {
        vm.chainId(originChainId);
        BridgeConfig bc = configs[originChainId];
        address originToken = _getToken(originChainId, tokenIndex);
        uint256[] memory chainIdsEVM = bc.getTokenChainIds(originToken);

        vm.expectEmit(false, false, false, true);
        emit TokenStatusUpdated(chainIdsEVM, originChainId, originToken, isEnabled);

        hoax(governance);
        bc.changeTokenStatus(originToken, isEnabled);

        _relayUpdateTokenStatus(originChainId, originToken, chainIdsEVM, isEnabled);

        _checkTokenStatus(chainIdsEVM, tokenIndex, isEnabled);
    }

    // -- RELAY BRIDGE CONFIGURATION TO OTHER CHAINS --

    function _relayUpdateMap(
        uint256 originChainId,
        uint256[] memory chainIdsEVM,
        address[] memory bridgeTokensEVM,
        uint256 chainIdNonEVM,
        string memory bridgeTokenNonEVM
    ) internal {
        for (uint256 i = 0; i < chainIdsEVM.length; i++) {
            uint256 chainId = chainIdsEVM[i];
            if (chainId == originChainId) {
                // Do not relay Event to chain where it originated from
                continue;
            }
            vm.chainId(chainId);
            hoax(node);
            configs[chainId].updateMap(chainIdsEVM, bridgeTokensEVM, chainIdNonEVM, bridgeTokenNonEVM);
        }
    }

    function _relayUpdateTokenStatus(
        uint256 originChainId,
        address originToken,
        uint256[] memory chainIdsEVM,
        bool isEnabled
    ) internal {
        for (uint256 i = 0; i < chainIdsEVM.length; i++) {
            uint256 chainId = chainIdsEVM[i];
            if (chainId == originChainId) {
                // Do not relay Event to chain where it originated from
                continue;
            }
            vm.chainId(chainId);
            hoax(node);
            configs[chainId].updateTokenStatus(originChainId, originToken, isEnabled);
        }
    }

    function _relayDeleteToken(
        uint256 originChainId,
        uint256[] memory chainIdsEVM,
        uint256 deletedChainId,
        address deletedToken
    ) internal {
        for (uint256 i = 0; i < chainIdsEVM.length; i++) {
            uint256 chainId = chainIdsEVM[i];
            if (chainId == originChainId) {
                // Do not relay Event to chain where it originated from
                continue;
            }
            vm.chainId(chainId);
            hoax(node);
            configs[chainId].removeTokenEVM(deletedChainId, deletedToken);
        }
    }

    // -- TEST MAP SETUP --

    function _checkMap(
        uint256 originChainId,
        uint256 tokenIndex,
        uint256 emptyChainId,
        bool includeNonEVM
    ) internal {
        _checkMap(
            _generateChainIds(originChainId, _getTestTokenAmountOfChains(tokenIndex)),
            tokenIndex,
            emptyChainId,
            includeNonEVM
        );
    }

    function _checkMap(
        uint256[] memory chainIds,
        uint256 tokenIndex,
        uint256 emptyChainId,
        bool includeNonEVM
    ) internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            uint256 chainId = chainIds[i];
            vm.chainId(chainId);
            if (chainId == emptyChainId) {
                _checkTokenDeleted(chainIds, chainId, tokenIndex);
            } else {
                _checkTokenPresent(chainIds, chainId, tokenIndex, emptyChainId, includeNonEVM);
            }
        }
    }

    function _checkTokenDeleted(uint256[] memory chainIds, uint256 tokenIndex) internal {
        for (uint256 i = 0; i < chainIds.length; ++i) {
            _checkTokenDeleted(chainIds, chainIds[i], tokenIndex);
        }
    }

    function _checkTokenDeleted(
        uint256[] memory chainIds,
        uint256 chainId,
        uint256 tokenIndex
    ) internal {
        BridgeConfig bc = configs[chainId];
        address srcToken = _getToken(chainId, tokenIndex);
        {
            address[] memory bridgeTokens = bc.getBridgeTokens();
            uint256 found = 0;
            for (uint256 i = 0; i < bridgeTokens.length; ++i) {
                if (bridgeTokens[i] == srcToken) ++found;
            }
            assertEq(found, 0, "Deleted token present in list of bridge tokens");
            assertTrue(found <= 1, "Deleted token found more than once in bridgeTokens");
        }

        {
            (address bridgeToken, bool isEnabled, ) = bc.getBridgeToken(srcToken);
            assertEq(bridgeToken, address(0), "Bridge token stored for deleted token");
            assertFalse(isEnabled, "Deleted token is still enabled");
        }

        for (uint256 j = 0; j < chainIds.length; ++j) {
            uint256 dstChainId = chainIds[j];
            if (dstChainId == chainId) continue;
            (address dstToken, ) = bc.getTokenAddressEVM(srcToken, dstChainId);
            assertEq(dstToken, address(0), "Deleted token is still mapped to token from other EVM chain");

            address _srcToken = bc.findTokenEVM(dstChainId, _getToken(dstChainId, tokenIndex));
            assertEq(_srcToken, address(0), "Token from other EVM chain is still mapped to deleted");
        }

        {
            (string memory dstToken, ) = bc.getTokenAddressNonEVM(srcToken, ID_NON_EVM);
            assertEq(dstToken, "", "Deleted token is still mapped to token from non-EVM chain");

            address _srcToken = bc.findTokenNonEVM(ID_NON_EVM, _getTokenNonEVM(tokenIndex));
            assertEq(_srcToken, address(0), "Token from non-EVM chain is still mapped to deleted");
        }

        {
            uint256[] memory updChainIds = bc.getTokenChainIds(srcToken);
            assertEq(updChainIds.length, 0, "Still storing chain IDs for deleted token");
        }
    }

    function _checkTokenPresent(
        uint256[] memory chainIds,
        uint256 chainId,
        uint256 tokenIndex,
        uint256 emptyChainId,
        bool includeNonEVM
    ) internal {
        BridgeConfig bc = configs[chainId];
        address srcToken = _getToken(chainId, tokenIndex);
        vm.chainId(chainId);
        {
            address[] memory bridgeTokens = bc.getBridgeTokens();
            uint256 found = 0;
            for (uint256 i = 0; i < bridgeTokens.length; ++i) {
                if (bridgeTokens[i] == srcToken) ++found;
            }
            assertTrue(found != 0, "Token not found in bridgeTokens");
            assertTrue(found <= 1, "Token found more than once in bridgeTokens");
        }

        if (includeNonEVM) {
            string memory dstToken = _getTokenNonEVM(tokenIndex);

            (string memory _dstToken, ) = bc.getTokenAddressNonEVM(srcToken, ID_NON_EVM);
            assertEq(_dstToken, dstToken, "Incorrect getTokenAddressNonEVM");

            address _srcToken = bc.findTokenNonEVM(ID_NON_EVM, dstToken);
            assertEq(_srcToken, srcToken, "Incorrect findTokenNonEVM");
        } else {
            (string memory _dstToken, ) = bc.getTokenAddressNonEVM(srcToken, ID_NON_EVM);
            assertEq(_dstToken, "", "Non-existent token in getTokenAddressNonEVM");

            address _srcToken = bc.findTokenNonEVM(ID_NON_EVM, _getTokenNonEVM(tokenIndex));
            assertEq(_srcToken, address(0), "Non-existent token in findTokenNonEVM");
        }

        for (uint256 j = 0; j < chainIds.length; ++j) {
            uint256 dstChainId = chainIds[j];
            if (dstChainId == chainId) continue;

            if (dstChainId == emptyChainId) {
                (address _dstToken, ) = bc.getTokenAddressEVM(srcToken, emptyChainId);
                assertEq(_dstToken, address(0), "Non-existent token in getTokenAddressEVM");

                address _srcToken = bc.findTokenEVM(emptyChainId, _getToken(emptyChainId, tokenIndex));
                assertEq(_srcToken, address(0), "Non-existent token in findTokenEVM");
            } else {
                address dstToken = _getToken(dstChainId, tokenIndex);

                (address _dstToken, ) = bc.getTokenAddressEVM(srcToken, dstChainId);
                assertEq(_dstToken, dstToken, "Incorrect getTokenAddressEVM");

                address _srcToken = bc.findTokenEVM(dstChainId, dstToken);
                assertEq(_srcToken, srcToken, "Incorrect findTokenEVM");
            }
        }
    }

    // -- CHECK TOKEN STATUS --

    function _checkTokenStatus(
        uint256[] memory chainIdsEVM,
        uint256 tokenIndex,
        bool isEnabled
    ) internal {
        for (uint256 i = 0; i < chainIdsEVM.length; ++i) {
            uint256 chainId = chainIdsEVM[i];
            vm.chainId(chainId);

            assertEq(configs[chainId].isTokenEnabled(_getToken(chainId, tokenIndex)), isEnabled, "Incorrect isEnabled");
        }
    }
}
