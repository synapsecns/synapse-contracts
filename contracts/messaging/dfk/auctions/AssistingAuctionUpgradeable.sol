// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721AuctionBaseUpgradeable.sol";

/// @title Reverse auction modified for assisting
/// @notice We omit a fallback function to prevent accidental sends to this contract.
contract AssistingAuctionUpgradeable is ERC721AuctionBaseUpgradeable {
    function initialize(
        address _heroCoreAddress,
        address _crystalAddress,
        uint256 _cut,
        uint256 _auctionIdOffset
    ) public initializer {
        __ERC721AuctionBaseUpgradeable_init(_heroCoreAddress, _crystalAddress, _cut, _auctionIdOffset);
    }

    function createAuction(
        uint256 _tokenId,
        uint128 _startingPrice,
        uint128 _endingPrice,
        uint64 _duration,
        address _winner
    ) external override {
        // Make sure they actually own the hero.
        require(ERC721.ownerOf(_tokenId) == msg.sender, "Must own the hero");

        Auction memory auction = Auction(msg.sender, _tokenId, _startingPrice, _endingPrice, _duration, uint64(block.timestamp), _winner, true);

        _addAuction(_tokenId, auction);
    }

    function bid(uint256, uint256) public view override whenNotPaused {
        revert("cannot bid on assisting auction");
    }

    function cancelAuction(uint256 _tokenId) external override {
        uint256 auctionId = tokenIdToAuction[_tokenId];
        Auction storage auction = auctions[auctionId];

        require(_isOnAuction(auction), "not on auction");
        require(msg.sender == ERC721.ownerOf(_tokenId) || msg.sender == auction.seller, "not owner or seller");

        _cancelAuction(auctionId, _tokenId, auction.seller);
    }
}
