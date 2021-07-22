This contract implements a key-value store for storing variables on which synapse nodes must coordinate
methods are purposely arbitrary to allow these fields to be defined in synapse improvement proposals.
This token is used for configuring different tokens on the bridge and mapping them across chains.



# Functions:
- [`keyCount()`](#NodeEnv-keyCount--)
- [`keyValueByIndex(uint256 index)`](#NodeEnv-keyValueByIndex-uint256-)
- [`get(string _key)`](#NodeEnv-get-string-)
- [`set(string _key, string _value)`](#NodeEnv-set-string-string-)

# Events:
- [`ConfigUpdate(string key)`](#NodeEnv-ConfigUpdate-string-)

# <a id="NodeEnv-keyCount--"></a> Function `keyCount() → uint256`
this is useful for enumerating through all keys in the env
# <a id="NodeEnv-keyValueByIndex-uint256-"></a> Function `keyValueByIndex(uint256 index) → string, string`
No description
# <a id="NodeEnv-get-string-"></a> Function `get(string _key) → string`
No description
# <a id="NodeEnv-set-string-string-"></a> Function `set(string _key, string _value) → bool`
caller must have bridge manager role

# <a id="NodeEnv-ConfigUpdate-string-"></a> Event `ConfigUpdate(string key)` 
No description
