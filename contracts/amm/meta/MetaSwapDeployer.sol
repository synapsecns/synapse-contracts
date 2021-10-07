// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../interfaces/ISwap.sol";
import "../interfaces/IMetaSwap.sol";
import "../interfaces/IMetaSwapDeposit.sol";

/**
 * @title MetaSwapDeployer
 * @notice A library to be used to permissionlessly deploy Metapools.
 */

contract MetaSwapDeployer is Ownable {
    event NewMetaSwapPool(
        address indexed deployer,
        address metaSwapAddress,
        address metaSwapDepositAddress
    );

    struct MetaSwapPoolInfo {
        address metaSwapAddress;
        address metaSwapDepositAddress;
    }

    MetaSwapPoolInfo[] public metaSwapPoolInfo;
    address public metaSwapAddress;
    address public metaSwapDepositAddress;

    constructor(address _swapAddress, address _swapDepositAddress)
        public
        Ownable()
    {
        metaSwapAddress = _swapAddress;
        metaSwapDepositAddress = _swapDepositAddress;
    }

    function metaSwapPoolLength() external view returns (uint256) {
        return metaSwapPoolInfo.length;
    }

    function deploy(
        IERC20[] memory _pooledTokens,
        uint8[] memory decimals,
        string memory lpTokenName,
        string memory lpTokenSymbol,
        uint256 _a,
        uint256 _fee,
        uint256 _adminFee,
        address lpTokenTargetAddress,
        address baseSwap
    ) external returns (address) {
        address metaSwapClone = Clones.clone(metaSwapAddress);
        address metaSwapDepositClone = Clones.clone(metaSwapDepositAddress);
        IMetaSwap(metaSwapClone).initializeMetaSwap(
            _pooledTokens,
            decimals,
            lpTokenName,
            lpTokenSymbol,
            _a,
            _fee,
            _adminFee,
            lpTokenTargetAddress,
            baseSwap
        );
        (, , , , , , address lpToken) = IMetaSwap(metaSwapClone).swapStorage();

        IMetaSwapDeposit(metaSwapDepositClone).initialize(
            ISwap(baseSwap),
            IMetaSwap(metaSwapClone),
            IERC20(lpToken)
        );
        Ownable(metaSwapClone).transferOwnership(owner());
        metaSwapPoolInfo.push(
            MetaSwapPoolInfo({
                metaSwapAddress: metaSwapClone,
                metaSwapDepositAddress: metaSwapDepositClone
            })
        );
        emit NewMetaSwapPool(msg.sender, metaSwapClone, metaSwapDepositClone);
        return metaSwapClone;
    }
}
