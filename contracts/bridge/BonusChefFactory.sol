// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {IMiniChefV2} from "./interfaces/IMiniChefV2.sol";
import {BonusChef} from "./BonusChef.sol";

// BonusChefFactory wraps bonus chef to facilitate deployment of new bonus chef contracts
contract BonusChefFactory {
    event BonusChefCreated(address tokenAddress);

    /// @notice deploys a new bonus chef contract
    function deploy(
        IMiniChefV2 miniChef,
        uint256 chefPoolID,
        address rewardsDistribution,
        address governance
    ) external returns (address) {
        BonusChef chef = new BonusChef(
            miniChef,
            chefPoolID,
            rewardsDistribution,
            governance
        );

        emit BonusChefCreated(address(chef));
        return address(chef);
    }
}
