// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title GeneScience implements the trait calculation for new genes
/// @author Axiom Zen, Dieter Shirley <dete@axiomzen.co> (https://github.com/dete), Fabiano P. Soriani <fabianosoriani@gmail.com> (https://github.com/flockonus), Jordan Schalm <jordan.schalm@gmail.com> (https://github.com/jordanschalm), Defi Crafter <deficrafter@protonmail.com> (https://github.com/deficrafter)
library LibGeneScience {
    /// @dev given a characteristic and 2 genes (unsorted) - returns > 0 if the genes ascended, that's the value
    /// @param trait1 any trait of that characteristic
    /// @param trait2 any trait of that characteristic
    /// @param rand is expected to be a 3 bits number (0~7)
    /// @return ascension -1 if didnt match any ascention, OR a number from 0 to 30 for the ascended trait
    function _ascend(
        uint8 trait1,
        uint8 trait2,
        uint256 rand
    ) internal pure returns (uint8 ascension) {
        ascension = 0;

        uint8 smallT = trait1;
        uint8 bigT = trait2;

        if (smallT > bigT) {
            bigT = trait1;
            smallT = trait2;
        }

        if ((bigT - smallT == 1) && smallT % 2 == 0) {
            // The rand argument is expected to be a random number 0-7.
            // 1st and 2nd tier: 1/4 chance (rand is 0 or 1)
            // 3rd and 4th tier: 1/8 chance (rand is 0)

            // must be at least this much to ascend
            uint256 maxRand;
            if (smallT < 23) maxRand = 1;
            else maxRand = 0;

            if (rand <= maxRand) {
                ascension = (smallT / 2) + 16;
            }
        }
    }

    /// @dev given a number get a slice of any bits, at certain offset
    /// @param _n a number to be sliced
    /// @param _nbits how many bits long is the new number
    /// @param _offset how many bits to skip
    function _sliceNumber(
        uint256 _n,
        uint256 _nbits,
        uint256 _offset
    ) private pure returns (uint256) {
        // mask is made by shifting left an offset number of times
        uint256 mask = uint256((2**_nbits) - 1) << _offset;
        // AND n with mask, and trim to max of _nbits bits
        return uint256((_n & mask) >> _offset);
    }

    /// @dev Get a 5 bit slice from an input as a number
    /// @param _input bits, encoded as uint
    /// @param _slot from 0 to 50
    function _get5Bits(uint256 _input, uint256 _slot) internal pure returns (uint8) {
        return uint8(_sliceNumber(_input, uint256(5), _slot * 5));
    }

    /// @dev Parse a gene and returns all of 12 "trait stack" that makes the characteristics
    /// @param _genes gene
    /// @return the 48 traits that composes the genetic code, logically divided in stacks of 4, where only the first trait of each stack may express
    function decode(uint256 _genes) internal pure returns (uint8[] memory) {
        uint8[] memory traits = new uint8[](48);
        uint256 i;
        for (i = 0; i < 48; i++) {
            traits[i] = _get5Bits(_genes, i);
        }
        return traits;
    }

    /// @dev Given an array of traits return the number that represent genes
    function encode(uint8[] memory _traits) internal pure returns (uint256 _genes) {
        _genes = 0;
        for (uint256 i = 0; i < 48; i++) {
            _genes = _genes << 5;
            // bitwise OR trait with _genes
            _genes = _genes | _traits[47 - i];
        }
        return _genes;
    }

    /// @dev return the expressing traits
    /// @param _genes the long number expressing cat genes
    function expressingTraits(uint256 _genes) internal pure returns (uint8[12] memory) {
        uint8[12] memory express;
        for (uint256 i = 0; i < 12; i++) {
            express[i] = _get5Bits(_genes, i * 4);
        }
        return express;
    }

    /// @dev the function as defined in the breeding contract.
    function mixGenes(
        uint256 _genes1,
        uint256 _genes2,
        uint256 _randomN
    ) internal pure returns (uint256) {
        // generate 256 bits of random, using as much entropy as we can from
        // sources that can't change between calls.
        _randomN = uint256(keccak256(abi.encodePacked(_randomN, _genes1, _genes2)));
        uint256 randomIndex = 0;

        uint8[] memory genes1Array = decode(_genes1);
        uint8[] memory genes2Array = decode(_genes2);
        // All traits that will belong to baby
        uint8[] memory babyArray = new uint8[](48);
        // A pointer to the trait we are dealing with currently
        uint256 traitPos;
        // Trait swap value holder
        uint8 swap;
        // iterate all 12 characteristics
        for (uint256 i = 0; i < 12; i++) {
            // pick 4 traits for characteristic i
            uint256 j;
            for (j = 3; j >= 1; j--) {
                traitPos = (i * 4) + j;

                uint256 rand = _sliceNumber(_randomN, 2, randomIndex); // 0~3
                randomIndex += 2;

                // 1/4 of a chance of gene swapping forward towards expressing.
                if (rand == 0) {
                    // do it for parent 1
                    swap = genes1Array[traitPos];
                    genes1Array[traitPos] = genes1Array[traitPos - 1];
                    genes1Array[traitPos - 1] = swap;
                }

                rand = _sliceNumber(_randomN, 2, randomIndex); // 0~3
                randomIndex += 2;

                if (rand == 0) {
                    // do it for parent 2
                    swap = genes2Array[traitPos];
                    genes2Array[traitPos] = genes2Array[traitPos - 1];
                    genes2Array[traitPos - 1] = swap;
                }
            }
        }

        // DEBUG ONLY - We should have used 72 2-bit slices above for the swapping
        // which will have consumed 144 bits.
        // assert(randomIndex == 144);

        // We have 256 - 144 = 112 bits of _randomNess left at this point. We will use up to
        // four bits for the first slot of each trait (three for the possible ascension, one
        // to pick between mom and dad if the ascension fails, for a total of 48 bits. The other
        // traits use one bit to pick between parents (36 gene pairs, 36 genes), leaving us
        // well within our entropy budget.

        // done shuffling parent genes, now let's decide on choosing trait and if ascending.
        // NOTE: Ascensions ONLY happen in the "top slot" of each characteristic. This saves
        //  gas and also ensures ascensions only happen when they're visible.
        for (traitPos = 0; traitPos < 48; traitPos++) {
            // See if this trait pair should ascend
            uint8 ascendedTrait = 0;

            // There are two checks here. The first is straightforward, only the trait
            // in the first slot can ascend. The first slot is zero mod 4.
            //
            // The second check is more subtle: Only values that are one apart can ascend,
            // which is what we check inside the _ascend method. However, this simple mask
            // and compare is very cheap (9 gas) and will filter out about half of the
            // non-ascending pairs without a function call.
            //
            // The comparison itself just checks that one value is even, and the other
            // is odd.
            if ((traitPos % 4 == 0) && (genes1Array[traitPos] & 1) != (genes2Array[traitPos] & 1)) {
                uint256 rand = _sliceNumber(_randomN, 3, randomIndex);
                randomIndex += 3;

                ascendedTrait = _ascend(genes1Array[traitPos], genes2Array[traitPos], rand);
            }

            if (ascendedTrait > 0) {
                babyArray[traitPos] = uint8(ascendedTrait);
            } else {
                // did not ascend, pick one of the parent's traits for the baby
                // We use the top bit of rand for this (the bottom three bits were used
                // to check for the ascension itself).
                uint256 rand = _sliceNumber(_randomN, 1, randomIndex);
                randomIndex += 1;

                if (rand == 0) {
                    babyArray[traitPos] = uint8(genes1Array[traitPos]);
                } else {
                    babyArray[traitPos] = uint8(genes2Array[traitPos]);
                }
            }
        }

        return encode(babyArray);
    }
}
