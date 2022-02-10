// SPDX-License-Identifier: ISC

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import {IMiniChefV2} from "./interfaces/IMiniChefV2.sol";
import "./BonusChef.sol";


// BonusChefFactory wraps bonus chef to faciliate deployment of new bonus chef contracts
contract BonusChefFactory {
    using SafeMath for uint256;

    event BonusChefCreated(address tokenAddress);

    // @notice deploys a new bonus chef contract
    function deploy(
        IMiniChefV2 miniChef,
        uint256 chefPoolID,
        address rewardsDistribution
    ) external returns (address) {
        BonusChef chef = new BonusChef(
            miniChef,
            chefPoolID,
            rewardsDistribution,
            msg.sender
        );

        emit BonusChefCreated(address(chef));
        return address(chef);
    }
}