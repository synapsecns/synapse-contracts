// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import {DeployerUtils} from "./DeployerUtils.sol";

abstract contract BaseScript is DeployerUtils {
    /// @notice Execute the script, which will be broadcasted.
    function run() external {
        execute(true);
    }

    /// @notice Execute the script, which won't be broadcasted.
    function runDry() external {
        execute(false);
    }

    /// @notice Logic for executing the script
    function execute(bool isBroadcasted) public virtual;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              LOAD CHAIN                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Loads chain name using block.chainid from the local deployments.
    /// @dev Will revert if current chainid is not saved.
    function loadChain() public {
        loadChain(_chainId());
    }

    /// @notice Loads chain name with matching chainId from the local deployments.
    /// @dev Will revert if chainid is not saved.
    function loadChain(uint256 chainId) public {
        require(chainId != 0, "Incorrect chainId");
        (bytes[] memory chains, uint256[] memory chainIds) = loadChains();
        string memory _chain = "";
        for (uint256 i = 0; i < chainIds.length; ++i) {
            if (chainIds[i] == chainId) {
                require(bytes(_chain).length == 0, "Multiple matching chains found");
                _chain = string(chains[i]);
                // To make sure there's only one matching chain we don't return chain right away,
                // instead we check every chain in "./deployments"
            }
        }
        setupChain(_chain);
    }

    /// @notice Loads all chains from the local deployments, alongside with their chainId.
    /// If chainId is not saved, the default zero value will be returned
    function loadChains() public returns (bytes[] memory chains, uint256[] memory chainIds) {
        string[] memory inputs = new string[](2);
        inputs[0] = "ls";
        inputs[1] = _deploymentsPath();
        bytes memory res = vm.ffi(inputs);
        chains = _splitString(abi.encodePacked(res, NEWLINE));
        uint256 amount = chains.length;
        chainIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            chainIds[i] = _loadChainId(string(chains[i]));
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Wrapper for block.chainid, which is not directly accessible in 0.6.12
    function _chainId() internal view returns (uint256 chainId) {
        // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        this;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
    }

    /// @dev Returns the chainId for the given chain
    /// Will return 0, if chainId is not saved in the deployments
    function _loadChainId(string memory _chain) internal returns (uint256 chainId) {
        string memory path = _concat(_deploymentsPath(), _chain, "/.chainId");
        try vm.readLine(path) returns (string memory str) {
            chainId = _strToInt(str);
            vm.closeFile(path);
        } catch {
            // Return 0 if .chainId doesn't exist
            chainId = 0;
        }
    }
}
