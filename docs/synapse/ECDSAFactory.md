



# Functions:
- [`getMembers()`](#ECDSAFactory-getMembers--)
- [`deploy(address nodeMgmtAddress, address owner, address[] members, uint256 honestThreshold)`](#ECDSAFactory-deploy-address-address-address---uint256-)

# Events:
- [`ECDSANodeGroupCreated(address keepAddress, address[] members, address owner, uint256 honestThreshold)`](#ECDSAFactory-ECDSANodeGroupCreated-address-address---address-uint256-)

# Function `getMembers() → address[]` {#ECDSAFactory-getMembers--}
Returns members of the keep.


## Return Values:
- List of the keep members' addresses.
# Function `deploy(address nodeMgmtAddress, address owner, address[] members, uint256 honestThreshold) → address` {#ECDSAFactory-deploy-address-address-address---uint256-}
Deploys a new node 
    @param nodeMgmtAddress address of the ECDSANodeManagement contract to initialize with
    @param owner Owner of the  ECDSANodeManagement contract who can determine if the node group is closed or active
    @param members Array of node group members addresses
    @param honestThreshold Number of signers to process a transaction 
    @return Address of the newest node management contract created



# Event `ECDSANodeGroupCreated(address keepAddress, address[] members, address owner, uint256 honestThreshold)` {#ECDSAFactory-ECDSANodeGroupCreated-address-address---address-uint256-}
No description

