// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Hero, HeroInfo, HeroState, HeroStats, HeroStatGrowth, SummoningInfo, HeroProfessions, Rarity} from "./types/HeroTypes.sol";

import {HeroCrystal} from "./types/CrystalTypes.sol";
import {JobTier} from "./types/JobTiers.sol";

interface IStatScienceUpgradeable {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function WHITELIST_ROLE() external view returns (bytes32);

    function augmentStat(
        HeroStats memory _stats,
        uint256 _stat,
        uint8 _increase
    ) external pure returns (HeroStats memory);

    function generateStatGrowth(
        uint256 _statGenes,
        HeroCrystal memory, /*_crystal*/
        Rarity, /*_rarity*/
        bool _isPrimary
    ) external pure returns (HeroStatGrowth memory);

    function generateStats(
        uint256 _statGenes,
        HeroCrystal memory _crystal,
        Rarity _rarity,
        uint256 _crystalId
    ) external returns (HeroStats memory);

    function getGene(uint256 _genes, uint8 _position) external pure returns (uint8);

    function getJobTier(uint8 _class) external pure returns (JobTier);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

    function renounceRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
