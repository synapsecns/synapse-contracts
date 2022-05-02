// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

enum HeroStatus {
    OK,
    KO
}

enum Rarity {
    COMMON,
    UNCOMMON,
    RARE,
    LEGENDARY,
    MYTHIC
}

struct HeroStats {
    uint16 strength;
    uint16 agility;
    uint16 intelligence;
    uint16 wisdom;
    uint16 luck;
    uint16 vitality;
    uint16 endurance;
    uint16 dexterity;
    uint16 hp;
    uint16 mp;
    uint16 stamina;
}

struct HeroStatGrowth {
    uint16 strength;
    uint16 agility;
    uint16 intelligence;
    uint16 wisdom;
    uint16 luck;
    uint16 vitality;
    uint16 endurance;
    uint16 dexterity;
    uint16 hpSm;
    uint16 hpRg;
    uint16 hpLg;
    uint16 mpSm;
    uint16 mpRg;
    uint16 mpLg;
}

struct SummoningInfo {
    uint256 summonedTime;
    // How long until the hero can participate in summoning again.
    uint256 nextSummonTime;
    uint256 summonerId;
    uint256 assistantId;
    // How many summons the hero has done.
    uint32 summons;
    // How many summons can the hero do max.
    uint32 maxSummons;
}

struct HeroInfo {
    uint256 statGenes;
    uint256 visualGenes;
    Rarity rarity;
    bool shiny;
    uint16 generation;
    uint32 firstName;
    uint32 lastName;
    uint8 shinyStyle;
    uint8 class;
    uint8 subClass;
}

struct HeroState {
    // The time the hero's stamina is full at.
    uint256 staminaFullAt;
    // The time the hero's hp is full at.
    uint256 hpFullAt;
    // The time the hero's mp is full at.
    uint256 mpFullAt;
    // The current level of the hero.
    uint16 level;
    // The current XP the hero has towards their next level.
    uint64 xp;
    // The current quest a hero is undertaking, if any.
    address currentQuest;
    // The skill points the hero can spend.
    uint8 sp;
    HeroStatus status;
}

struct HeroProfessions {
    uint16 mining;
    uint16 gardening;
    uint16 foraging;
    uint16 fishing;
}

/// @dev The main Hero struct.
struct Hero {
    uint256 id;
    SummoningInfo summoningInfo;
    HeroInfo info;
    HeroState state;
    HeroStats stats;
    HeroStatGrowth primaryStatGrowth;
    HeroStatGrowth secondaryStatGrowth;
    HeroProfessions professions;
}

