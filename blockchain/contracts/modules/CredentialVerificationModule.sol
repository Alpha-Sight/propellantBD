// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../base/AccessControl.sol";
import "../base/Pausable.sol";
import "../base/Upgradeable.sol";
import "./RoleModule.sol";
import "./UserProfileModule.sol";

/**
 * @title CredentialVerificationModule
 * @dev Contract module for managing credentials in the PropellantBD ecosystem.
 * Handles issuance, verification, and revocation of credentials.
 */
contract CredentialVerificationModule is AccessControl, Pausable, Upgradeable {
    // Role constants (imported from RoleModule)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TALENT_ROLE = keccak256("TALENT_ROLE");
    bytes32 public constant ORGANIZATION_ROLE = keccak256("ORGANIZATION_ROLE");
    
    // Credential issuer role - only these accounts can issue credentials
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    
    // Reference to RoleModule for role checks
    RoleModule private _roleModule;
    
    // Reference to UserProfileModule for profile validation
    UserProfileModule private _userProfileModule;
    
    // Credential types
    enum CredentialType {
        EDUCATION,       // Educational qualifications
        CERTIFICATION,   // Professional certifications
        EXPERIENCE,      // Work experience
        SKILL,           // Specific skills/proficiencies
        ACHIEVEMENT,     // Awards, honors, recognition
        REFERENCE,       // Professional references
        OTHER            // Any other credential type
    }
    
    // Credential verification status
    enum VerificationStatus {
        PENDING,         // Awaiting verification
        VERIFIED,        // Successfully verified
        REJECTED,        // Verification rejected
        REVOKED          // Previously verified but now revoked
    }
    
    // Credential structure
    struct Credential {
        bytes32 id;                  // Unique identifier
        address subject;             // Who the credential is about
        address issuer;              // Who issued the credential
        string name;                 // Name/title of the credential
        string description;          // Detailed description
        string metadataURI;          // IPFS URI for additional metadata
        CredentialType credentialType; // Type of credential
        VerificationStatus status;   // Current verification status
        uint256 issuanceDate;        // When the credential was issued
        uint256 expirationDate;      // When the credential expires (0 for no expiration)
        bytes32 evidenceHash;        // Hash of evidence supporting the credential
        bool revocable;              // Whether this credential can be revoked
    }
    
    // Verification record
    struct VerificationRecord {
        address verifier;            // Who verified the credential
        VerificationStatus status;   // Status set by this verification
        string notes;                // Notes from the verifier
        uint256 timestamp;           // When the verification occurred
    }
    
    // Mappings for credential data
    mapping(bytes32 => Credential) private _credentials;
    mapping(address => bytes32[]) private _subjectCredentials;
    mapping(address => bytes32[]) private _issuerCredentials;
    mapping(bytes32 => VerificationRecord[]) private _verificationHistory;
    
    // Events
    event CredentialIssued(bytes32 indexed id, address indexed subject, address indexed issuer, CredentialType credentialType);
    event CredentialVerified(bytes32 indexed id, address indexed verifier, VerificationStatus status);
    event CredentialRevoked(bytes32 indexed id, address indexed revoker, string reason);
    event CredentialUpdated(bytes32 indexed id, string name, string description);
    event IssuerAdded(address indexed issuer);
    event IssuerRemoved(address indexed issuer);
    
    /**
     * @dev Modifier to ensure the caller is the credential subject or an admin
     */
    modifier onlySubjectOrAdmin(bytes32 id) {
        require(
            _credentials[id].subject == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "CredentialVerification: caller is not credential subject or admin"
        );
        _;
    }
    
    /**
     * @dev Modifier to ensure the caller is the credential issuer
     */
    modifier onlyIssuer(bytes32 id) {
        require(
            _credentials[id].issuer == msg.sender,
            "CredentialVerification: caller is not the credential issuer"
        );
        _;
    }
    
    /**
     * @dev Constructor that sets the role module and user profile module addresses
     */
    constructor(address payable roleModuleAddress, address payable userProfileModuleAddress) {
        require(roleModuleAddress != address(0), "CredentialVerification: role module address is zero");
        require(userProfileModuleAddress != address(0), "CredentialVerification: user profile module address is zero");
        
        _roleModule = RoleModule(roleModuleAddress);
        _userProfileModule = UserProfileModule(userProfileModuleAddress);
    }
    
    /**
     * @dev Adds an account as a credential issuer
     * @param issuer Address to add as an issuer
     */
    function addIssuer(address issuer) 
        external 
        whenNotPaused 
        onlyRole(ADMIN_ROLE) 
    {
        require(issuer != address(0), "CredentialVerification: issuer is zero address");
        require(_roleModule.hasRole(ORGANIZATION_ROLE, issuer) || hasRole(ADMIN_ROLE, issuer), 
                "CredentialVerification: issuer must be an organization or admin");
        
        _roleModule.grantRoleSafe(ISSUER_ROLE, issuer);
        
        emit IssuerAdded(issuer);
    }
    
    /**
     * @dev Removes an account from the credential issuers
     * @param issuer Address to remove as an issuer
     */
    function removeIssuer(address issuer) 
        external 
        whenNotPaused 
        onlyRole(ADMIN_ROLE) 
    {
        require(_roleModule.hasRole(ISSUER_ROLE, issuer), "CredentialVerification: address is not an issuer");
        
        _roleModule.revokeRoleSafe(ISSUER_ROLE, issuer);
        
        emit IssuerRemoved(issuer);
    }
    
    /**
     * @dev Issues a new credential
     * @param subject Address of the credential subject
     * @param name Name/title of the credential
     * @param description Detailed description
     * @param metadataURI IPFS URI for additional metadata
     * @param credentialType Type of credential
     * @param expirationDate When the credential expires (0 for no expiration)
     * @param evidenceHash Hash of evidence supporting the credential
     * @param revocable Whether this credential can be revoked
     */
    function issueCredential(
        address subject,
        string memory name,
        string memory description,
        string memory metadataURI,
        CredentialType credentialType,
        uint256 expirationDate,
        bytes32 evidenceHash,
        bool revocable
    ) 
        external 
        whenNotPaused 
        returns (bytes32)
    {
        require(_roleModule.hasRole(ISSUER_ROLE, msg.sender), "CredentialVerification: caller is not an issuer");
        require(subject != address(0), "CredentialVerification: subject is zero address");
        require(_userProfileModule.profileExists(subject), "CredentialVerification: subject profile does not exist");
        require(bytes(name).length > 0, "CredentialVerification: name cannot be empty");
        
        // If expiration date is set, it must be in the future
        if (expirationDate > 0) {
            require(expirationDate > block.timestamp, "CredentialVerification: expiration date must be in the future");
        }
        
        // Generate a unique ID for the credential
        bytes32 id = keccak256(abi.encodePacked(
            subject, 
            msg.sender, 
            name, 
            block.timestamp, 
            _issuerCredentials[msg.sender].length
        ));
        
        // Ensure the ID is unique
        require(_credentials[id].issuanceDate == 0, "CredentialVerification: ID collision - try again");
        
        // Create and store the new credential
        _credentials[id] = Credential({
            id: id,
            subject: subject,
            issuer: msg.sender,
            name: name,
            description: description,
            metadataURI: metadataURI,
            credentialType: credentialType,
            status: VerificationStatus.PENDING,
            issuanceDate: block.timestamp,
            expirationDate: expirationDate,
            evidenceHash: evidenceHash,
            revocable: revocable
        });
        
        // Add to subject's and issuer's credentials
        _subjectCredentials[subject].push(id);
        _issuerCredentials[msg.sender].push(id);
        
        emit CredentialIssued(id, subject, msg.sender, credentialType);
        
        return id;
    }
    
    /**
     * @dev Verifies a credential
     * @param id ID of the credential
     * @param status New verification status
     * @param notes Notes from the verifier
     */
    function verifyCredential(
        bytes32 id,
        VerificationStatus status,
        string memory notes
    ) 
        external 
        whenNotPaused 
    {
        require(_credentials[id].issuanceDate > 0, "CredentialVerification: credential does not exist");
        require(
            msg.sender == _credentials[id].issuer || hasRole(ADMIN_ROLE, msg.sender),
            "CredentialVerification: caller cannot verify this credential"
        );
        require(
            status != VerificationStatus.PENDING,
            "CredentialVerification: cannot set status to PENDING"
        );
        
        // Create new verification record
        VerificationRecord memory record = VerificationRecord({
            verifier: msg.sender,
            status: status,
            notes: notes,
            timestamp: block.timestamp
        });
        
        // Add to verification history
        _verificationHistory[id].push(record);
        
        // Update credential status
        _credentials[id].status = status;
        
        emit CredentialVerified(id, msg.sender, status);
    }
    
    /**
     * @dev Revokes a credential
     * @param id ID of the credential
     * @param reason Reason for revocation
     */
    function revokeCredential(bytes32 id, string memory reason) 
        external 
        whenNotPaused 
    {
        require(_credentials[id].issuanceDate > 0, "CredentialVerification: credential does not exist");
        require(_credentials[id].revocable, "CredentialVerification: credential is not revocable");
        require(
            msg.sender == _credentials[id].issuer || hasRole(ADMIN_ROLE, msg.sender),
            "CredentialVerification: caller cannot revoke this credential"
        );
        require(
            _credentials[id].status != VerificationStatus.REVOKED,
            "CredentialVerification: credential already revoked"
        );
        
        // Update credential status
        _credentials[id].status = VerificationStatus.REVOKED;
        
        // Create revocation record
        VerificationRecord memory record = VerificationRecord({
            verifier: msg.sender,
            status: VerificationStatus.REVOKED,
            notes: reason,
            timestamp: block.timestamp
        });
        
        // Add to verification history
        _verificationHistory[id].push(record);
        
        emit CredentialRevoked(id, msg.sender, reason);
    }
    
    /**
     * @dev Updates credential metadata
     * @param id ID of the credential
     * @param name New name/title
     * @param description New description
     * @param metadataURI New IPFS URI for additional metadata
     */
    function updateCredential(
        bytes32 id,
        string memory name,
        string memory description,
        string memory metadataURI
    ) 
        external 
        whenNotPaused 
        onlyIssuer(id) 
    {
        require(_credentials[id].issuanceDate > 0, "CredentialVerification: credential does not exist");
        require(_credentials[id].status != VerificationStatus.REVOKED, "CredentialVerification: credential is revoked");
        require(bytes(name).length > 0, "CredentialVerification: name cannot be empty");
        
        Credential storage credential = _credentials[id];
        
        credential.name = name;
        credential.description = description;
        credential.metadataURI = metadataURI;
        
        emit CredentialUpdated(id, name, description);
    }
    
    /**
     * @dev Gets a credential's data
     * @param id ID of the credential
     */
    function getCredential(bytes32 id) 
        external 
        view 
        returns (
            address subject,
            address issuer,
            string memory name,
            string memory description,
            string memory metadataURI,
            CredentialType credentialType,
            VerificationStatus status,
            uint256 issuanceDate,
            uint256 expirationDate,
            bytes32 evidenceHash,
            bool revocable
        ) 
    {
        require(_credentials[id].issuanceDate > 0, "CredentialVerification: credential does not exist");
        
        Credential storage credential = _credentials[id];
        return (
            credential.subject,
            credential.issuer,
            credential.name,
            credential.description,
            credential.metadataURI,
            credential.credentialType,
            credential.status,
            credential.issuanceDate,
            credential.expirationDate,
            credential.evidenceHash,
            credential.revocable
        );
    }
    
    /**
     * @dev Gets all credentials for a subject
     * @param subject Address of the subject
     */
    function getSubjectCredentials(address subject) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return _subjectCredentials[subject];
    }
    
    /**
     * @dev Gets all credentials issued by an issuer
     * @param issuer Address of the issuer
     */
    function getIssuerCredentials(address issuer) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return _issuerCredentials[issuer];
    }
    
    /**
     * @dev Gets the verification history for a credential
     * @param id ID of the credential
     */
    function getVerificationHistory(bytes32 id) 
        external 
        view 
        returns (VerificationRecord[] memory) 
    {
        require(_credentials[id].issuanceDate > 0, "CredentialVerification: credential does not exist");
        return _verificationHistory[id];
    }
    
    /**
     * @dev Checks if a credential is valid (verified and not expired)
     * @param id ID of the credential
     */
    function isCredentialValid(bytes32 id) 
        external 
        view 
        returns (bool) 
    {
        if (_credentials[id].issuanceDate == 0) {
            return false;
        }
        
        Credential storage credential = _credentials[id];
        
        // Check if verified
        bool verified = credential.status == VerificationStatus.VERIFIED;
        
        // Check if not expired
        bool notExpired = credential.expirationDate == 0 || credential.expirationDate > block.timestamp;
        
        return verified && notExpired;
    }
    
    /**
     * @dev Checks if an address is an issuer
     * @param issuer Address to check
     */
    function isIssuer(address issuer) 
        external 
        view 
        returns (bool) 
    {
        return _roleModule.hasRole(ISSUER_ROLE, issuer);
    }
}