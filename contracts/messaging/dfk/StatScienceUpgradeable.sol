// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./random/IRandomGenerator.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/access/AccessControlUpgradeable.sol";

import "./libs/LibGeneScience.sol";
import "./IHeroCoreUpgradeable.sol";

import {Hero, HeroStats, HeroStatGrowth, HeroProfessions} from "./types/HeroTypes.sol";
import {HeroCrystal} from "./types/CrystalTypes.sol";
import {RandomInputs} from "./types/RandomTypes.sol";
import "./types/JobTiers.sol";

/// @title StatScience contains the logic to calculate starting stats.
/// @author Frisky Fox - Defi Kingdoms
contract StatScienceUpgradeable is AccessControlUpgradeable {
    /// CONTRACTS ///
    IRandomGenerator randomGenerator;

    /// ROLES ///
    bytes32 public constant WHITELIST_ROLE = keccak256("WHITELIST_ROLE");

    constructor(address _randomGeneratorAddress) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(WHITELIST_ROLE, msg.sender);

        randomGenerator = IRandomGenerator(_randomGeneratorAddress);
    }

    /// @dev Gets the job tier for genes.
    function getJobTier(uint8 _class) public pure returns (JobTier) {
        if (_class > 29) {
            return JobTier.TRANSCENDENT;
        }
        if (_class > 27) {
            return JobTier.EXALTED;
        }
        if (_class > 23) {
            return JobTier.ELITE;
        }
        if (_class > 15) {
            return JobTier.ADVANCED;
        }
        return JobTier.NORMAL;
    }

    function getGene(uint256 _genes, uint8 _position) public pure returns (uint8) {
        uint8[] memory statTraits = LibGeneScience.decode(_genes);
        return statTraits[_position];
    }

    function generateStats(
        uint256 _statGenes,
        HeroCrystal memory _crystal,
        Rarity _rarity,
        uint256 _crystalId
    ) external onlyRole(WHITELIST_ROLE) returns (HeroStats memory) {
        uint8[11][31] memory classBaseStats;

        classBaseStats[0] = [11, 5, 5, 7, 7, 9, 8, 8, 150, 25, 25]; // warrior
        classBaseStats[1] = [10, 5, 6, 7, 6, 10, 10, 6, 140, 35, 25]; // knight
        classBaseStats[2] = [7, 6, 7, 10, 10, 6, 6, 8, 135, 40, 25]; // thief
        classBaseStats[3] = [7, 7, 6, 8, 7, 6, 7, 12, 135, 40, 25]; // archer
        classBaseStats[4] = [5, 10, 13, 7, 6, 6, 7, 6, 110, 65, 25]; // priest
        classBaseStats[5] = [5, 12, 12, 7, 6, 6, 6, 6, 100, 75, 25]; // wizard
        classBaseStats[6] = [8, 6, 8, 6, 8, 8, 8, 8, 135, 40, 25]; // monk
        classBaseStats[7] = [9, 5, 5, 10, 7, 8, 7, 9, 145, 30, 25]; // pirate
        classBaseStats[16] = [10, 6, 10, 7, 6, 10, 10, 6, 160, 40, 25]; // paladin
        classBaseStats[17] = [14, 8, 6, 6, 6, 11, 7, 7, 150, 50, 25]; // darkknight
        classBaseStats[18] = [6, 14, 12, 7, 7, 6, 6, 7, 120, 80, 25]; // summoner
        classBaseStats[19] = [7, 7, 6, 10, 12, 7, 6, 10, 140, 60, 25]; // ninja
        classBaseStats[24] = [11, 7, 9, 8, 8, 8, 10, 9, 175, 50, 25]; // dragoon
        classBaseStats[25] = [6, 15, 15, 7, 8, 7, 6, 6, 125, 100, 25]; // sage
        classBaseStats[28] = [15, 8, 8, 7, 8, 10, 11, 8, 200, 50, 25]; // dreadknight

        uint8 class = getGene(_statGenes, 44); // Class is at position 44.
        HeroStats memory heroStats = HeroStats({
            strength: classBaseStats[class][0],
            intelligence: classBaseStats[class][1],
            wisdom: classBaseStats[class][2],
            luck: classBaseStats[class][3],
            agility: classBaseStats[class][4],
            vitality: classBaseStats[class][5],
            endurance: classBaseStats[class][6],
            dexterity: classBaseStats[class][7],
            hp: classBaseStats[class][8],
            mp: classBaseStats[class][9],
            stamina: classBaseStats[class][10]
        });

        // Augment with the statboost genes.
        uint8 statBonusGene = getGene(_statGenes, 16); // Stat bonus gene is at position 16.
        if (statBonusGene == 0) {
            heroStats.strength = heroStats.strength + 2;
        }
        if (statBonusGene == 2) {
            heroStats.agility = heroStats.agility + 2;
        }
        if (statBonusGene == 4) {
            heroStats.intelligence = heroStats.intelligence + 2;
        }
        if (statBonusGene == 6) {
            heroStats.wisdom = heroStats.wisdom + 2;
        }
        if (statBonusGene == 8) {
            heroStats.luck = heroStats.luck + 2;
        }
        if (statBonusGene == 10) {
            heroStats.vitality = heroStats.vitality + 2;
        }
        if (statBonusGene == 12) {
            heroStats.endurance = heroStats.endurance + 2;
        }
        if (statBonusGene == 14) {
            heroStats.dexterity = heroStats.dexterity + 2;
        }

        // Add Rarity
        (heroStats, ) = addRarityBonus(heroStats, _rarity, _crystal, _crystalId);

        // Augment with tears.
        heroStats = _augmentStatTears(heroStats, _crystal);

        // TODO Augment with bonus item.

        return heroStats;
    }

    function _addMutualExclusiveStatBonuses(
        HeroStats memory _heroStats,
        uint8[8] memory _statsIncreased,
        uint8 _numStats,
        uint8 _boostAmount,
        HeroCrystal memory _crystal,
        uint256 _crystalId
    ) internal returns (HeroStats memory, uint8[8] memory) {
        uint8[8] memory statsArray = [0, 1, 2, 3, 4, 5, 6, 7];
        for (uint256 i = 0; i < _numStats; i++) {
            // Choose a random index between 0 and 7 - i so that it decreases each time it runs.
            uint256 randomIndex = IRandomGenerator(randomGenerator).getRandom(
                RandomInputs(0, (7 - i), _crystal.createdBlock, 5, _crystalId)
            );

            // Grab the stat from the random index.
            uint8 randomStat = statsArray[randomIndex];

            // Take the stat at the end of the limit and swap it with this one.
            statsArray[randomIndex] = statsArray[7 - i];

            // Increase the stat by the boost amount.
            _heroStats = augmentStat(_heroStats, randomStat, _boostAmount);
            _statsIncreased[randomStat] += _boostAmount;
        }

        return (_heroStats, _statsIncreased);
    }

    function addRarityBonus(
        HeroStats memory _heroStats,
        Rarity _rarity,
        HeroCrystal memory _crystal,
        uint256 _crystalId
    ) public onlyRole(WHITELIST_ROLE) returns (HeroStats memory, uint8[8] memory) {
        uint8[8] memory statsIncreased;
        if (_rarity == Rarity.MYTHIC) {
            // +2 to three random, mutually exclusive stats
            (_heroStats, statsIncreased) = _addMutualExclusiveStatBonuses(
                _heroStats,
                statsIncreased,
                3,
                2,
                _crystal,
                _crystalId
            );
            // then +1 to three random, mutually exclusive stats
            (_heroStats, statsIncreased) = _addMutualExclusiveStatBonuses(
                _heroStats,
                statsIncreased,
                3,
                1,
                _crystal,
                _crystalId
            );
            // then +1 to a random stat.
            (_heroStats, statsIncreased) = _addMutualExclusiveStatBonuses(
                _heroStats,
                statsIncreased,
                1,
                1,
                _crystal,
                _crystalId
            );
        } else if (_rarity == Rarity.LEGENDARY) {
            // +2 to one random stat,
            (_heroStats, statsIncreased) = _addMutualExclusiveStatBonuses(
                _heroStats,
                statsIncreased,
                1,
                2,
                _crystal,
                _crystalId
            );
            // then +1 to three random, mutually exclusive stats
            (_heroStats, statsIncreased) = _addMutualExclusiveStatBonuses(
                _heroStats,
                statsIncreased,
                3,
                1,
                _crystal,
                _crystalId
            );
            // then an additional +1 to two random stat, mutually exclusive stats.
            (_heroStats, statsIncreased) = _addMutualExclusiveStatBonuses(
                _heroStats,
                statsIncreased,
                2,
                1,
                _crystal,
                _crystalId
            );
        } else if (_rarity == Rarity.RARE) {
            // +1 to three random, mutually exclusive stats
            (_heroStats, statsIncreased) = _addMutualExclusiveStatBonuses(
                _heroStats,
                statsIncreased,
                3,
                1,
                _crystal,
                _crystalId
            );
            // then an additional +1 to a random stat (including any stats that received a bonus already)
            (_heroStats, statsIncreased) = _addMutualExclusiveStatBonuses(
                _heroStats,
                statsIncreased,
                1,
                1,
                _crystal,
                _crystalId
            );
        } else if (_rarity == Rarity.UNCOMMON) {
            // +1 to two random, mutually exclusive stats
            (_heroStats, statsIncreased) = _addMutualExclusiveStatBonuses(
                _heroStats,
                statsIncreased,
                2,
                1,
                _crystal,
                _crystalId
            );
        }

        return (_heroStats, statsIncreased);
    }

    function _augmentStatTears(
        HeroStats memory _stats,
        HeroCrystal memory /*_crystal*/
    ) internal pure returns (HeroStats memory) {
        // TODO - Augment the stats based on the tears from each parent.
        // To do this effectively, we need to load both parents.
        // Hero memory summoner = heroCore.getHero(_crystal.summonerId);
        // Hero memory assistant = heroCore.getHero(_crystal.assistantId);

        // Get the bonus for each parent based on their tears and job level.

        /*

        Each parent can provide bonuses to the Stats, PrimeStatUp, and SubStatUp arrays. 
        Bonuses are based on the level of each parent and the amount of Gaia’s Tears used to make the summoning egg. 
        Players can spend +10 Gaia’s Tears for each step of 5 levels each hero has reached.
        The Gaia’s tear bonuses follow a specific alternating pattern, and loop back to the beginning from the end:

        +(1 + loopCount) to stat matching highest parent stat
        +(1 + loopCount)% to primary stat increase rate of highest parent stat
        +(2 + loopCount)% to secondary stat increase rate of highest parent stat
        +(1 + loopCount) to stat matching second highest parent stat
        +(1 + loopCount)% to primary stat increase rate of second highest parent stat
        +(2 + loopCount)% to secondary stat increase rate of second highest parent stat
        +(1 + loopCount) to stat matching third highest parent stat
        +(1 + loopCount)% to primary stat increase rate of third highest parent stat
        +(2 + loopCount)% to secondary stat increase rate of third highest parent stat

        */

        return _stats;
    }

    function augmentStat(
        HeroStats memory _stats,
        uint256 _stat,
        uint8 _increase
    ) public pure returns (HeroStats memory) {
        if (_stat == 0) {
            _stats.strength = _stats.strength + _increase;
        } else if (_stat == 1) {
            _stats.agility = _stats.agility + _increase;
        } else if (_stat == 2) {
            _stats.intelligence = _stats.intelligence + _increase;
        } else if (_stat == 3) {
            _stats.wisdom = _stats.wisdom + _increase;
        } else if (_stat == 4) {
            _stats.luck = _stats.luck + _increase;
        } else if (_stat == 5) {
            _stats.vitality = _stats.vitality + _increase;
        } else if (_stat == 6) {
            _stats.endurance = _stats.endurance + _increase;
        } else if (_stat == 7) {
            _stats.dexterity = _stats.dexterity + _increase;
        } else if (_stat == 8) {
            _stats.hp = _stats.hp + _increase;
        } else if (_stat == 9) {
            _stats.mp = _stats.mp + _increase;
        } else if (_stat == 10) {
            _stats.stamina = _stats.stamina + _increase;
        }
        return _stats;
    }

    function generateStatGrowth(
        uint256 _statGenes,
        HeroCrystal memory, /*_crystal*/
        Rarity, /*_rarity*/
        bool _isPrimary
    ) external pure returns (HeroStatGrowth memory) {
        uint16[14][31] memory classStatGrowth;

        classStatGrowth[0] = [7500, 2000, 2000, 3500, 5000, 6500, 6500, 7000, 1500, 4000, 4500, 5000, 3500, 1500]; // warrior
        classStatGrowth[1] = [7000, 2000, 2500, 3500, 4500, 7500, 7500, 5500, 1500, 3500, 5000, 4000, 4000, 2000]; // knight
        classStatGrowth[2] = [5500, 2500, 3500, 6500, 7000, 5000, 4500, 5500, 2500, 5000, 2500, 3000, 4000, 3000]; // thief
        classStatGrowth[3] = [5500, 4000, 2500, 4000, 5000, 5000, 6000, 8000, 2500, 5000, 2500, 3000, 4000, 3000]; // archer
        classStatGrowth[4] = [3000, 7000, 8000, 4000, 4000, 5000, 6000, 3000, 3500, 4000, 2500, 1500, 3500, 5000]; // priest
        classStatGrowth[5] = [3000, 8000, 8000, 4000, 4000, 5000, 5000, 3000, 3500, 4000, 2500, 1500, 3500, 5000]; // wizard
        classStatGrowth[6] = [6000, 2500, 5000, 3000, 6000, 6000, 5500, 6000, 2500, 3500, 4000, 3000, 4000, 3000]; // monk
        classStatGrowth[7] = [7000, 2000, 2000, 5500, 5000, 6000, 5500, 7000, 1500, 4500, 4000, 4500, 4000, 1500]; // pirate
        classStatGrowth[16] = [8000, 3000, 6500, 4000, 3500, 8000, 8000, 4000, 1000, 4000, 5000, 2500, 4000, 3500]; // paladin
        classStatGrowth[17] = [8500, 7000, 3500, 3500, 3500, 7500, 6000, 5500, 2000, 5500, 2500, 2000, 4000, 4000]; // darkknight
        classStatGrowth[18] = [4500, 8500, 8500, 4000, 5000, 5000, 5000, 4500, 4000, 4000, 2000, 1500, 3500, 5000]; // summoner
        classStatGrowth[19] = [5000, 5000, 4000, 6000, 8500, 5000, 4000, 7500, 2500, 5000, 2500, 2500, 5000, 2500]; // ninja
        classStatGrowth[24] = [8000, 5000, 6000, 5000, 6500, 6000, 7000, 6500, 1500, 3500, 5000, 3500, 4500, 2000]; // dragoon
        classStatGrowth[25] = [4000, 9000, 9000, 5500, 7500, 6000, 5000, 4000, 4000, 3500, 2500, 1000, 3000, 6000]; // sage
        classStatGrowth[28] = [8500, 6500, 6500, 6000, 6000, 6500, 7500, 7500, 1000, 4000, 5000, 2500, 5000, 2500]; // dreadknight

        // TODO - Augment this with the tears from each parent, as well as their growthstats.

        /*

        Each parent can provide bonuses to the Stats, PrimeStatUp, and SubStatUp arrays. 
        Bonuses are based on the level of each parent and the amount of Gaia’s Tears used to make the summoning egg. 
        Players can spend +10 Gaia’s Tears for each step of 5 levels each hero has reached.
        The Gaia’s tear bonuses follow a specific alternating pattern, and loop back to the beginning from the end:

        +(1 + loopCount) to stat matching highest parent stat
        +(1 + loopCount)% to primary stat increase rate of highest parent stat
        +(2 + loopCount)% to secondary stat increase rate of highest parent stat
        +(1 + loopCount) to stat matching second highest parent stat
        +(1 + loopCount)% to primary stat increase rate of second highest parent stat
        +(2 + loopCount)% to secondary stat increase rate of second highest parent stat
        +(1 + loopCount) to stat matching third highest parent stat
        +(1 + loopCount)% to primary stat increase rate of third highest parent stat
        +(2 + loopCount)% to secondary stat increase rate of third highest parent stat

        */

        uint8 class;

        if (_isPrimary) {
            class = getGene(_statGenes, 44); // Class is position 44
        } else {
            class = getGene(_statGenes, 40); // Subclass is position 40
        }

        HeroStatGrowth memory statGrowth = HeroStatGrowth({
            strength: classStatGrowth[class][0],
            intelligence: classStatGrowth[class][1],
            wisdom: classStatGrowth[class][2],
            luck: classStatGrowth[class][3],
            agility: classStatGrowth[class][4],
            vitality: classStatGrowth[class][5],
            endurance: classStatGrowth[class][6],
            dexterity: classStatGrowth[class][7],
            hpSm: classStatGrowth[class][8],
            hpRg: classStatGrowth[class][9],
            hpLg: classStatGrowth[class][10],
            mpSm: classStatGrowth[class][11],
            mpRg: classStatGrowth[class][12],
            mpLg: classStatGrowth[class][13]
        });

        // If this is for secondary, go through and divide each stat by 4.
        if (!_isPrimary) {
            statGrowth.strength = statGrowth.strength / 4;
            statGrowth.intelligence = statGrowth.intelligence / 4;
            statGrowth.wisdom = statGrowth.wisdom / 4;
            statGrowth.luck = statGrowth.luck / 4;
            statGrowth.agility = statGrowth.agility / 4;
            statGrowth.vitality = statGrowth.vitality / 4;
            statGrowth.endurance = statGrowth.endurance / 4;
            statGrowth.dexterity = statGrowth.dexterity / 4;
            statGrowth.hpSm = statGrowth.hpSm / 4;
            statGrowth.hpRg = statGrowth.hpRg / 4;
            statGrowth.hpLg = statGrowth.hpLg / 4;
            statGrowth.mpSm = statGrowth.mpSm / 4;
            statGrowth.mpRg = statGrowth.mpRg / 4;
            statGrowth.mpLg = statGrowth.mpLg / 4;
        }

        // Augment this with the stat boost genes.
        uint16 boostAmount = 200;

        if (!_isPrimary) {
            boostAmount = 400;
        }

        uint8 statBoostGene = getGene(_statGenes, 12); // Stat boost gene is at position 12.
        if (statBoostGene == 0) {
            statGrowth.strength = statGrowth.strength + boostAmount;
        }
        if (statBoostGene == 2) {
            statGrowth.agility = statGrowth.agility + boostAmount;
        }
        if (statBoostGene == 4) {
            statGrowth.intelligence = statGrowth.intelligence + boostAmount;
        }
        if (statBoostGene == 6) {
            statGrowth.wisdom = statGrowth.wisdom + boostAmount;
        }
        if (statBoostGene == 8) {
            statGrowth.luck = statGrowth.luck + boostAmount;
        }
        if (statBoostGene == 10) {
            statGrowth.vitality = statGrowth.vitality + boostAmount;
        }
        if (statBoostGene == 12) {
            statGrowth.endurance = statGrowth.endurance + boostAmount;
        }
        if (statBoostGene == 14) {
            statGrowth.dexterity = statGrowth.dexterity + boostAmount;
        }

        return statGrowth;
    }
}
