// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ITokenMinter {
    /**
     * @notice Get the local token associated with the given remote domain and token.
     * @param remoteDomain Remote domain
     * @param remoteToken Remote token
     * @return local token address
     */
    function getLocalToken(uint32 remoteDomain, bytes32 remoteToken) external view returns (address);
}
