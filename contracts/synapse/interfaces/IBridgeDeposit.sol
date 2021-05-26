
pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface IBridgeDeposit {
    using SafeERC20 for IERC20;
    
    function deposit(address to, IERC20 token, uint256 amount);
}
