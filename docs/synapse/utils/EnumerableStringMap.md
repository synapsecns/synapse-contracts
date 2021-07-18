
Library for managing an enumerable variant of Solidity's
https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`]
type.

Maps have the following properties:

- Entries are added, removed, and checked for existence in constant time
(O(1)).
- Entries are enumerated in O(n). No guarantees are made on the ordering.

this isn't a terribly gas efficient implementation because it emphasizes usability over gas efficiency
by allowing arbitrary length string memorys. If Gettetrs/Setters are going to be used frequently in contracts
consider using the OpenZeppeling Bytes32 implementation

this also differs from the OpenZeppelin implementation by keccac256 hashing the string memorys
so we can use enumerable bytes32 set

# Functions:



