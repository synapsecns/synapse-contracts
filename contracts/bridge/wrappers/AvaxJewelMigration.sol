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

    ISynapseBridge constant synapseBridge = ISynapseBridge(0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE);
    // MULTICHAIN JEWEL
    IERC20 constant legacyToken = IERC20(0x4f60a160D8C2DDdaAfe16FCC57566dB84D674BD6);
    // SYNAPSE JEWEL
    IERC20 constant newToken = IERC20(0x997Ddaa07d716995DE90577C123Db411584E5E46);
    uint256 constant MAX_UINT256 = 2**256 - 1;

    constructor() public {
        newToken.safeApprove(address(synapseBridge), MAX_UINT256);
    }

    function migrate(uint256 amount) public {
        legacyToken.safeTransferFrom(msg.sender, address(this), amount);
        IERC20Mintable(address(newToken)).mint(msg.sender, amount);
    }

    function migrateAndBridge(
        uint256 amount,
        address to,
        uint256 chainId
    ) external {
        migrate(amount);
        synapseBridge.redeem(to, chainId, newToken, amount);
    }

    function redeemLegacy() external onlyOwner {
        uint256 legacyBalance = legacyToken.balanceOf(address(this));
        legacyToken.safeTransfer(owner(), legacyBalance);
    }
}
