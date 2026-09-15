// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseERC20} from "../../../contracts/bridge/SynapseERC20.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract ReenteringToken is SynapseERC20 {
    address internal target;
    bytes internal data;

    function setReenteringData(address target_, bytes memory data_) public {
        target = target_;
        data = data_;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        super._transfer(sender, recipient, amount);
        _reenterTarget();
    }

    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);
        _reenterTarget();
    }

    function _reenterTarget() internal {
        if (target != address(0)) {
            address target_ = target;
            bytes memory data_ = data;
            delete target;
            delete data;
            Address.functionCall(target_, data_);
        }
    }
}
