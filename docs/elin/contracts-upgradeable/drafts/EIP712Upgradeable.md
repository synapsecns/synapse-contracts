# EIP712Upgradeable







*https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data. The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible, thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding they need in their contracts using a combination of `abi.encode` and `keccak256`. This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA ({_hashTypedDataV4}). The implementation of the domain separator was designed to be as efficient as possible while still properly updating the chain id to protect against replay attacks on an eventual fork of the chain. NOTE: This contract implements the version of the encoding known as &quot;v4&quot;, as implemented by the JSON RPC method https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask]. _Available since v3.4._*



