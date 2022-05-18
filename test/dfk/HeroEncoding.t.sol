pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../contracts/messaging/dfk/types/HeroTypes.sol";

contract HeroEncodingTest is Test {
    function testHeroStruct() public {
        Hero memory heroStruct = Hero({
            id: 1000,
            info: HeroInfo({
                statGenes: 1001,
                visualGenes: 1002,
                rarity: Rarity.COMMON,
                shiny: true,
                generation: 1003,
                firstName: 1004,
                lastName: 1005,
                shinyStyle: 1,
                class: 1,
                subClass: 1
            }),
            state: HeroState({
                level: 1009,
                xp: 1010,
                currentQuest: address(0),
                staminaFullAt: 1011,
                hpFullAt: 1012,
                mpFullAt: 1013,
                sp: 1,
                status: HeroStatus.OK
            }),
            summoningInfo: SummoningInfo({
                summonedTime: 1015,
                nextSummonTime: 1016,
                summonerId: 1017,
                assistantId: 1018,
                summons: 1019,
                maxSummons: 1020
            }),
            stats: HeroStats({
                strength: 1021,
                agility: 1022,
                intelligence: 1023,
                wisdom: 1024,
                luck: 1025,
                vitality: 1026,
                endurance: 1027,
                dexterity: 1028,
                hp: 1029,
                mp: 1030,
                stamina: 1031
            }),
            primaryStatGrowth: HeroStatGrowth({
                strength: 1032,
                agility: 1033,
                intelligence: 1034,
                wisdom: 1035,
                luck: 1036,
                vitality: 1037,
                endurance: 1038,
                dexterity: 1039,
                hpSm: 1040,
                hpRg: 1041,
                hpLg: 1042,
                mpSm: 1043,
                mpRg: 1044,
                mpLg: 1045
            }),
            secondaryStatGrowth: HeroStatGrowth({
                strength: 1046,
                agility: 1047,
                intelligence: 1048,
                wisdom: 1049,
                luck: 1050,
                vitality: 1051,
                endurance: 1052,
                dexterity: 1053,
                hpSm: 1054,
                hpRg: 1055,
                hpLg: 1056,
                mpSm: 1057,
                mpRg: 1058,
                mpLg: 1059
            }),
            professions: HeroProfessions({
                mining: 1060,
                gardening: 1061,
                foraging: 1062,
                fishing: 1063
            })
        });
        bytes memory heroBytes = abi.encode(heroStruct);
        console.logBytes(heroBytes);
        Hero memory decodedHero = abi.decode(heroBytes, (Hero));
        console.log(decodedHero.id);
    }
}
