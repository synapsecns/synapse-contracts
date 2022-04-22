// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Hero, HeroInfo, HeroState, SummoningInfo, HeroProfessions, Rarity} from "./types/HeroTypes.sol";
import {HeroCrystal} from "./types/CrystalTypes.sol";

interface IHeroCoreUpgradeable {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function MINTER_ROLE() external view returns (bytes32);

    function MODERATOR_ROLE() external view returns (bytes32);

    function PAUSER_ROLE() external view returns (bytes32);

    function STAMINA_ROLE() external view returns (bytes32);

    function HERO_MODERATOR_ROLE() external view returns (bytes32);

    function updateHero(Hero memory _hero) external;

    function approve(address to, uint256 tokenId) external;

    function assistingAuction() external view returns (address);

    function balanceOf(address owner) external view returns (uint256);

    function baseCooldown() external view returns (uint256);

    function baseSummonFee() external view returns (uint256);

    function burn(uint256 tokenId) external;

    function calculateSummoningCost(uint256 _heroId) external view returns (uint256);

    function cooldownPerGen() external view returns (uint256);

    function cooldownPerSummon() external view returns (uint256);

    function cooldowns(uint256) external view returns (uint32);

    function createAssistingAuction(
        uint256 _heroId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration
    ) external;

    function createHero(
        uint256 _statGenes,
        uint256 _visualGenes,
        Rarity _rarity,
        bool _shiny,
        HeroCrystal memory _crystal,
        uint256 _crystalId
    ) external returns (uint256);

    function createSaleAuction(
        uint256 _heroId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration
    ) external;

    function deductStamina(uint256 _heroId, uint256 _staminaDeduction) external;

    function extractNumber(
        uint256 randomNumber,
        uint256 digits,
        uint256 offset
    ) external pure returns (uint256 result);

    function geneScience() external view returns (address);

    function getApproved(uint256 tokenId) external view returns (address);

    function getCurrentStamina(uint256 _heroId) external view returns (uint256);

    function getHero(uint256 _id) external view returns (Hero memory);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    function getRoleMemberCount(bytes32 role) external view returns (uint256);

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

    function increasePerGen() external view returns (uint256);

    function increasePerSummon() external view returns (uint256);

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) external;

    function initialize(address _crystalAddress) external;

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function isReadyToSummon(uint256 _heroId) external view returns (bool);

    function crystalToken() external view returns (address);

    function mint(address to) external;

    function name() external view returns (string memory);

    function openCrystal(uint256 _crystalId) external returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function pause() external;

    function paused() external view returns (bool);

    function renounceRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) external;

    function saleAuction() external view returns (address);

    function setApprovalForAll(address operator, bool approved) external;

    function setAssistingAuctionAddress(address _address) external;

    function setFees(address[] memory _feeAddresses, uint256[] memory _feePercents) external;

    function setSaleAuctionAddress(address _address) external;

    function setSummonCooldowns(
        uint256 _baseCooldown,
        uint256 _cooldownPerSummon,
        uint256 _cooldownPerGen
    ) external;

    function setSummonFees(
        uint256 _baseSummonFee,
        uint256 _increasePerSummon,
        uint256 _increasePerGen
    ) external;

    function setTimePerStamina(uint256 _timePerStamina) external;

    function summonCrystal(
        uint256 _summonerId,
        uint256 _assistantId,
        uint8 _summonerTears,
        uint8 _assistantTears,
        address _enhancementStone
    ) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function timePerStamina() external view returns (uint256);

    function tokenByIndex(uint256 index) external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function unpause() external;

    function vrf(uint256 blockNumber) external view returns (bytes32 result);
}
