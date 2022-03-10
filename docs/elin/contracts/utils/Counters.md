# Counters

*Matt Condon (@shrugs)*

> Counters



*Provides counters that can only be incremented or decremented by one. This can be used e.g. to track the number of elements in a mapping, issuing ERC721 ids, or counting request ids. Include with `using Counters for Counters.Counter;` Since it is not possible to overflow a 256 bit integer with increments of one, `increment` can skip the {SafeMath} overflow check, thereby saving gas. This does assume however correct usage, in that the underlying `_value` is never directly accessed.*



