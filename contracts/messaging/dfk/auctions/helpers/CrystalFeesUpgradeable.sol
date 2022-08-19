// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// INTERFACES ///
// TEMPORARY: NOT PROD
import "@openzeppelin/contracts-upgradeable-4.5.0/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/proxy/utils/Initializable.sol";

/// @title CrystalFees
/// @author Frisky Fox - Defi Kingdoms
/// @dev Functionality that supports paying fees.
abstract contract CrystalFeesUpgradeable is Initializable {
    /// CONTRACTS ///
    IERC20Upgradeable public crystalToken;

    /// STATE ///
    address[] public feeAddresses;
    uint256[] public feePercents;

    function __CrystalFeesUpgradeable_init(address _crystalTokenAddress) internal onlyInitializing {
        crystalToken = IERC20Upgradeable(_crystalTokenAddress);
    }

    /// @dev Spends CRYSTALs and takes care to send them to the proper places.
    function distributeCrystals(address _from, uint256 _amount) internal {
        // Send percentages to different wallets.
        for (uint256 i = 0; i < feeAddresses.length; i++) {
            uint256 feeAmount = (feePercents[i] * _amount) / 10000;
            crystalToken.transferFrom(_from, feeAddresses[i], feeAmount);
        }
    }

    /// @dev Sets the addresses and percentages that will receive fees.
    /// @param _feeAddresses An array of addresses to send fees to.
    /// @param _feePercents An array of percentages for the addresses to get.
    function _setFees(address[] memory _feeAddresses, uint256[] memory _feePercents) internal {
        // Make sure the length of the two arrays match.
        require(_feeAddresses.length == _feePercents.length, "length mismatch");

        // Make sure the percentages all add up to 10000.
        uint256 total = 0;
        for (uint256 i = 0; i < _feePercents.length; i++) {
            total = total + _feePercents[i];
        }

        require(total == 10000, "invalid fee amounts");

        // Set the fees.
        feePercents = _feePercents;
        feeAddresses = _feeAddresses;
    }

    function setFees(address[] memory _feeAddresses, uint256[] memory _feePercents) public virtual;
}