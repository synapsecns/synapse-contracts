// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Pet, PetOptions, UnhatchedEgg, PriceTier} from "./types/PetTypes.sol";

interface IPetCoreUpgradeable {
    function getUserPets(address _address) external view returns (Pet[] memory);

    function getPet(uint256 _id) external view returns (Pet memory);

    function hatchPet(PetOptions memory _petOptions, address owner) external returns (uint256);

    function updatePet(Pet memory _pet) external;

    function bridgeMint(uint256 _id, address _to) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

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

    function ownerOf(uint256 tokenId) external view returns (address);

    function approve(address to, uint256 tokenId) external;
}
