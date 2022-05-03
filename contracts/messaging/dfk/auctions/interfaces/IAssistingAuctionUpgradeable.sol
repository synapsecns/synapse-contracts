// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAssistingAuctionUpgradeable {
    function bid(uint256 _tokenId, uint256 _bidAmount) external;

    function bidFor(
        address _bidder,
        uint256 _tokenId,
        uint256 _bidAmount
    ) external;

    function cancelAuction(uint256 _tokenId) external;

    function cancelAuctionWhenPaused(uint256 _tokenId) external;

    function isOnAuction(uint256 _tokenId) external returns (bool);

    function createAuction(
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration
    ) external;

    function getAuction(uint256 _tokenId)
        external
        view
        returns (
            address seller,
            uint256 startingPrice,
            uint256 endingPrice,
            uint256 duration,
            uint256 startedAt
        );

    function getCurrentPrice(uint256 _tokenId) external view returns (uint256);

    function heroCore() external view returns (address);

    function jewelToken() external view returns (address);

    function owner() external view returns (address);

    function ownerCut() external view returns (uint256);

    function paused() external view returns (bool);

    function renounceOwnership() external;

    function setFees(address[] memory _feeAddresses, uint256[] memory _feePercents) external;

    function transferOwnership(address newOwner) external;
}
