// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import {IMintBurnWrapper} from "../interfaces/IMintBurnWrapper.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts-solc8/access/AccessControl.sol";

interface IERC20Decimals is IERC20 {
    function decimals() external view returns (uint8);
}

/**
    @dev This contract is used as a bridge mint-burn token on chains where 
         native (underlying) token is not directly compatible with Synapse:Bridge.
         A way to perform 1:1 "swap" between MintBurnWrapper and tokenNative has to exist.

    Here's the list of all contracts that will be interacting with MintBurnWrapper.
    List is constructed using implementation of Router from this branch (yeah, it's annoying, I know):
    https://github.com/synapsecns/synapse-contracts/tree/chisq/adapters-optimising/contracts/router

                    Getting MintBurnWrapper as parameter:
    1. Bridge
                Externally:
        1. mint [as token] -> _mint(token)
        2. mintAndSwapV2 [as token] -> _mint(token); _handleSwap(token)
        3. redeem(Max) [as token] -> _redeem(token); _getMaxAmount(token)
        4. redeemV2(Max) [as token] -> _redeemV2(token); _getMaxAmount(token)
        5. redeem(Max)AndSwapV2 [as token] -> _redeemAndSwapV2(token); _getMaxAmount(token)

                Internally:
        (1) _mint [as token] -> Vault.mintToken(token)
        (2) _handleSwap [as token] -> BridgeRouter.refundToAddress(token)
            (swapParams.path[0] would be underlying token)
        3. _redeem(AndSwap)(V2) [as token] -> _burnFromSender(token)
        [4] _burnFromSender [as token] -> token.balanceOf(); token.burnFrom()
        [5] _getMaxAmount [as token] -> token.balanceOf(); token.allowance()

    2. Vault
                Externally:
        [1] mintToken [as token] -> _getUnderlyingToken(token); token.mint()

                Internally:
        1. _getUnderlyingToken [as token] -> read underlyingTokens[token]

    3. BridgeRouter
                Externally:
        1. refundToAddress [as token] -> _getUnderlyingToken(token)

                Internally:
        1. _getUnderlyingToken [as token] -> read underlyingTokens[token]
        (2) _callBridge [as _getBridgeToken] -> _setBridgeTokenAllowance(_bridgeToken); 
                                                Bridge.redeemMax(AndSwapV2) [as token]
        3. _setBridgeTokenAllowance [as _bridgeToken] -> _setTokenAllowance(_bridgeToken)
        [4] _setTokenAllowance [as token] -> token.allowance(); token.approve()

            Summary on token functions:
    1. allowance: Bridge, BridgeRouter
    2. approve: BridgeRouter
    3. burnFrom: Bridge
    4. mint: Vault

*/
abstract contract MintBurnWrapper is AccessControl, IMintBurnWrapper {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    mapping(address => mapping(address => uint256)) private _allowances;

    /// @notice address of native (underlying) token
    address public immutable tokenNative;

    constructor(
        string memory _name,
        string memory _symbol,
        address _tokenNative,
        address _adminAddress
    ) {
        name = _name;
        symbol = _symbol;
        decimals = IERC20Decimals(_tokenNative).decimals();
        tokenNative = _tokenNative;
        _grantRole(DEFAULT_ADMIN_ROLE, _adminAddress);
    }

    /**
        @notice Get maximum amount of native tokens `spender` can burn from `spender` 
        via {burnFrom}.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
        @notice Sets `amount` as maximum amount of tokens `spender` can burn from caller.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    /**
        @notice Returns the `account` balance of native tokens. This is required for 
        external validation of {mint} and {burnFrom}, as well as for getting the max amount of 
        native tokens can be burnt via {burnFrom}.
     */
    function balanceOf(address account)
        external
        view
        virtual
        returns (uint256)
    {
        return IERC20(tokenNative).balanceOf(account);
    }

    /**
        @notice Burns native tokens from `account`, within the approved allowance.
        @dev Only Bridge is able to call this function (see the list of interactions above).
        This, and the requirement for approving, makes it impossible to call {burnFrom} without bridging the tokens.
     */
    function burnFrom(address account, uint256 amount)
        external
        onlyRole(BRIDGE_ROLE)
    {
        require(
            _allowances[account][msg.sender] >= amount,
            "Can't burn more than allowance"
        );
        _allowances[account][msg.sender] -= amount;
        uint256 balanceBefore = IERC20(tokenNative).balanceOf(account);

        _burnFrom(account, amount);

        uint256 balanceAfter = IERC20(tokenNative).balanceOf(account);
        // Verify the burn, so Bridge doesn't have to trust burn implementation
        require(balanceBefore == amount + balanceAfter, "Burn is incomplete");
    }

    /**
        @notice Mints native tokens to account.
        @dev Only Vault is able to call this function (see the list of interactions above).
        This makes it impossible to mint tokens without having valid proof of bridging (see Vault).
     */
    function mint(address to, uint256 amount) external onlyRole(VAULT_ROLE) {
        uint256 balanceBefore = IERC20(tokenNative).balanceOf(to);

        _mint(to, amount);

        uint256 balanceAfter = IERC20(tokenNative).balanceOf(to);
        // Verify the burn, so Vault doesn't have to trust mint implementation
        require(balanceBefore + amount == balanceAfter, "Mint is incomplete");
    }

    /**
        @notice Sends native tokens from caller to account.
        @dev Only Router is supposed to call this function (see the list of interactions above).
        This makes sure only following Router swaps with {MintBurnToken} are possible:
        1. BridgeRouter.selfSwap(), using {MintBurnToken} as initial token: takes care of 
        "bridge into {tokenNative} and swap" transactions.
        2. BridgeRouter.swapAndBridge() using {MintBurnToken} as final token: takes care of
        "swap into {tokenNative} and bridge" transactions.
        3. Router.swap() using {MintBurnToken} as final token: this will do exactly the same as
        Router.swap() using {tokenNative} as final token, while spending some extra gas. This is why
        UI is supposed to use {MintBurnToken} instead of {tokenNative} only for cross-chain swaps.

        The absence of {transferFrom} makes it impossible to do Router.swap() using {MintBurnToken}
        as initial token. It will also not be used as intermediate token for swapping, provided {MintBurnToken}
        is not set as "trusted token" on {Quoter}.
     */
    function transfer(address to, uint256 amount)
        external
        onlyRole(ROUTER_ROLE)
    {
        uint256 balanceBefore = IERC20(tokenNative).balanceOf(to);
        _transfer(to, amount);

        uint256 balanceAfter = IERC20(tokenNative).balanceOf(to);
        require(
            balanceBefore + amount == balanceAfter,
            "Transfer is incomplete"
        );
    }

    /// @dev This should burn native token from account.
    /// Will only be called by Bridge
    function _burnFrom(address account, uint256 amount) internal virtual;

    /// @dev This should mint native token to account.
    /// Will only be called by Vault
    function _mint(address to, uint256 amount) internal virtual;

    /// @dev This should transfer native token from caller to account.
    /// Will only be called by Router, set up infinite allowance, if needed.
    function _transfer(address to, uint256 amount) internal virtual;
}
