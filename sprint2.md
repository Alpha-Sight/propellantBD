# PropellantBD Smart Contract Documentation

## Credential Verification System

The PropellantBD credential verification system implements a comprehensive solution for issuing, verifying, and managing digital credentials on the Lisk blockchain. This documentation outlines the key methods, events, and integration points for backend developers.

### CredentialVerificationModule

#### Key Methods

```solidity
// Issue a new credential
function issueCredential(
    address subject,
    string memory name,
    string memory description,
    string memory metadataURI,
    CredentialType credentialType,
    uint256 validUntil,
    bytes32 evidenceHash
) external returns (uint256);

// Verify a pending credential
function verifyCredential(
    uint256 credentialId,
    CredentialStatus status,
    string memory notes
) external;

// Revoke a previously verified credential
function revokeCredential(
    uint256 credentialId,
    string memory notes
) external;

// Update credential metadata
function updateCredential(
    uint256 credentialId,
    string memory name,
    string memory description,
    string memory metadataURI,
    uint256 validUntil
) external;

// Add a new issuer
function addIssuer(address issuer) external;

// Remove an issuer
function removeIssuer(address issuer) external;

// Check if an address is an authorized issuer
function isIssuer(address account) external view returns (bool);

// Get credential details
function getCredential(uint256 credentialId) external view returns (Credential memory);

// Get verification history for a credential
function getVerificationHistory(uint256 credentialId) external view returns (VerificationRecord[] memory);
```

#### Key Events

```solidity
// Emitted when a new credential is submitted
event CredentialSubmitted(
    uint256 indexed credentialId,
    address indexed issuer,
    address indexed subject
);

// Emitted when a credential status changes
event CredentialStatusChanged(
    uint256 indexed credentialId,
    CredentialStatus status,
    address verifier
);

// Emitted when a credential is updated
event CredentialUpdated(
    uint256 indexed credentialId,
    address updater
);

// Emitted when an issuer is added
event IssuerAdded(
    address indexed issuer,
    address indexed addedBy
);

// Emitted when an issuer is removed
event IssuerRemoved(
    address indexed issuer,
    address indexed removedBy
);
```

#### Data Structures

```solidity
// Credential types
enum CredentialType {
    GENERAL,
    CERTIFICATION,
    EDUCATION,
    EMPLOYMENT,
    SKILL
}

// Credential status values
enum CredentialStatus {
    PENDING,
    VERIFIED,
    REJECTED,
    REVOKED
}

// Main credential structure
struct Credential {
    address issuer;         // Who issued this credential
    address subject;        // Who this credential belongs to
    string name;            // Credential name
    string description;     // Brief description
    string metadataURI;     // Link to extended metadata (IPFS URI)
    CredentialType credentialType;  // Type classification
    CredentialStatus status;        // Current status
    uint256 issuedAt;       // Timestamp of issuance
    uint256 validUntil;     // Expiration date (0 for no expiration)
    bytes32 evidenceHash;   // Hash of supporting evidence
}

// Verification history record
struct VerificationRecord {
    CredentialStatus status;  // Status set in this record
    uint256 timestamp;        // When this change occurred
    address verifier;         // Who made the change
    string notes;             // Additional notes
}
```

### RoleModule

#### Key Methods

```solidity
// Grant a role to an account
function grantRole(bytes32 role, address account) external;

// Grant a role with validation
function grantRoleSafe(bytes32 role, address account) external;

// Revoke a role from an account
function revokeRole(bytes32 role, address account) external;

// Check if an account has a role
function hasRole(bytes32 role, address account) external view returns (bool);

// Get role metadata
function getRoleMetadata(bytes32 role) external view returns (
    string memory name, 
    string memory description, 
    bool active
);

// Update role metadata
function updateRoleMetadata(
    bytes32 role,
    string memory name,
    string memory description,
    bool active
) external;
```

#### Key Events

```solidity
// Emitted when a role is granted
event RoleGranted(
    bytes32 indexed role,
    address indexed account,
    address indexed sender
);

// Emitted when a role is revoked
event RoleRevoked(
    bytes32 indexed role,
    address indexed account,
    address indexed sender
);

// Emitted when role metadata changes
event RoleMetadataUpdated(
    bytes32 indexed role,
    string name,
    string description
);

// Emitted when a role's status changes
event RoleStatusChanged(
    bytes32 indexed role,
    bool active
);
```

#### Constants

```solidity
// Pre-defined roles
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant TALENT_ROLE = keccak256("TALENT_ROLE");
bytes32 public constant ORGANIZATION_ROLE = keccak256("ORGANIZATION_ROLE");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```

### UserProfileModule

#### Key Methods

```solidity
// Create a new user profile
function createProfile(
    string memory name,
    string memory bio,
    string memory email,
    string memory avatar
) external;

// Update an existing profile
function updateProfile(
    string memory name,
    string memory bio,
    string memory avatar
) external;

// Add a social media handle
function addSocialHandle(
    string memory platform,
    string memory handle
) external;

// Remove a social media handle
function removeSocialHandle(
    string memory platform
) external;

// Get a profile by address
function getProfile(address user) external view returns (
    string memory name,
    string memory bio,
    string memory email,
    string memory avatar
);

// Look up an address by email
function getAddressByEmail(string memory email) external view returns (address);

// Check if a profile exists
function profileExists(address user) external view returns (bool);
```

#### Key Events

```solidity
// Emitted when a profile is created
event ProfileCreated(
    address indexed user,
    string name,
    string email
);

// Emitted when a profile is updated
event ProfileUpdated(
    address indexed user
);

// Emitted when a social handle is added
event SocialHandleAdded(
    address indexed user,
    string platform,
    string handle
);

// Emitted when a social handle is removed
event SocialHandleRemoved(
    address indexed user,
    string platform
);
```

## Account Abstraction System

### PropellantBDAccount

```solidity
// Initialize the account
function initialize(address owner) external;

// Execute a transaction
function execute(
    address target,
    uint256 value,
    bytes calldata data
) external returns (bytes memory);

// Execute multiple transactions
function executeBatch(Call[] calldata calls) external;

// Initialize a profile for this account
function initializeProfile(
    string memory name,
    string memory bio,
    string memory email,
    string memory avatar
) external;

// Update profile linked to this account
function updateProfile(
    string memory name,
    string memory bio,
    string memory avatar
) external;

// Add social handle
function addSocialHandle(
    string memory platform, 
    string memory handle
) external;
```

### PropellantBDEntryPoint

```solidity
// Handle user operations
function handleOps(
    UserOperation[] calldata ops, 
    address payable beneficiary
) external;

// Get sender address from initCode
function getSenderAddress(bytes calldata initCode) external returns (address);

// Deposit funds for gas payments
function depositTo(address account) external payable;

// Withdraw funds
function withdrawTo(
    address payable withdrawAddress, 
    uint256 withdrawAmount
) external;
```

### PropellantBDPaymaster

```solidity
// Deposit funds to EntryPoint
function deposit() public payable;

// Set daily sponsorship limit
function setDailySponsorshipLimit(uint256 newLimit) external;

// Set maximum gas limit for operations
function setMaxGasLimit(uint256 newLimit) external;

// Toggle accepting operations
function setAcceptingOperations(bool accepting) external;

// Reset a user's daily usage
function resetDailyUsage(address account) external;

// Withdraw funds from EntryPoint
function withdrawFromEntryPoint(uint256 amount) external;
```

#### Key Events

```solidity
// Emitted when sponsorship is used
event SponsorshipUsed(
    address indexed account, 
    uint256 amount
);

// Emitted when sponsorship limit is updated
event SponsorshipLimitUpdated(
    uint256 newLimit
);

// Emitted when max gas limit is updated
event MaxGasLimitUpdated(
    uint256 newLimit
);

// Emitted when operation acceptance changes
event AcceptingOperationsUpdated(
    bool isAccepting
);
```

## Integration Examples

### Issuing a Credential

```javascript
// From backend to relayer
const credentialData = {
  userAddress: "0x...", // Smart account address
  target: credentialVerificationModuleAddress,
  value: "0",
  data: encodeFunctionData("issueCredential", [
    subjectAddress,
    "Software Engineering Certificate",
    "Advanced certification in software architecture",
    "ipfs://QmCredentialMetadata",
    1, // CERTIFICATION type
    0, // No expiration
    evidenceHash
  ]),
  operation: 0,
  description: "Issue credential"
};
```

### Verifying a Credential

```javascript
// From backend to relayer
const verifyData = {
  userAddress: "0x...", // Issuer's smart account address
  target: credentialVerificationModuleAddress,
  value: "0",
  data: encodeFunctionData("verifyCredential", [
    credentialId,
    1, // VERIFIED status
    "All requirements met"
  ]),
  operation: 0,
  description: "Verify credential"
};
```

## Event Handling

When monitoring for credential events, listen for:

```javascript
// Create filter for CredentialSubmitted events
const filter = credentialVerificationModule.filters.CredentialSubmitted();

// Subscribe to events
credentialVerificationModule.on(filter, (credentialId, issuer, subject) => {
  console.log(`Credential ${credentialId} issued from ${issuer} to ${subject}`);
});

// Status change filter
const statusFilter = credentialVerificationModule.filters.CredentialStatusChanged();
```

## Access Control

- Only accounts with ORGANIZATION_ROLE can issue credentials
- Only the original issuer can verify/revoke their issued credentials
- Only ADMIN_ROLE accounts can add/remove issuers
- Credential subjects can view but not modify their credentials

## Transaction Flow

1. Backend requests credential issuance/verification
2. Request is queued in the relayer service
3. Relayer creates a UserOperation with:
   - Smart account as sender
   - Paymaster covering gas fees
   - Target function call in callData
4. EntryPoint processes the operation
5. Transaction status is monitored and reported back

## Testing

For backend integration testing, use the included test suite that covers:
- Credential issuance, verification, and revocation
- Role-based access control
- Profile creation and management
- Account creation and transaction submission
- Error cases and edge conditions