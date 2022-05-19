// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/ISynapseBridge.sol";
import "../interfaces/IERC20Migrator.sol";

contract MigratorBridgeZap {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    ISynapseBridge constant synapseBridge = ISynapseBridge(0xd123f70AE324d34A9E76b67a27bf77593bA8749f);
    IERC20Migrator constant erc20Migrator = IERC20Migrator(0xf0284FB86adA5E4D82555C529677eEA3B2C3E022);
    IERC20 constant legacyToken = IERC20(0x42F6f551ae042cBe50C739158b4f0CAC0Edb9096);
    IERC20 constant newToken = IERC20(0xa4080f1778e69467E905B8d6F72f6e441f9e9484);
    uint256 constant MAX_UINT256 = 2**256 - 1;

    constructor() public {
        legacyToken.safeApprove(address(erc20Migrator), MAX_UINT256);
        newToken.safeApprove(address(synapseBridge), MAX_UINT256);
    }

    function migrate(uint256 amount) external {
        legacyToken.safeTransferFrom(msg.sender, address(this), amount);
        erc20Migrator.migrate(amount);
        newToken.safeTransfer(msg.sender, amount.mul(5).div(2));
    }

    function migrateAndBridge(
        uint256 amount,
        address to,
        uint256 chainId
    ) external {
        legacyToken.safeTransferFrom(msg.sender, address(this), amount);
        erc20Migrator.migrate(amount);
        synapseBridge.redeem(to, chainId, newToken, amount.mul(5).div(2));
    }
}
