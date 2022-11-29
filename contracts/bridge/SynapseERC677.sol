// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./SynapseERC20.sol";

interface IERC677Receiver {
    function onTokenTransfer(
        address _sender,
        uint256 _value,
        bytes calldata _data
    ) external;
}

contract SynapseERC677 is SynapseERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);

    /**
     * @dev transfer token to a contract address with additional data if the recipient is a contact.
     * Note: data will not be passed to the recipient, if this was called from the recipient's constructor.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     * @param _data The extra data to be passed to the receiving contract.
     */
    function transferAndCall(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (bool success) {
        super.transfer(_to, _value);
        emit Transfer(msg.sender, _to, _value, _data);
        if (_isContract(_to)) {
            // Fallback will NOT be triggered, if this is called from `_to` constructor
            _contractFallback(_to, _value, _data);
        }
        return true;
    }

    // PRIVATE

    function _contractFallback(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) private {
        IERC677Receiver(_to).onTokenTransfer(msg.sender, _value, _data);
    }

    function _isContract(address _addr) private view returns (bool hasCode) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.
        uint256 length;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            length := extcodesize(_addr)
        }
        return length > 0;
    }
}
