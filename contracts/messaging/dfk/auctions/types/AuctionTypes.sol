// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct Auction {
    // Current owner of NFT
    address seller;
    uint256 tokenId;
    // Price (in wei) at beginning of auction
    uint128 startingPrice;
    // Price (in wei) at end of auction
    uint128 endingPrice;
    // Duration (in seconds) of auction
    uint64 duration;
    // Time when auction started
    // NOTE: 0 if this auction has been concluded
    uint64 startedAt;
    // If the winner is set from the start, that means it is a private auction.
    address winner;
    bool open;
}
