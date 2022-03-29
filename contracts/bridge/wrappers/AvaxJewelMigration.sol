// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/ISynapseBridge.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract AvaxJewelMigration is Ownable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Mintable;

    ISynapseBridge public constant SYNAPSE_BRIDGE =
        ISynapseBridge(0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE);
    // MULTICHAIN JEWEL
    IERC20 public constant LEGACY_TOKEN =
        IERC20(0x4f60a160D8C2DDdaAfe16FCC57566dB84D674BD6);
    // SYNAPSE JEWEL
    IERC20Mintable public constant NEW_TOKEN =
        IERC20Mintable(0x997Ddaa07d716995DE90577C123Db411584E5E46);
    uint256 private constant MAX_UINT256 = 2**256 - 1;

    constructor() public {
        NEW_TOKEN.safeApprove(address(SYNAPSE_BRIDGE), MAX_UINT256);
    }

    function migrate(uint256 amount) external {
        _migrate(amount, msg.sender);
    }

    function migrateAndBridge(
        uint256 amount,
        address to,
        uint256 chainId
    ) external {
        // First, mint new tokens to this contract, as Bridge burns tokens
        // from msg.sender, which would be AvaxJewelMigration
        _migrate(amount, address(this));
        // Initiate bridging and specify `to` as receiver on destination chain
        SYNAPSE_BRIDGE.redeem(to, chainId, NEW_TOKEN, amount);
    }

    /// @notice Pull old tokens from user and mint new ones to account
    function _migrate(uint256 amount, address account) internal {
        LEGACY_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        NEW_TOKEN.mint(account, amount);
    }

    function redeemLegacy() external onlyOwner {
        uint256 legacyBalance = LEGACY_TOKEN.balanceOf(address(this));
        LEGACY_TOKEN.safeTransfer(owner(), legacyBalance);
    }
}
