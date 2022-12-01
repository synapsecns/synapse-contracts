// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../interfaces/IWETH9.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WKlayUnwrapper is Ownable {
    using SafeERC20 for IERC20;

    IWETH9 public constant WKLAY = IWETH9(payable(0x5819b6af194A78511c79C85Ea68D2377a7e9335f));
    address public immutable bridge;

    /**
     * @notice Creates a contract to unwrap WKLAY. Sets governance address as the owner.
     * Governance functions are limited to rescuing the locked tokens/KLAY.
     */
    constructor(address _bridge, address governance) public {
        bridge = _bridge;
        transferOwnership(governance);
    }

    // Make sure this contract can receive gas
    receive() external payable {}

    /**
     * @notice This contract is not supposed to store any tokens. In the event
     * of any tokens or KLAY sent to this contract, they could be rescued by the governance.
     * @dev Can be only called by governance address
     * @param token     Token to rescue, use address(0) to rescue KLAY
     */
    function rescueToken(address token) external onlyOwner {
        if (token == address(0)) {
            // Rescue locked ether
            _transferKLAY(msg.sender, address(this).balance);
        } else {
            // Rescue locked token
            uint256 amount = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(msg.sender, amount);
        }
    }

    /**
     * @notice Unwraps WKLAY and transfers it to SynapseBridge
     * @dev Can be only called by SynapseBridge
     * @param amount    Transfer amount
     */
    function withdraw(uint256 amount) external {
        require(msg.sender == bridge, "!bridge");
        WKLAY.withdraw(amount);
        _transferKLAY(msg.sender, amount);
    }

    /// @notice Transfers KLAY to a specified address
    function _transferKLAY(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH_TRANSFER_FAILED");
    }
}
