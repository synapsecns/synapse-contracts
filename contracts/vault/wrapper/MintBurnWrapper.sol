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

    Here's the list of all contracts that will be interacting with MintBurnWrapper
    1. Bridge
            Direct calls:
        1. balanceOf() in _getMaxAmount()
        2. allowance() in _getMaxAmount()
        3. balanceOf() in _burnFromSender() 
        4. burnFrom() in _burnFromSender()

            Passing as a parameter:
        1. Vault.mintToken() [as token] in _mint()
        2. BridgeRouter.selfSwap() [as path[0]] in _handleSwap()
        3. BridgeRouter.refundToAddress() [as token] in _handleSwap()
    2. Vault
            Direct calls:
        1. mint() in mintToken()

            Passing as a parameter:
        None
    3. BridgeRouter
            Direct calls:
        1. allowance() in _setBridgeTokenAllowance()
        2. approve() in _setBridgeTokenAllowance()

            Passing as a parameter:
        1. Router._swap() [as path[N-1]] in swapAndBridge()
        2. Router._selfSwap() [as path[N-1]] in swapFromGasAndBridge()
        3. Bridge.redeemMax|Bridge.redeemMaxAndSwapV2 [as token] in _callBridge()
        4. BasicRouter._returnTokensTo() [as _token] in refundToAddress()
        5. Router._selfSwap() [as path[0]] in selfSwap()
        
    4. Router
            Direct calls:
        1. transfer() in _selfSwap() [when passed as path[0]]
    
            Passing as a parameter:
        1. Adapter.swap() [as tokenIn|tokenOut] in _doChainedSwaps()
    
    5. BasicRouter
            Direct calls:
        1. transfer() in _returnTokensTo()
    
    6. Adapter
        A specialized Adapter must be implemented that will be actually swapping native token,
        while stating a support for MintBurnWrapper swaps. No calls to this contract,
        rather than tokenNative() must be made
 */
abstract contract MintBurnWrapper is AccessControl, IMintBurnWrapper {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    mapping(address => mapping(address => uint256)) private _allowances;

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

    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function balanceOf(address account)
        external
        view
        virtual
        returns (uint256)
    {
        return IERC20(tokenNative).balanceOf(account);
    }

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
        require(balanceBefore == amount + balanceAfter, "Burn is incomplete");
    }

    function mint(address to, uint256 amount) external onlyRole(VAULT_ROLE) {
        uint256 balanceBefore = IERC20(tokenNative).balanceOf(to);

        _mint(to, amount);

        uint256 balanceAfter = IERC20(tokenNative).balanceOf(to);
        require(balanceBefore + amount == balanceAfter, "Mint is incomplete");
    }

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
