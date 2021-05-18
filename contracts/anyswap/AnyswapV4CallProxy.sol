// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.3;


contract AnyCallProxy {
    // configurable delay for timelock functions
    uint public delay = 2*24*3600;

    // primary controller of the token contract
    address public mpc;
    address public pendingMPC;
    uint public delayMPC;

    uint public pendingDelay;
    uint public delayDelay;

    modifier onlyMPC() {
        require(msg.sender == mpc, "AnyswapCallProxy: FORBIDDEN");
        _;
    }

    function setMPC(address _mpc) external onlyMPC {
        pendingMPC = _mpc;
        delayMPC = block.timestamp + delay;
        emit LogChangeMPC(mpc, pendingMPC, delayMPC);
    }

    function applyMPC() external {
        require(msg.sender == pendingMPC);
        require(block.timestamp >= delayMPC);
        mpc = pendingMPC;
    }

    event LogChangeMPC(address indexed oldMPC, address indexed newMPC, uint indexed effectiveTime);
    event LogAnyExec(address indexed from, address[] to, bytes[] data, bool[] success, bytes[] result, address[] callbacks, uint[] nonces, uint fromChainID, uint toChainID);
    event LogAnyCall(address indexed from, address[] to, bytes[] data, address[] callbacks, uint[] nonces, uint fromChainID, uint toChainID);

    function cID() public view returns (uint id) {
        assembly {id := chainid()}
    }

    constructor(address _mpc) {
        mpc = _mpc;
    }
    /*
        @notice Trigger a cross-chain contract interaction
        @param to - list of addresses to call
        @param data - list of data payloads to send / call
        @param callbacks - the callbacks on the fromChainID to call `callback(address to, bytes data, uint nonces, uint fromChainID, bool success, bytes result)`
        @param nonces - the nonces (ordering) to include for the resulting callback
        @param toChainID - the recipient chain that will receive the events
    */
    function anyCall(address[] memory to, bytes[] memory data, address[] memory callbacks, uint[] memory nonces, uint toChainID) external {
        emit LogAnyCall(msg.sender, to, data, callbacks, nonces, cID(), toChainID);
    }

    function anyCall(address from, address[] memory to, bytes[] memory data, address[] memory callbacks, uint[] memory nonces, uint fromChainID) external onlyMPC {
        bool[] memory success = new bool[](to.length);
        bytes[] memory results = new bytes[](to.length);
        for (uint i = 0; i < to.length; i++) {
            (success[i], results[i]) = to[i].call{value:0}(data[i]);
        }
        emit LogAnyExec(from, to, data, success, results, callbacks, nonces, fromChainID, cID());
    }

    function encode(string memory signature, bytes memory data) external pure returns (bytes memory) {
        return abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
    }

    function encodePermit(address target, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external pure returns (bytes memory) {
        return abi.encodeWithSignature("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)", target, spender, value, deadline, v, r, s);
    }

    function encodeTransferFrom(address sender, address recipient, uint256 amount) external pure returns (bytes memory) {
        return abi.encodeWithSignature("transferFrom(address,address,uint256)", sender, recipient, amount);
    }
}