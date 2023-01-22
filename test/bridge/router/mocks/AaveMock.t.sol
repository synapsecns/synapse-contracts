// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../../../../contracts/amm/AaveSwapWrapper.sol";

interface BurnMintToken {
    function burnFrom(address to, uint256 amount) external;

    function mint(address to, uint256 amount) external;
}

contract LendingPoolMock is ILendingPool {
    using SafeERC20 for IERC20;

    mapping(address => address) internal underlyingTokenMap;
    mapping(address => address) internal aTokenMap;

    function addToken(address _aToken, address _underlyingToken) external {
        underlyingTokenMap[_aToken] = _underlyingToken;
        aTokenMap[_underlyingToken] = _aToken;
    }

    /**
     * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * - E.g. User deposits 100 USDC and gets in return 100 aUSDC
     * @param asset The address of the underlying asset to deposit
     * @param amount The amount to be deposited
     * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     **/
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16
    ) external override {
        address aToken = aTokenMap[asset];
        require(aToken != address(0), "Unknown asset");
        IERC20(asset).safeTransferFrom(onBehalfOf, address(this), amount);
        BurnMintToken(aToken).mint(onBehalfOf, amount);
    }

    /**
     * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
     * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
     * @param asset The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @param to Address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @return The final amount withdrawn
     **/
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external override returns (uint256) {
        address aToken = aTokenMap[asset];
        require(aToken != address(0), "Unknown asset");
        uint256 amountOut = amount == type(uint256).max ? IERC20(aToken).balanceOf(msg.sender) : amount;
        BurnMintToken(aToken).burnFrom(msg.sender, amountOut);
        IERC20(asset).safeTransfer(to, amountOut);
    }
}
