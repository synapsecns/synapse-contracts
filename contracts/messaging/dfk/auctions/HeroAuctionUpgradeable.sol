// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IAssistingAuctionUpgradeable.sol";
import "./ERC721AuctionBaseUpgradeable.sol";

/// @title Auction modified for sale of heroes
/// @notice We omit a fallback function to prevent accidental sends to this contract.
contract HeroAuctionUpgradeable is ERC721AuctionBaseUpgradeable {
    /// CONTRACTS ///
    IAssistingAuctionUpgradeable public assistingAuction; // TODO this makes its underlying contract non upgradeable. any way we can do without this?

    function initialize(
        address _heroCoreAddress,
        address _crystalAddress,
        uint256 _cut,
        address _assistingAuctionAddress,
        uint256 _auctionIdOffset
    ) public initializer {
        __ERC721AuctionBaseUpgradeable_init(_heroCoreAddress, _crystalAddress, _cut, _auctionIdOffset);
        assistingAuction = IAssistingAuctionUpgradeable(_assistingAuctionAddress);
    }

    /// @dev Creates and begins a new auction.
    /// @param _tokenId - ID of token to auction, sender must be owner.
    /// @param _startingPrice - Price of item (in wei) at beginning of auction.
    /// @param _endingPrice - Price of item (in wei) at end of auction.
    /// @param _duration - Length of auction (in seconds).
    function createAuction(
        uint256 _tokenId,
        uint128 _startingPrice,
        uint128 _endingPrice,
        uint64 _duration,
        address _winner
    ) external override {
        // Make sure they actually own the hero.
        require(ERC721.ownerOf(_tokenId) == msg.sender, "Must own the hero");

        // Cannot be on a hire auction.
        require(!assistingAuction.isOnAuction(_tokenId), "assisting");

        _escrow(msg.sender, _tokenId);
        Auction memory auction = Auction(msg.sender, _tokenId, _startingPrice, _endingPrice, _duration, uint64(block.timestamp), _winner, true);
        _addAuction(_tokenId, auction);
    }

    /// @dev Bids on an open auction, completing the auction and transferring
    ///  ownership of the NFT if enough CRYSTALs are supplied.
    /// @param _tokenId - ID of token to bid on.
    /// @param _bidAmount The bid amount.
    function bid(uint256 _tokenId, uint256 _bidAmount) public override whenNotPaused {
        // _bid will throw if the bid or funds transfer fails
        _bid(msg.sender, _tokenId, _bidAmount);
        _transfer(msg.sender, _tokenId);
    }

    /// @dev Cancels an auction that hasn't been won yet.
    ///  Returns the NFT to original owner.
    /// @notice This is a state-modifying function that can
    ///  be called while the contract is paused.
    /// @param _tokenId - ID of token on auction
    function cancelAuction(uint256 _tokenId) external override {
        uint256 auctionId = tokenIdToAuction[_tokenId];
        Auction storage auction = auctions[auctionId];

        require(_isOnAuction(auction), "not on auction");
        require(msg.sender == auction.seller, "not seller");

        _cancelAuction(auctionId, _tokenId, auction.seller);
        _transfer(auction.seller, _tokenId);
    }
}
