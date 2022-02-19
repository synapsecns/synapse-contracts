// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Adapter} from "../../Adapter.sol";
import {ICurvePool} from "../../interfaces/ICurvePool.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

abstract contract CurveAbstractAdapter is Adapter {
    ICurvePool public pool;

    constructor(
        string memory _name,
        address _pool,
        uint256 _swapGasEstimate
    ) Adapter(_name, _swapGasEstimate) {
        pool = ICurvePool(_pool);
        _setPoolTokens();
    }

    function _setPoolTokens() internal virtual {
        for (uint8 i = 0; true; i++) {
            try pool.coins(i) returns (address _tokenAddress) {
                _addPoolToken(_tokenAddress, i);
            } catch {
                break;
            }
        }
    }

    function _addPoolToken(address _tokenAddress, uint8 _index)
        internal
        virtual;

	function _approveIfNeeded(address _tokenIn, uint256 _amount)
        internal
        virtual
        override
    {
        _checkAllowance(IERC20(_tokenIn), _amount, address(pool));
    }

    function _depositAddress(address, address)
        internal
        view
        virtual
        override
        returns (address)
    {
        return address(this);
    }
}
