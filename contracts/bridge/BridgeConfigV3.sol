// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title BridgeConfig contract
 * @notice This token is used for configuring different tokens on the bridge and mapping them across chains.
 **/

contract BridgeConfigV3 is AccessControl {
    using SafeMath for uint256;
    bytes32 public constant BRIDGEMANAGER_ROLE =
        keccak256("BRIDGEMANAGER_ROLE");
    bytes32[] private _allTokenIDs;
    mapping(bytes32 => Token[]) private _allTokens; // key is tokenID
    mapping(uint256 => mapping(string => bytes32)) private _tokenIDMap; // key is chainID,tokenAddress
    mapping(bytes32 => mapping(uint256 => Token)) private _tokens; // key is tokenID,chainID
    mapping(address => mapping(uint256 => Pool)) private _pool; // key is tokenAddress,chainID
    mapping(uint256 => uint256) private _maxGasPrice; // key is tokenID,chainID
    uint256 public constant bridgeConfigVersion = 3;

    // the denominator used to calculate fees. For example, an
    // LP fee might be something like tradeAmount.mul(fee).div(FEE_DENOMINATOR)
    uint256 private constant FEE_DENOMINATOR = 10**10;

    // this struct must be initialized using setTokenConfig for each token that directly interacts with the bridge
    struct Token {
        uint256 chainId;
        string tokenAddress;
        uint8 tokenDecimals;
        uint256 maxSwap;
        uint256 minSwap;
        uint256 swapFee;
        uint256 maxSwapFee;
        uint256 minSwapFee;
        bool hasUnderlying;
        bool isUnderlying;
    }

    struct Pool {
        address tokenAddress;
        uint256 chainId;
        address poolAddress;
        bool metaswap;
    }

    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Returns a list of all existing token IDs converted to strings
     */
    function getAllTokenIDs() public view returns (string[] memory result) {
        uint256 length = _allTokenIDs.length;
        result = new string[](length);
        for (uint256 i = 0; i < length; ++i) {
            result[i] = toString(_allTokenIDs[i]);
        }
    }

    function _getTokenID(string memory tokenAddress, uint256 chainID)
        internal
        view
        returns (string memory)
    {
        return toString(_tokenIDMap[chainID][tokenAddress]);
    }

    function getTokenID(string memory tokenAddress, uint256 chainID)
        public
        view
        returns (string memory)
    {
        return _getTokenID(_toLower(tokenAddress), chainID);
    }

    /**
     * @notice Returns the token ID (string) of the cross-chain token inputted
     * @param tokenAddress address of token to get ID for
     * @param chainID chainID of which to get token ID for
     */
    function getTokenID(address tokenAddress, uint256 chainID)
        public
        view
        returns (string memory)
    {
        return _getTokenID(toString(tokenAddress), chainID);
    }

    /**
     * @notice Returns the full token config struct
     * @param tokenID String input of the token ID for the token
     * @param chainID Chain ID of which token address + config to get
     */
    function getToken(string memory tokenID, uint256 chainID)
        public
        view
        returns (Token memory token)
    {
        return _tokens[toBytes32(tokenID)][chainID];
    }

    /**
     * @notice Returns the full token config struct
     * @param tokenID String input of the token ID for the token
     * @param chainID Chain ID of which token address + config to get
     */
    function getTokenByID(string memory tokenID, uint256 chainID)
        public
        view
        returns (Token memory token)
    {
        return _tokens[toBytes32(tokenID)][chainID];
    }

    /**
     * @notice Returns token config struct, given an address and chainID
     * @param tokenAddress Matches the token ID by using a combo of address + chain ID
     * @param chainID Chain ID of which token to get config for
     */
    function getTokenByAddress(string memory tokenAddress, uint256 chainID)
        public
        view
        returns (Token memory token)
    {
        return _tokens[_tokenIDMap[chainID][tokenAddress]][chainID];
    }

    function getTokenByEVMAddress(address tokenAddress, uint256 chainID)
        public
        view
        returns (Token memory token)
    {
        return
            _tokens[_tokenIDMap[chainID][_toLower(toString(tokenAddress))]][
                chainID
            ];
    }

    /**
     * @notice Returns true if the token has an underlying token -- meaning the token is deposited into the bridge
     * @param tokenID String to check if it is a withdraw/underlying token
     */
    function hasUnderlyingToken(string memory tokenID)
        public
        view
        returns (bool)
    {
        bytes32 bytesTokenID = toBytes32(tokenID);
        Token[] memory _mcTokens = _allTokens[bytesTokenID];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].hasUnderlying) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Returns which token is the underlying token to withdraw
     * @param tokenID string token ID
     */
    function getUnderlyingToken(string memory tokenID)
        public
        view
        returns (Token memory token)
    {
        bytes32 bytesTokenID = toBytes32(tokenID);
        Token[] memory _mcTokens = _allTokens[bytesTokenID];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].isUnderlying) {
                return _mcTokens[i];
            }
        }
    }

    /**
     @notice Public function returning if token ID exists given a string
     */
    function isTokenIDExist(string memory tokenID) public view returns (bool) {
        return _isTokenIDExist(toBytes32(tokenID));
    }

    /**
     @notice Internal function returning if token ID exists given bytes32 version of the ID
     */
    function _isTokenIDExist(bytes32 tokenID) internal view returns (bool) {
        for (uint256 i = 0; i < _allTokenIDs.length; ++i) {
            if (_allTokenIDs[i] == tokenID) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Internal function which handles logic of setting token ID and dealing with mappings
     * @param tokenID bytes32 version of ID
     * @param chainID which chain to set the token config for
     * @param tokenToAdd Token object to set the mapping to
     */
    function _setTokenConfig(
        bytes32 tokenID,
        uint256 chainID,
        Token memory tokenToAdd
    ) internal returns (bool) {
        _tokens[tokenID][chainID] = tokenToAdd;
        if (!_isTokenIDExist(tokenID)) {
            _allTokenIDs.push(tokenID);
        }

        Token[] storage _mcTokens = _allTokens[tokenID];
        for (uint256 i = 0; i < _mcTokens.length; ++i) {
            if (_mcTokens[i].chainId == chainID) {
                string memory oldToken = _mcTokens[i].tokenAddress;
                if (compareStrings(tokenToAdd.tokenAddress, oldToken)) {
                    _mcTokens[i].tokenAddress = tokenToAdd.tokenAddress;
                    _tokenIDMap[chainID][oldToken] = keccak256("");
                    _tokenIDMap[chainID][tokenToAdd.tokenAddress] = tokenID;
                }
            }
        }
        _mcTokens.push(tokenToAdd);
        _tokenIDMap[chainID][tokenToAdd.tokenAddress] = tokenID;
        return true;
    }

    /**
     * @notice Main write function of this contract - Handles creating the struct and passing it to the internal logic function
     * @param tokenID string ID to set the token config object form
     * @param chainID chain ID to use for the token config object
     * @param tokenAddress token address of the token on the given chain
     * @param tokenDecimals decimals of token
     * @param maxSwap maximum amount of token allowed to be transferred at once - in native token decimals
     * @param minSwap minimum amount of token needed to be transferred at once - in native token decimals
     * @param swapFee percent based swap fee -- 10e6 == 10bps
     * @param maxSwapFee max swap fee to be charged - in native token decimals
     * @param minSwapFee min swap fee to be charged - in native token decimals - especially useful for mainnet ETH
     * @param hasUnderlying bool which represents whether this is a global mint token or one to withdraw()
     * @param isUnderlying bool which represents if this token is the one to withdraw on the given chain
     */
    function setTokenConfig(
        string calldata tokenID,
        uint256 chainID,
        address tokenAddress,
        uint8 tokenDecimals,
        uint256 maxSwap,
        uint256 minSwap,
        uint256 swapFee,
        uint256 maxSwapFee,
        uint256 minSwapFee,
        bool hasUnderlying,
        bool isUnderlying
    ) public returns (bool) {
        require(hasRole(BRIDGEMANAGER_ROLE, msg.sender));
        return
            setTokenConfig(
                tokenID,
                chainID,
                toString(tokenAddress),
                tokenDecimals,
                maxSwap,
                minSwap,
                swapFee,
                maxSwapFee,
                minSwapFee,
                hasUnderlying,
                isUnderlying
            );
    }

    /**
     * @notice Main write function of this contract - Handles creating the struct and passing it to the internal logic function
     * @param tokenID string ID to set the token config object form
     * @param chainID chain ID to use for the token config object
     * @param tokenAddress token address of the token on the given chain
     * @param tokenDecimals decimals of token
     * @param maxSwap maximum amount of token allowed to be transferred at once - in native token decimals
     * @param minSwap minimum amount of token needed to be transferred at once - in native token decimals
     * @param swapFee percent based swap fee -- 10e6 == 10bps
     * @param maxSwapFee max swap fee to be charged - in native token decimals
     * @param minSwapFee min swap fee to be charged - in native token decimals - especially useful for mainnet ETH
     * @param hasUnderlying bool which represents whether this is a global mint token or one to withdraw()
     * @param isUnderlying bool which represents if this token is the one to withdraw on the given chain
     */
    function setTokenConfig(
        string calldata tokenID,
        uint256 chainID,
        string memory tokenAddress,
        uint8 tokenDecimals,
        uint256 maxSwap,
        uint256 minSwap,
        uint256 swapFee,
        uint256 maxSwapFee,
        uint256 minSwapFee,
        bool hasUnderlying,
        bool isUnderlying
    ) public returns (bool) {
        require(hasRole(BRIDGEMANAGER_ROLE, msg.sender));
        Token memory tokenToAdd;
        tokenToAdd.tokenAddress = _toLower(tokenAddress);
        tokenToAdd.tokenDecimals = tokenDecimals;
        tokenToAdd.maxSwap = maxSwap;
        tokenToAdd.minSwap = minSwap;
        tokenToAdd.swapFee = swapFee;
        tokenToAdd.maxSwapFee = maxSwapFee;
        tokenToAdd.minSwapFee = minSwapFee;
        tokenToAdd.hasUnderlying = hasUnderlying;
        tokenToAdd.isUnderlying = isUnderlying;
        tokenToAdd.chainId = chainID;

        return _setTokenConfig(toBytes32(tokenID), chainID, tokenToAdd);
    }

    function _calculateSwapFee(
        string memory tokenAddress,
        uint256 chainID,
        uint256 amount
    ) internal view returns (uint256) {
        Token memory token = _tokens[_tokenIDMap[chainID][tokenAddress]][
            chainID
        ];
        uint256 calculatedSwapFee = amount.mul(token.swapFee).div(
            FEE_DENOMINATOR
        );
        if (
            calculatedSwapFee > token.minSwapFee &&
            calculatedSwapFee < token.maxSwapFee
        ) {
            return calculatedSwapFee;
        } else if (calculatedSwapFee > token.maxSwapFee) {
            return token.maxSwapFee;
        } else {
            return token.minSwapFee;
        }
    }

    /**
     * @notice Calculates bridge swap fee based on the destination chain's token transfer.
     * @dev This means the fee should be calculated based on the chain that the nodes emit a tx on
     * @param tokenAddress address of the destination token to query token config for
     * @param chainID destination chain ID to query the token config for
     * @param amount in native token decimals
     * @return Fee calculated in token decimals
     */
    function calculateSwapFee(
        string memory tokenAddress,
        uint256 chainID,
        uint256 amount
    ) external view returns (uint256) {
        return _calculateSwapFee(tokenAddress, chainID, amount);
    }

    /**
     * @notice Calculates bridge swap fee based on the destination chain's token transfer.
     * @dev This means the fee should be calculated based on the chain that the nodes emit a tx on
     * @param tokenAddress address of the destination token to query token config for
     * @param chainID destination chain ID to query the token config for
     * @param amount in native token decimals
     * @return Fee calculated in token decimals
     */
    function calculateSwapFee(
        address tokenAddress,
        uint256 chainID,
        uint256 amount
    ) external view returns (uint256) {
        return _calculateSwapFee(toString(tokenAddress), chainID, amount);
    }

    // GAS PRICING

    /**
     * @notice sets the max gas price for a chain
     */
    function setMaxGasPrice(uint256 chainID, uint256 maxPrice) public {
        require(hasRole(BRIDGEMANAGER_ROLE, msg.sender));
        _maxGasPrice[chainID] = maxPrice;
    }

    /**
     * @notice gets the max gas price for a chain
     */
    function getMaxGasPrice(uint256 chainID) public view returns (uint256) {
        return _maxGasPrice[chainID];
    }

    // POOL CONFIG

    function getPoolConfig(address tokenAddress, uint256 chainID)
        external
        view
        returns (Pool memory)
    {
        return _pool[tokenAddress][chainID];
    }

    function setPoolConfig(
        address tokenAddress,
        uint256 chainID,
        address poolAddress,
        bool metaswap
    ) external returns (Pool memory) {
        require(
            hasRole(BRIDGEMANAGER_ROLE, msg.sender),
            "Caller is not Bridge Manager"
        );
        Pool memory newPool = Pool(
            tokenAddress,
            chainID,
            poolAddress,
            metaswap
        );
        _pool[tokenAddress][chainID] = newPool;
        return newPool;
    }

    // UTILITY FUNCTIONS

    function toString(bytes32 data) internal pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && data[i] != 0) {
            ++i;
        }
        bytes memory bs = new bytes(i);
        for (uint8 j = 0; j < i; ++j) {
            bs[j] = data[j];
        }
        return string(bs);
    }

    // toBytes32 converts a string to a bytes 32
    function toBytes32(string memory str)
        internal
        pure
        returns (bytes32 result)
    {
        require(bytes(str).length <= 32);
        assembly {
            result := mload(add(str, 32))
        }
    }

    function toString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }

        string memory addrPrefix = "0x";

        return concat(addrPrefix, string(s));
    }

    function concat(string memory _x, string memory _y)
        internal
        pure
        returns (string memory)
    {
        bytes memory _xBytes = bytes(_x);
        bytes memory _yBytes = bytes(_y);

        string memory _tmpValue = new string(_xBytes.length + _yBytes.length);
        bytes memory _newValue = bytes(_tmpValue);

        uint256 i;
        uint256 j;

        for (i = 0; i < _xBytes.length; i++) {
            _newValue[j++] = _xBytes[i];
        }

        for (i = 0; i < _yBytes.length; i++) {
            _newValue[j++] = _yBytes[i];
        }

        return string(_newValue);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) {
            c = bytes1(uint8(b) + 0x30);
        } else {
            c = bytes1(uint8(b) + 0x57);
        }
    }

    function compareStrings(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    function _toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // Uppercase character...
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // So we add 32 to make it lowercase
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
}
