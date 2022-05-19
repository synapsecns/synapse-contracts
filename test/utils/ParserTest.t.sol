// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

contract ParserTest is Test {
    struct AdapterData {
        string contractName;
        bytes constructorParams;
        string[] tokens;
        bool isUnderquoting;
    }

    function testParse() public {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "scripts/adapters.js";
        inputs[2] = "1";
        inputs[3] = "test/adapters.json";
        bytes memory res = vm.ffi(inputs);

        bytes[] memory adapters = abi.decode(res, (bytes[]));
        for (uint256 i = 0; i < adapters.length; ++i) {
            (string memory _c, string memory name, bytes memory args, string[] memory tokens, bool underquote) = abi
            .decode(adapters[i], (string, string, bytes, string[], bool));

            emit log_string(_c);
            emit log_string(name);
            if (keccak256(bytes(_c)) == keccak256("UniswapV2Adapter")) {
                (string memory _name, uint256 _gas, address _factory, bytes32 _hash, uint256 _fee) = abi.decode(
                    args,
                    (string, uint256, address, bytes32, uint256)
                );
                emit log_named_string("Name", _name);
                emit log_named_uint("Gas", _gas);
                emit log_named_address("Factory", _factory);
                emit log_named_bytes32("Hash", _hash);
                emit log_named_uint("Fee", _fee);
            } else {
                emit log_bytes(args);
            }

            emit log_named_uint("Length", tokens.length);
            for (uint256 j = 0; j < tokens.length; ++j) {
                emit log_string(tokens[j]);
            }
            emit log_string(underquote ? "True" : "False");
        }
    }
}
