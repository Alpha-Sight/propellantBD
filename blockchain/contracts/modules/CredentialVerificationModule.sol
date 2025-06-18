// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// Interface for external modules
interface IRoleModule {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function ORGANIZATION_ROLE() external view returns (bytes32);
    function ADMIN_ROLE() external view returns (bytes32);
}

interface IUserProfileModule {
    function hasProfile(address user) external view returns (bool);
}

/**
 * @title CredentialVerificationModule
 * @dev Handles verification of credentials 
 */
contract CredentialVerificationModule is AccessControl, Pausable {
    // References to other modules
    IRoleModule public immutable roleModule;
    IUserProfileModule public immutable profileModule;
    
    // Replace Counters with simple uint256
    uint256 private _credentialIdCounter;
    
    // Credential types
    enum CredentialType {
        EDUCATION,
        CERTIFICATION,
        EXPERIENCE,
        SKILL,
        ACHIEVEMENT,
        REFERENCE,
        OTHER
    }
    
    // Verification status
    enum CredentialStatus {
        PENDING,
        VERIFIED,
        REJECTED,
        REVOKED
    }

    // Credential structure
    struct Credential {
        uint256 id;
        address issuer;
        address subject;
        string name;
        string description;
        string metadataURI;
        CredentialType credentialType;
        uint256 validUntil;
        bytes32 evidenceHash;
        bool revocable;
        CredentialStatus status;
        uint256 issuedAt;
        uint256 verifiedAt;
        address verifier;
    }

    // Verification record structure
    struct VerificationRecord {
        CredentialStatus status;
        uint256 timestamp;
        address verifier;
        string notes;
    }

    // Storage mappings
    mapping(uint256 => Credential) private _credentials;
    mapping(address => uint256[]) private _userCredentials;
    mapping(uint256 => VerificationRecord[]) private _verificationHistory;

    // Role definition
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    // Events
    event CredentialSubmitted(uint256 indexed credentialId, address indexed issuer, address indexed subject);
    event CredentialStatusChanged(uint256 indexed credentialId, CredentialStatus status, address verifier);
    event CredentialUpdated(uint256 indexed credentialId, address updater);
    event IssuerAdded(address indexed issuer);
    event IssuerRemoved(address indexed issuer);

    /**
     * @dev Constructor
     */
    constructor(address _roleModule, address _profileModule) {
        require(_roleModule != address(0), "CredentialVerification: roleModule is zero address");
        require(_profileModule != address(0), "CredentialVerification: profileModule is zero address");
        
        roleModule = IRoleModule(_roleModule);
        profileModule = IUserProfileModule(_profileModule);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Issue a new credential
     */
    function issueCredential(
        address subject,
        string memory name,
        string memory description,
        string memory metadataURI,
        CredentialType credentialType,
        uint256 validUntil,
        bytes32 evidenceHash,
        bool revocable
    ) external returns (uint256) {
        require(hasRole(ISSUER_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "CredentialVerification: caller is not an issuer");
        require(subject != address(0), "CredentialVerification: invalid subject");
        
        // Replace Counters usage
        _credentialIdCounter++;
        uint256 credentialId = _credentialIdCounter;
        
        // Store credential data
        _credentials[credentialId] = Credential({
            id: credentialId,
            issuer: msg.sender,
            subject: subject,
            name: name,
            description: description,
            metadataURI: metadataURI,
            credentialType: credentialType,
            validUntil: validUntil,
            evidenceHash: evidenceHash,
            revocable: revocable,
            status: CredentialStatus.PENDING,
            issuedAt: block.timestamp,
            verifiedAt: 0,
            verifier: address(0)
        });
        
        // Add to user's credentials list
        _userCredentials[subject].push(credentialId);
        
        emit CredentialSubmitted(credentialId, msg.sender, subject);
        
        return credentialId;
    }

    /**
     * @dev Add an organization as an issuer
     */
    function addIssuer(address issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            roleModule.hasRole(roleModule.ORGANIZATION_ROLE(), issuer) || 
            roleModule.hasRole(roleModule.ADMIN_ROLE(), issuer),
            "CredentialVerification: issuer must be an organization or admin"
        );
        
        _grantRole(ISSUER_ROLE, issuer);
        emit IssuerAdded(issuer);
    }

    /**
     * @dev Remove an issuer
     */
    function removeIssuer(address issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ISSUER_ROLE, issuer);
        emit IssuerRemoved(issuer);
    }

    /**
     * @dev Get credential details
     */
    function getCredential(uint256 credentialId) external view returns (Credential memory) {
        return _credentials[credentialId];
    }

    /**
     * @dev Get user's credentials
     */
    function getUserCredentials(address user) external view returns (uint256[] memory) {
        return _userCredentials[user];
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}