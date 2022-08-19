// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable-4.5.0/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "./helpers/CrystalFeesUpgradeable.sol";

import {Auction} from "./types/AuctionTypes.sol";

/// INTERFACES ///
// import "../ILandCore.sol";

/// @title AuctionBase for non-fungible tokens.
/// @notice We omit a fallback function to prevent accidental sends to this contract.
abstract contract ERC721AuctionBaseUpgradeable is
    PausableUpgradeable,
    AccessControlUpgradeable,
    CrystalFeesUpgradeable,
    IERC721ReceiverUpgradeable
{
    /// ROLES ///
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant BIDDER_ROLE = keccak256("BIDDER_ROLE");

    /// CONTRACTS ///
    // Reference to contract tracking NFT ownership
    IERC721Upgradeable public ERC721;

    /// STATE ///
    // Cut owner takes on each auction, measured in basis points (1/100 of a percent).
    // Values 0-10,000 map to 0%-100%
    uint256 public ownerCut;

    mapping(uint256 => Auction) public auctions;

    // Map from token ID to their corresponding auction.
    mapping(uint256 => uint256) tokenIdToAuction;
    mapping(address => uint256[]) public userAuctions;
    mapping(uint256 => uint256) auctionAtIndex;

    uint256 public auctionIdOffset;
    uint256 public totalAuctions;

    /// EVENTS ///
    event AuctionCreated(
        uint256 auctionId,
        address indexed owner,
        uint256 indexed tokenId,
        uint256 startingPrice,
        uint256 endingPrice,
        uint256 duration,
        address winner
    );
    event AuctionSuccessful(uint256 auctionId, uint256 indexed tokenId, uint256 totalPrice, address winner);
    event AuctionCancelled(uint256 auctionId, uint256 indexed tokenId);

    function __ERC721AuctionBaseUpgradeable_init(
        address _ERC721Address,
        address _crystalAddress,
        uint256 _cut,
        uint256 _auctionIdOffset
    ) internal onlyInitializing {
        __CrystalFeesUpgradeable_init(_crystalAddress);
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MODERATOR_ROLE, msg.sender);

        require(_cut <= 10000);
        ownerCut = _cut;

        ERC721 = IERC721Upgradeable(_ERC721Address);

        Auction memory auction = Auction({
            seller: address(this),
            tokenId: 0,
            startingPrice: 0,
            endingPrice: 0,
            duration: 0,
            startedAt: 0,
            winner: address(0),
            open: false
        });
        auctions[0] = auction;

        auctionIdOffset = _auctionIdOffset;
        totalAuctions = 1;
    }

    /////////////////////
    /// @dev ABSTRACT ///
    /////////////////////

    /// @dev Creates and begins a new auction. This can either escrow or not depending on implementation
    /// but should at the very least call _addAuction and check ownership
    /// @param _tokenId - ID of token to auction, sender must be owner.
    /// @param _startingPrice - Price of item (in wei) at beginning of auction.
    /// @param _endingPrice - Price of item (in wei) at end of auction.
    /// @param _duration - Length of auction (in seconds).
    /// @param _winner - The person who can win, if private. 0 for anyone.
    function createAuction(
        uint256 _tokenId,
        uint128 _startingPrice,
        uint128 _endingPrice,
        uint64 _duration,
        address _winner
    ) external virtual;

    /// @dev Bids on an open auction, completing the auction if enough JEWELs are supplied.
    /// @param _tokenId - ID of token to bid on.
    /// @param _bidAmount The bid amount.
    function bid(uint256 _tokenId, uint256 _bidAmount) public virtual;

    /// @dev Cancels an auction that hasn't been won yet.
    ///  Returns the NFT to original owner.
    /// @notice This is a state-modifying function that can
    ///  be called while the contract is paused.
    /// @notice depending on if the auction is escrow or not this might need to verify ownership
    /// @param _tokenId - ID of token on auction
    function cancelAuction(uint256 _tokenId) external virtual;

    /////////////////
    /// @dev CORE ///
    /////////////////

    /// @dev Bids on an open auction, completing the auction if enough JEWELs are supplied.
    /// @param _tokenId - ID of token to bid on.
    /// @param _bidAmount The bid amount.
    function bidFor(
        address _bidder,
        uint256 _tokenId,
        uint256 _bidAmount
    ) public virtual whenNotPaused onlyRole(BIDDER_ROLE) {
        // _bid will throw if the bid or funds transfer fails
        _bid(_bidder, _tokenId, _bidAmount);
    }

    /////////////////
    /// @dev VIEW ///
    /////////////////

    /// @dev Checks if the token is currently on auction.
    function isOnAuction(uint256 _tokenId) public view returns (bool) {
        Auction storage auction = auctions[tokenIdToAuction[_tokenId]];
        return _isOnAuction(auction);
    }

    /// @dev Returns auction info for an NFT on auction.
    /// @param _tokenId - ID of NFT on auction.
    function getAuction(uint256 _tokenId) public view returns (Auction memory) {
        require(tokenIdToAuction[_tokenId] != 0, "Auction does not exist");
        uint256 _auctionId = tokenIdToAuction[_tokenId];
        Auction storage auction = auctions[_auctionId];
        require(_isOnAuction(auction));
        return auction;
    }

    /// @dev single endpoint gets an array of auctions
    function getAuctions(uint256[] memory _tokenIds) public view returns (Auction[] memory) {
        Auction[] memory auctionsArr = new Auction[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            auctionsArr[i] = getAuction(_tokenIds[i]);
        }
        return auctionsArr;
    }

    /// @dev Returns the current price of an auction.
    /// @param _tokenId - ID of the token price we are checking.
    function getCurrentPrice(uint256 _tokenId) public view returns (uint256) {
        Auction storage auction = auctions[tokenIdToAuction[_tokenId]];
        require(_isOnAuction(auction));
        return _currentPrice(auction);
    }

    /// @dev returns the accounts auctions
    function getUserAuctions(address _address) public view returns (uint256[] memory) {
        return userAuctions[_address];
    }

    /////////////////////
    /// @dev INTERNAL ///
    /////////////////////

    /// @dev Escrows the NFT, assigning ownership to this contract.
    /// Throws if the escrow fails.
    /// @param _owner - Current owner address of token to escrow.
    /// @param _tokenId - ID of token whose approval to verify.
    function _escrow(address _owner, uint256 _tokenId) internal {
        // it will throw if transfer fails
        ERC721.safeTransferFrom(_owner, address(this), _tokenId);
    }

    /// @dev Transfers an NFT owned by this contract to another address.
    /// Returns true if the transfer succeeds.
    /// @param _receiver - Address to transfer NFT to.
    /// @param _tokenId - ID of token to transfer.
    function _transfer(address _receiver, uint256 _tokenId) internal {
        // it will throw if transfer fails
        ERC721.safeTransferFrom(address(this), _receiver, _tokenId);
    }

    /// @dev Adds an auction to the list of open auctions. Also fires the
    ///  AuctionCreated event.
    /// @param _tokenId The ID of the token to be put on auction.
    /// @param _auction Auction to add.
    function _addAuction(uint256 _tokenId, Auction memory _auction) internal {
        // Require that all auctions have a duration of
        // at least one minute. (Keeps our math from getting hairy!)
        require(_auction.duration >= 1 minutes, "duration");

        // Enforce prices are not 0
        require(_auction.startingPrice > 0 && _auction.endingPrice > 0, "cannot auction for 0");

        // Make sure it's not already on auction.
        require(tokenIdToAuction[_tokenId] == 0, "already on auction");

        uint256 auctionId = auctionIdOffset + totalAuctions;
        totalAuctions += 1;

        auctions[auctionId] = _auction;

        tokenIdToAuction[_tokenId] = auctionId;

        auctionAtIndex[_tokenId] = userAuctions[msg.sender].length;
        userAuctions[msg.sender].push(_tokenId);

        emit AuctionCreated(
            auctionId,
            msg.sender,
            uint256(_tokenId),
            uint256(_auction.startingPrice),
            uint256(_auction.endingPrice),
            uint256(_auction.duration),
            _auction.winner
        );
    }

    /// @dev Cancels an auction unconditionally.
    function _cancelAuction(
        uint256 _auctionId,
        uint256 _tokenId,
        address _seller
    ) internal {
        _removeAuction(_seller, _auctionId, _tokenId);
        emit AuctionCancelled(_auctionId, _tokenId);
    }

    /// @dev Computes the price and transfers winnings.
    /// Does NOT transfer ownership of token.
    function _bid(
        address _bidder,
        uint256 _tokenId,
        uint256 _bidAmount
    ) internal returns (uint256) {
        // Get a reference to the auction struct
        uint256 auctionId = tokenIdToAuction[_tokenId];

        if (auctionId == 0) {
            revert("Not on auction");
        }

        Auction storage auction = auctions[auctionId];

        // Explicitly check that this auction is currently live.
        require(_isOnAuction(auction), "Not on auction.");

        // Make sure the auction is open.
        require(auction.open, "Auction closed");

        // Check that the bid is greater than or equal to the current price
        uint256 price = _currentPrice(auction);
        require(_bidAmount >= price, "Bid too low");

        // If this is a private sale, make sure it only allows the address given.
        require(auction.winner == address(0) || auction.winner == _bidder, "private");

        // The bid is good! Remove the auction before sending the fees
        // to the sender so we can't have a reentrancy attack.
        _removeAuction(auction.seller, auctionId, _tokenId);

        // Transfer proceeds to owner (if there are any!)
        if (price > 0) {
            // Calculate the auctioneer's cut.
            // (NOTE: _computeCut() is guaranteed to return a
            // value <= price, so this subtraction can't go negative.)
            uint256 auctioneerCut = _computeCut(price);
            uint256 sellerProceeds = price - auctioneerCut;

            // Transfer the JEWELs to the ERC721 owner, minus the fee.
            crystalToken.transferFrom(_bidder, auction.seller, sellerProceeds);

            // Distribute the fee to the various addresses.
            distributeCrystals(_bidder, auctioneerCut);
        }

        emit AuctionSuccessful(auctionId, _tokenId, price, _bidder);

        return price;
    }

    /// @dev Returns true if the NFT is on auction.
    /// @param _auction - Auction to check.
    function _isOnAuction(Auction storage _auction) internal view returns (bool) {
        return (_auction.startedAt > 0 && _auction.open);
    }

    /// @dev Returns current price of an NFT on auction. Broken into two
    ///  functions (this one, that computes the duration from the auction
    ///  structure, and the other that does the price computation) so we
    ///  can easily test that the price computation works correctly.
    function _currentPrice(Auction storage _auction) internal view returns (uint256) {
        uint256 secondsPassed = 0;

        // A bit of insurance against negative values (or wraparound).
        // Probably not necessary (since Ethereum guarnatees that the
        // now variable doesn't ever go backwards).
        if (block.timestamp > _auction.startedAt) {
            secondsPassed = block.timestamp - _auction.startedAt;
        }

        return _computeCurrentPrice(_auction.startingPrice, _auction.endingPrice, _auction.duration, secondsPassed);
    }

    /// @dev Computes the current price of an auction. Factored out
    ///  from _currentPrice so we can run extensive unit tests.
    ///  When testing, make this function public and turn on
    ///  `Current price computation` test suite.
    function _computeCurrentPrice(
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration,
        uint256 _secondsPassed
    ) internal pure returns (uint256) {
        // NOTE: We don't use SafeMath (or similar) in this function because
        //  all of our public functions carefully cap the maximum values for
        //  time (at 64-bits) and currency (at 128-bits). _duration is
        //  also known to be non-zero (see the require() statement in
        //  _addAuction())
        if (_secondsPassed >= _duration) {
            // We've reached the end of the dynamic pricing portion
            // of the auction, just return the end price.
            return _endingPrice;
        } else {
            // Starting price can be higher than ending price (and often is!), so
            // this delta can be negative.
            int256 totalPriceChange = int256(_endingPrice) - int256(_startingPrice);

            // This multiplication can't overflow, _secondsPassed will easily fit within
            // 64-bits, and totalPriceChange will easily fit within 128-bits, their product
            // will always fit within 256-bits.
            int256 currentPriceChange = (totalPriceChange * int256(_secondsPassed)) / int256(_duration);

            // currentPriceChange can be negative, but if so, will have a magnitude
            // less that _startingPrice. Thus, this result will always end up positive.
            int256 currentPrice = int256(_startingPrice) + currentPriceChange;

            return uint256(currentPrice);
        }
    }

    /// @dev Computes owner's cut of a sale.
    /// @param _price - Sale price of NFT.
    function _computeCut(uint256 _price) internal view returns (uint256) {
        // NOTE: We don't use SafeMath (or similar) in this function because
        //  all of our entry functions carefully cap the maximum values for
        //  currency (at 128-bits), and ownerCut <= 10000 (see the require()
        //  statement in the Auction constructor). The result of this
        //  function is always guaranteed to be <= _price.
        return (_price * ownerCut) / 10000;
    }

    function _removeAuction(
        address _account,
        uint256 _auctionId,
        uint256 _tokenId
    ) internal {
        // We need to delete the item from the array for the user.
        // Get the current index of that item.
        uint256 currentIndex = auctionAtIndex[_tokenId];

        // Put the last item in the array at that index.
        userAuctions[_account][currentIndex] = userAuctions[_account][userAuctions[_account].length - 1];

        // Remove the last element from the array.
        userAuctions[_account].pop();

        // Update the crystalAtIndex record for that crystal that was moved.
        if (userAuctions[_account].length > currentIndex) {
            auctionAtIndex[userAuctions[_account][currentIndex]] = currentIndex;
        }

        delete tokenIdToAuction[_tokenId];

        Auction storage auction = auctions[_auctionId];
        auction.open = false;
    }

    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    //////////////////
    /// @dev ADMIN ///
    //////////////////

    /// @dev Sets the addresses and percentages that will receive fees.
    /// @param _feeAddresses An array of addresses to send fees to.
    /// @param _feePercents An array of percentages for the addresses to get.
    function setFees(address[] memory _feeAddresses, uint256[] memory _feePercents) public override onlyRole(MODERATOR_ROLE) {
        _setFees(_feeAddresses, _feePercents);
    }

    /// @dev Cancels an auction when the contract is paused.
    ///  Only the owner may do this, and NFTs are returned to
    ///  the seller. This should only be used in emergencies.
    /// @param _tokenId - ID of the NFT on auction to cancel.
    function cancelAuctionWhenPaused(uint256 _tokenId) external whenPaused onlyRole(MODERATOR_ROLE) {
        uint256 auctionId = tokenIdToAuction[_tokenId];
        Auction storage auction = auctions[auctionId];
        require(_isOnAuction(auction));
        _cancelAuction(auctionId, _tokenId, auction.seller);
    }

    function pause() public whenNotPaused onlyRole(MODERATOR_ROLE) {
        _pause();
    }

    function unpause() public whenPaused onlyRole(MODERATOR_ROLE) {
        _unpause();
    }
}
