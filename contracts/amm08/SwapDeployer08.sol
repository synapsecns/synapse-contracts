// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import "@openzeppelin/contracts-4.5.0/proxy/Clones.sol";
import "./interfaces/ISwap08.sol";

contract SwapDeployer08 is Ownable {
    event NewSwapPool(address indexed deployer, address swapAddress, IERC20[] pooledTokens);

    constructor() Ownable() {
        this;
    }

    function deploy(
        address swapAddress,
        IERC20[] memory _pooledTokens,
        uint8[] memory decimals,
        string memory lpTokenName,
        string memory lpTokenSymbol,
        uint256 _a,
        uint256 _fee,
        uint256 _adminFee,
        address lpTokenTargetAddress
    ) external returns (address) {
        address swapClone = Clones.clone(swapAddress);
        ISwap08(swapClone).initialize(
            _pooledTokens,
            decimals,
            lpTokenName,
            lpTokenSymbol,
            _a,
            _fee,
            _adminFee,
            lpTokenTargetAddress
        );
        Ownable(swapClone).transferOwnership(owner());
        emit NewSwapPool(msg.sender, swapClone, _pooledTokens);
        return swapClone;
    }
}
