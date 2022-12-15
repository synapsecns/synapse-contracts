// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct PriceTier {
    uint8 jewelCost;
    uint16 goldCost;
    uint8 tearCost;
    uint32 incubationTime;
    uint16 shinyChance;
}

struct EggTypeCost {
    address eggAddress;
    address itemAddress1;
    uint16 itemAmount1;
    address itemAddress2;
    uint16 itemAmount2;
}

struct Pet {
    uint256 id;
    uint8 originId;
    string name;
    uint8 season;
    uint8 eggType; // 0 = blue, 1 = grey, 2 = green, 3 = yellow, 4 = gold
    uint8 rarity;
    uint8 element;
    uint8 bonusCount;
    uint8 profBonus;
    uint8 profBonusScalar;
    uint8 craftBonus;
    uint8 craftBonusScalar;
    uint8 combatBonus;
    uint8 combatBonusScalar;
    uint16 appearance;
    uint8 background;
    uint8 shiny;
    uint64 hungryAt;
    uint64 equippableAt;
    uint256 equippedTo;
}

struct PetOptions {
    uint8 originId;
    string name;
    uint8 season;
    uint8 eggType;
    uint8 rarity;
    uint8 element;
    uint8 bonusCount;
    uint8 profBonus;
    uint8 profBonusScalar;
    uint8 craftBonus;
    uint8 craftBonusScalar;
    uint8 combatBonus;
    uint8 combatBonusScalar;
    uint16 appearance;
    uint8 background;
    uint8 shiny;
}

struct UnhatchedEgg {
    uint256 id;
    uint256 petId;
    address owner;
    uint8 eggType;
    uint256 seedblock;
    uint256 finishTime;
    uint8 tier; // 0 = Small, 1 = Medium, 2 = Large
}

struct PetExchangeData {
    uint256 id;
    address owner;
    uint256 petId1;
    uint256 petId2;
    uint256 seedblock;
    uint256 finishTime;
    PetExchangeStatus status;
}

enum PetExchangeStatus {
    NONE,
    STARTED,
    COMPLETED
}
