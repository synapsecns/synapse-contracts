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

contract ERC677Token is SynapseERC20 {
    
    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);
    /**
     * @dev transfer token to a contract address with additional data if the recipient is a contact.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     * @param _data The extra data to be passed to the receiving contract.
     */
    function transferAndCall(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) public returns (bool success) {
        super.transfer(_to, _value);
        emit Transfer(msg.sender, _to, _value, _data);
        if (isContract(_to)) {
            contractFallback(_to, _value, _data);
        }
        return true;
    }

    // PRIVATE

    function contractFallback(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) private {
        IERC677Receiver(_to).onTokenTransfer(msg.sender, _value, _data);
    }

    function isContract(address _addr) private returns (bool hasCode) {
        uint256 length;
        assembly {
            length := extcodesize(_addr)
        }
        return length > 0;
    }
}
