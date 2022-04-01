// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import {MintBurnWrapper} from "./MintBurnWrapper.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

contract DepositBridgeWrapper is MintBurnWrapper {
    using SafeERC20 for IERC20;

    constructor(
        address _bridge,
        address _vault,
        string memory _name,
        string memory _symbol,
        address _depositToken
    ) MintBurnWrapper(_bridge, _vault, _name, _symbol, _depositToken) {
        this;
    }

    /**
        @dev burnFrom is called when bridging via redeem-like function on Bridge
        Full support for bridging using BridgeRouter can be achieved by doing 
        BridgeRouter.setInfiniteTokenAllowance(depositToken, DepositBridgeWrapper)
        Users willing to bridge via Bridge directly (but why?) will need to pre-approve 
        DepositBridgeWrapper to spend their depositToken
     */
    function _burnFrom(address account, uint256 amount)
        internal
        virtual
        override
    {
        IERC20(tokenNative).safeTransferFrom(account, address(this), amount);
    }

    function _mint(address to, uint256 amount) internal virtual override {
        IERC20(tokenNative).safeTransfer(to, amount);
    }
}
