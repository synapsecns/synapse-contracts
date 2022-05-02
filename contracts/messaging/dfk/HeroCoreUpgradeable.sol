// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable-4.5.0/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/access/AccessControlUpgradeable.sol";
import "./IStatScienceUpgradeable.sol";
import {HeroStatus} from "./types/HeroTypes.sol";
/// @title Core contract for Heroes.
/// @author Frisky Fox - Defi Kingdoms
/// @dev Holds the base structs, events, and data.
contract HeroCoreUpgradeable is ERC721EnumerableUpgradeable, PausableUpgradeable, AccessControlUpgradeable {
    /// ROLES ///
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant HERO_MODERATOR_ROLE = keccak256("HERO_MODERATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// STATE ///
    IStatScienceUpgradeable statScience;
    mapping(uint256 => Hero) public heroes;
    uint256 public nextHeroId;
    /// EVENTS ///
    /// @dev The HeroSummoned event is fired whenever a new hero is created.
    event HeroSummoned(address indexed owner, uint256 heroId, uint256 summonerId, uint256 assistantId, uint256 statGenes, uint256 visualGenes);
    /// @dev The HeroUpdated event is fired whenever a hero is updated.
    event HeroUpdated(address indexed owner, uint256 heroId, Hero hero);
    /// @dev The initialize function is the constructor for upgradeable contracts.
    function initialize(
        string memory _name,
        string memory _symbol,
        address _statScience
    ) public virtual initializer {
        __ERC721_init(_name, _symbol);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MODERATOR_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(HERO_MODERATOR_ROLE, msg.sender);
        statScience = IStatScienceUpgradeable(_statScience);
        nextHeroId = 1000000000001;
    }
    function _baseURI() internal pure override returns (string memory) {
        return "https://api.defikingdoms.com/";
    }
    function getUserHeroes(address _address) external view returns (Hero[] memory) {
        uint256 balance = balanceOf(_address);
        Hero[] memory heroArr = new Hero[](balance);
        for (uint256 i = 0; i < balance; i++) {
            heroArr[i] = getHero(tokenOfOwnerByIndex(_address, i));
        }
        return heroArr;
    }
    /// @dev Gets a hero object.
    /// @param _id The hero id.
    function getHero(uint256 _id) public view returns (Hero memory) {
        return heroes[_id];
    }
    /// @dev Creates Heroes with the given settings.
    /// @param _statGenes the encoded genes for the hero stats.
    /// @param _visualGenes the genes for the appearance.
    /// @param _rarity the rarity of the hero.
    /// @param _shiny whether or not the hero is shiny.
    /// @param _crystal the crystal
    function createHero(
        uint256 _statGenes,
        uint256 _visualGenes,
        Rarity _rarity,
        bool _shiny,
        HeroCrystal memory _crystal,
        uint256 _crystalId
    ) public onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        Hero memory _hero = Hero({
            id: nextHeroId,
            info: HeroInfo({
                statGenes: _statGenes,
                visualGenes: _visualGenes,
                rarity: _rarity,
                shiny: _shiny,
                generation: _crystal.generation,
                firstName: _crystal.firstName,
                lastName: _crystal.lastName,
                shinyStyle: _crystal.shinyStyle,
                class: statScience.getGene(_statGenes, 44), // class is position 44
                subClass: statScience.getGene(_statGenes, 40) // subclass is position 40
            }),
            state: HeroState({
                level: 1,
                xp: 0,
                currentQuest: address(0),
                staminaFullAt: 0,
                hpFullAt: 0,
                mpFullAt: 0,
                sp: 0,
                status: HeroStatus.OK
            }),
            summoningInfo: SummoningInfo({
                summonedTime: block.timestamp,
                nextSummonTime: block.timestamp,
                summonerId: _crystal.summonerId,
                assistantId: _crystal.assistantId,
                summons: 0,
                maxSummons: _crystal.maxSummons
            }),
            stats: statScience.generateStats(_statGenes, _crystal, _rarity, _crystalId),
            primaryStatGrowth: statScience.generateStatGrowth(_statGenes, _crystal, _rarity, true),
            secondaryStatGrowth: statScience.generateStatGrowth(_statGenes, _crystal, _rarity, false),
            professions: HeroProfessions({mining: 0, gardening: 0, foraging: 0, fishing: 0})
        });
        heroes[nextHeroId] = _hero;
        nextHeroId++;
        // emit the summon event
        emit HeroSummoned(
            _crystal.owner,
            _hero.id,
            uint256(_hero.summoningInfo.summonerId),
            uint256(_hero.summoningInfo.assistantId),
            _hero.info.statGenes,
            _hero.info.visualGenes
        );
        // Send the newly created hero to the owner.
        _mint(_crystal.owner, _hero.id);
        return _hero.id;
    }
    /// @dev Saves a hero object to storage.
    function updateHero(Hero memory _hero) external onlyRole(HERO_MODERATOR_ROLE) whenNotPaused {
        // Save the hero.
        heroes[_hero.id] = _hero;
        emit HeroUpdated(ownerOf(_hero.id), _hero.id, _hero);
    }
    // /**
    //  * @dev See {IERC165-supportsInterface}.
    //  */
    // /// TODO find out if this is right, Im not sure
    function supportsInterface(bytes4 interfaceId) public view override(ERC721EnumerableUpgradeable, AccessControlUpgradeable) returns (bool) {
        // return interfaceId == type(IHeroTypes).interfaceId || super.supportsInterface(interfaceId);
        return super.supportsInterface(interfaceId);
    }
    ///////////////////////////
    /// @dev ADMIN FUNCTION ///
    //////////////////////////
    function pause() public onlyRole(MODERATOR_ROLE) {
        _pause();
    }
    function unpause() public onlyRole(MODERATOR_ROLE) {
        _unpause();
    }
}