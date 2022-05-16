pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";

import "../../contracts/messaging/dfk/types/HeroTypes.sol";

import "../../contracts/messaging/dfk/bridge/HeroBridgeUpgradeable.sol";
import "../../contracts/messaging/dfk/random/RandomGenerator.sol";
import "../../contracts/messaging/dfk/auctions/AssistingAuctionUpgradeable.sol";
import "../../contracts/messaging/dfk/StatScienceUpgradeable.sol";
import "../../contracts/messaging/dfk/HeroCoreUpgradeable.sol";

import "../../contracts/messaging/MessageBus.sol";
import "../../contracts/messaging/GasFeePricing.sol";
import "../../contracts/messaging/AuthVerifier.sol";
import "../../contracts/messaging/apps/PingPong.sol";
import "../../contracts/messaging/AuthVerifier.sol";

contract HeroBridgeUpgradeableTest is Test {
    Utilities internal utils;
    address payable[] internal users;
    MessageBus public messageBusChainA;
    PingPong public pingPongChainA;
    GasFeePricing public gasFeePricingChainA;
    AuthVerifier public authVerifierChainA;
    HeroBridgeUpgradeable public HeroBridgeUpgradeableChainA;
    StatScienceUpgradeable public statScienceUpgradeableChainA;
    RandomGenerator public randomGeneratorChainA;
    HeroCoreUpgradeable public heroCoreUpgradeableChainA;
    AssistingAuctionUpgradeable public assistingAuctionUpgradeableChainA;
    Hero public heroStruct;
    address payable public node;

    struct MessageFormat {
        Hero dstHero;
        address dstUser;
        uint256 dstHeroId;
    }

    event MessageSent(
        address indexed sender,
        uint256 srcChainID,
        bytes32 receiver,
        uint256 indexed dstChainId,
        bytes message,
        uint64 nonce,
        bytes options,
        uint256 fee,
        bytes32 indexed messageId
    );

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function setUp() public {
        gasFeePricingChainA = new GasFeePricing();

        utils = new Utilities();
        users = utils.createUsers(10);
        node = users[0];
        vm.label(node, "Node");

        authVerifierChainA = new AuthVerifier(node);
        messageBusChainA = new MessageBus(
            address(gasFeePricingChainA),
            address(authVerifierChainA)
        );

        randomGeneratorChainA = new RandomGenerator();
        statScienceUpgradeableChainA = new StatScienceUpgradeable(
            address(randomGeneratorChainA)
        );
        heroCoreUpgradeableChainA = new HeroCoreUpgradeable();
        heroCoreUpgradeableChainA.initialize(
            "Heroes",
            "HERO",
            address(statScienceUpgradeableChainA)
        );
        heroCoreUpgradeableChainA.grantRole(
            keccak256("BRIDGE_ROLE"),
            address(this)
        );
        heroStruct = Hero({
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

        assistingAuctionUpgradeableChainA = new AssistingAuctionUpgradeable();
        HeroBridgeUpgradeableChainA = new HeroBridgeUpgradeable();
        HeroBridgeUpgradeableChainA.initialize(
            address(messageBusChainA),
            address(heroCoreUpgradeableChainA),
            address(assistingAuctionUpgradeableChainA)
        );
        HeroBridgeUpgradeableChainA.setMsgGasLimit(800000);
        heroCoreUpgradeableChainA.grantRole(
            keccak256("BRIDGE_ROLE"),
            address(HeroBridgeUpgradeableChainA)
        );
        heroCoreUpgradeableChainA.grantRole(
            keccak256("HERO_MODERATOR_ROLE"),
            address(HeroBridgeUpgradeableChainA)
        );
        gasFeePricingChainA.setCostPerChain(
            1666700000,
            2000000000,
            100000000000000000
        );
        HeroBridgeUpgradeableChainA.setTrustedRemote(
            1666700000,
            bytes32("trustedRemoteB")
        );
        HeroBridgeUpgradeableChainA.setTrustedRemote(
            335,
            bytes32("trustedRemoteA")
        );
    }

    function testHeroSendMessage() public {
        heroCoreUpgradeableChainA.bridgeMint(1000, users[1]);
        heroCoreUpgradeableChainA.updateHero(heroStruct);
        vm.startPrank(users[1]);
        heroCoreUpgradeableChainA.approve(
            address(HeroBridgeUpgradeableChainA),
            1000
        );
        // check first two topics, but don't check data or msgId
        vm.expectEmit(true, true, false, false);
        emit MessageSent(
            address(HeroBridgeUpgradeableChainA),
            block.chainid,
            bytes32("1337"),
            1666700000, // chain id
            "0x", // example possible message
            messageBusChainA.nonce(),
            "0x", // null
            100000000000000000,
            keccak256("placeholder_message_id")
        );
        HeroBridgeUpgradeableChainA.sendHero{value: 1000000000000000000}(
            1000,
            1666700000
        );
        // Hero locked into HeroBridgeUpgradeable contract now
        assertEq(
            heroCoreUpgradeableChainA.ownerOf(1000),
            address(HeroBridgeUpgradeableChainA)
        );
    }

    function testExecuteMessage() public {
        MessageFormat memory msgFormat = MessageFormat({
            dstHeroId: 1000,
            dstHero: heroStruct,
            dstUser: address(1337)
        });

        bytes memory message = abi.encode(msgFormat);
        vm.prank(address(messageBusChainA));
        HeroBridgeUpgradeableChainA.executeMessage(
            bytes32("trustedRemoteA"),
            335,
            message,
            msg.sender
        );
    }
}
