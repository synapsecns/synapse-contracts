# EnumerableMapUpgradeable







*Library for managing an enumerable variant of Solidity&#39;s https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`] type. Maps have the following properties: - Entries are added, removed, and checked for existence in constant time (O(1)). - Entries are enumerated in O(n). No guarantees are made on the ordering. ``` contract Example {     // Add the library methods     using EnumerableMap for EnumerableMap.UintToAddressMap;     // Declare a set state variable     EnumerableMap.UintToAddressMap private myMap; } ``` The following map types are supported: - `uint256 -&gt; address` (`UintToAddressMap`) since v3.0.0 - `address -&gt; uint256` (`AddressToUintMap`) since v4.6.0 - `bytes32 -&gt; bytes32` (`Bytes32ToBytes32`) since v4.6.0*



