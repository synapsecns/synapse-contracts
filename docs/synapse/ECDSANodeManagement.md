


# Functions:
- [`getPublicKey()`](#ECDSANodeManagement-getPublicKey--)
- [`submitPublicKey(bytes _publicKey)`](#ECDSANodeManagement-submitPublicKey-bytes-)
- [`getOwner()`](#ECDSANodeManagement-getOwner--)
- [`getOpenedTimestamp()`](#ECDSANodeManagement-getOpenedTimestamp--)
- [`closeKeep()`](#ECDSANodeManagement-closeKeep--)
- [`isActive()`](#ECDSANodeManagement-isActive--)
- [`isClosed()`](#ECDSANodeManagement-isClosed--)
- [`isTerminated()`](#ECDSANodeManagement-isTerminated--)
- [`getMembers()`](#ECDSANodeManagement-getMembers--)
- [`initialize(address _owner, address[] _members, uint256 _honestThreshold)`](#ECDSANodeManagement-initialize-address-address---uint256-)

# Events:
- [`ConflictingPublicKeySubmitted(address submittingMember, bytes conflictingPublicKey)`](#ECDSANodeManagement-ConflictingPublicKeySubmitted-address-bytes-)
- [`PublicKeyPublished(bytes publicKey)`](#ECDSANodeManagement-PublicKeyPublished-bytes-)
- [`KeepClosed()`](#ECDSANodeManagement-KeepClosed--)
- [`KeepTerminated()`](#ECDSANodeManagement-KeepTerminated--)

# <a id="ECDSANodeManagement-getPublicKey--"></a> Function `getPublicKey() → bytes`
No description
## Return Values:
- s ECDSA public key.
# <a id="ECDSANodeManagement-submitPublicKey-bytes-"></a> Function `submitPublicKey(bytes _publicKey)`
Public key is published successfully if all members submit the same
value. In case of conflicts with others members submissions it will emit
`ConflictingPublicKeySubmitted` event. When all submitted keys match
it will store the key as keep's public key and emit a `PublicKeyPublished`
event.

## Parameters:
- `_publicKey`: Signer's public key.
# <a id="ECDSANodeManagement-getOwner--"></a> Function `getOwner() → address`
No description
## Return Values:
- Address of the keep owner.
# <a id="ECDSANodeManagement-getOpenedTimestamp--"></a> Function `getOpenedTimestamp() → uint256`
No description
## Return Values:
- Timestamp the keep was opened at.
# <a id="ECDSANodeManagement-closeKeep--"></a> Function `closeKeep()`
The function can be called only by the owner of the keep and only
if the keep has not been already closed.
# <a id="ECDSANodeManagement-isActive--"></a> Function `isActive() → bool`
No description
## Return Values:
- true if the keep is active, false otherwise.
# <a id="ECDSANodeManagement-isClosed--"></a> Function `isClosed() → bool`
No description
## Return Values:
- true if the keep is closed, false otherwise.
# <a id="ECDSANodeManagement-isTerminated--"></a> Function `isTerminated() → bool`
No description
## Return Values:
- true if the keep has been terminated, false otherwise.
# <a id="ECDSANodeManagement-getMembers--"></a> Function `getMembers() → address[]`
No description
## Return Values:
- List of the keep members' addresses.
# <a id="ECDSANodeManagement-initialize-address-address---uint256-"></a> Function `initialize(address _owner, address[] _members, uint256 _honestThreshold)`
We use clone factory to create new keep. That is why this contract
doesn't have a constructor. We provide keep parameters for each instance
function after cloning instances from the master contract.
Initialization must happen in the same transaction in which the clone is
created.

## Parameters:
- `_owner`: Address of the keep owner.

- `_members`: Addresses of the keep members.

- `_honestThreshold`: Minimum number of honest keep members.

# <a id="ECDSANodeManagement-ConflictingPublicKeySubmitted-address-bytes-"></a> Event `ConflictingPublicKeySubmitted(address submittingMember, bytes conflictingPublicKey)` 
No description
# <a id="ECDSANodeManagement-PublicKeyPublished-bytes-"></a> Event `PublicKeyPublished(bytes publicKey)` 
No description
# <a id="ECDSANodeManagement-KeepClosed--"></a> Event `KeepClosed()` 
No description
# <a id="ECDSANodeManagement-KeepTerminated--"></a> Event `KeepTerminated()` 
No description
