// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./RoleModule.sol";
import "./UserProfileModule.sol";
import "./CredentialNFT.sol";

/**
 * @title CredentialVerificationModule
 * @dev Handles verification of credentials and interfaces with CredentialNFT
 */
contract CredentialVerificationModule is AccessControl, Pausable {
    using Counters for Counters.Counter;
    
    // References to other modules
    RoleModule public immutable roleModule;
    UserProfileModule public immutable profileModule;
    CredentialNFT public immutable credentialNFT;
    
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
    
    // Credential verification record
    struct VerificationRecord {
        uint256 timestamp;
        address verifier;
        CredentialStatus status;
        string notes;
    }
    
    // Role constants
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    
    // Mappings for verification history
    mapping(uint256 => VerificationRecord[]) private _verificationHistory;
    
    // Events
    event CredentialSubmitted(uint256 indexed tokenId, address indexed subject, address indexed issuer);
    event CredentialVerified(uint256 indexed tokenId, address indexed verifier, CredentialStatus status);
    event CredentialRevoked(uint256 indexed tokenId, address indexed revoker, string reason);
    event IssuerAdded(address indexed issuer);
    event IssuerRemoved(address indexed issuer);
    
    /**
     * @dev Constructor
     * @param _roleModule Address of the RoleModule contract
     * @param _profileModule Address of the UserProfileModule contract
     * @param _credentialNFT Address of the CredentialNFT contract
     */
    constructor(
        RoleModule _roleModule,
        UserProfileModule _profileModule,
        CredentialNFT _credentialNFT
    ) {
        require(address(_roleModule) != address(0), "CredentialVerification: roleModule is zero address");
        require(address(_profileModule) != address(0), "CredentialVerification: profileModule is zero address");
        require(address(_credentialNFT) != address(0), "CredentialVerification: credentialNFT is zero address");
        
        roleModule = _roleModule;
        profileModule = _profileModule;
        credentialNFT = _credentialNFT;
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // Grant this contract the MINTER_ROLE on the CredentialNFT contract
        _credentialNFT.grantRole(_credentialNFT.MINTER_ROLE(), address(this));
    }
    
    /**
     * @dev Modifier to check if caller is an issuer
     */
    modifier onlyIssuer() {
        require(
            hasRole(ISSUER_ROLE, msg.sender) || 
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
            roleModule.hasRole(roleModule.ADMIN_ROLE(), msg.sender),
            "CredentialVerification: caller is not an issuer"
        );
        _;
    }
    
    /**
     * @dev Add an organization as an issuer
     * @param issuer Address to add as issuer
     */
    function addIssuer(address issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            roleModule.hasRole(roleModule.ORGANIZATION_ROLE(), issuer) || 
            roleModule.hasRole(roleModule.ADMIN_ROLE(), issuer),
            "CredentialVerification: issuer must be an organization or admin"
        );
        
        grantRole(ISSUER_ROLE, issuer);
        emit IssuerAdded(issuer);
    }
    
    /**
     * @dev Remove an issuer
     * @param issuer Address to remove
     */
    function removeIssuer(address issuer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ISSUER_ROLE, issuer);
        emit IssuerRemoved(issuer);
    }
    
    /**
     * @dev Check if an address is an issuer
     * @param issuer Address to check
     * @return True if address is an issuer
     */
    function isIssuer(address issuer) external view returns (bool) {
        return hasRole(ISSUER_ROLE, issuer) || hasRole(DEFAULT_ADMIN_ROLE, issuer);
    }
    
    /**
     * @dev Issue a new credential and mint NFT
     * @param subject Address that will own the credential
     * @param name Credential name
     * @param description Credential description
     * @param metadataURI IPFS URI for additional metadata
     * @param credentialType Type of credential
     * @param validUntil Expiration timestamp (0 for no expiration)
     * @param evidenceHash Hash of evidence supporting this credential
     * @return tokenId The ID of the newly minted credential NFT
     */
    function issueCredential(
        address subject,
        string memory name,
        string memory description,
        string memory metadataURI,
        CredentialType credentialType,
        uint256 validUntil,
        bytes32 evidenceHash
    ) 
        external
        whenNotPaused
        onlyIssuer
        returns (uint256 tokenId)
    {
        require(profileModule.profileExists(subject), "CredentialVerification: subject has no profile");
        
        // Construct JSON metadata (to be stored as tokenURI)
        string memory jsonMetadata = constructTokenURI(
            name,
            description,
            metadataURI,
            subject,
            msg.sender,
            uint8(credentialType),
            validUntil
        );
        
        // Mint the NFT
        tokenId = credentialNFT.mintCredential(
            subject,
            msg.sender,
            jsonMetadata,
            uint8(credentialType),
            validUntil,
            evidenceHash
        );
        
        // Record initial verification status
        _verificationHistory[tokenId].push(VerificationRecord({
            timestamp: block.timestamp,
            verifier: msg.sender,
            status: CredentialStatus.PENDING,
            notes: "Credential issued"
        }));
        
        emit CredentialSubmitted(tokenId, subject, msg.sender);
        
        return tokenId;
    }
    
    /**
     * @dev Change verification status of a credential
     * @param tokenId Token ID to update
     * @param status New status (VERIFIED or REJECTED)
     * @param notes Additional notes about verification
     */
    function verifyCredential(
        uint256 tokenId,
        CredentialStatus status,
        string memory notes
    ) 
        external
        whenNotPaused
        onlyIssuer
    {
        require(
            status == CredentialStatus.VERIFIED || 
            status == CredentialStatus.REJECTED,
            "CredentialVerification: invalid status for verification"
        );
        
        // Get metadata to check issuer
        CredentialNFT.CredentialMetadata memory metadata = credentialNFT.getCredentialMetadata(tokenId);
        
        // Only issuer or admin can verify
        require(
            metadata.issuer == msg.sender || 
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "CredentialVerification: caller is not issuer or admin"
        );
        
        // Update NFT status
        credentialNFT.updateVerificationStatus(tokenId, uint8(status));
        
        // Record in verification history
        _verificationHistory[tokenId].push(VerificationRecord({
            timestamp: block.timestamp,
            verifier: msg.sender,
            status: status,
            notes: notes
        }));
        
        emit CredentialVerified(tokenId, msg.sender, status);
    }
    
    /**
     * @dev Revoke a credential
     * @param tokenId Token ID to revoke
     * @param reason Reason for revocation
     */
    function revokeCredential(
        uint256 tokenId,
        string memory reason
    ) 
        external
        whenNotPaused
    {
        // Get metadata to check issuer
        CredentialNFT.CredentialMetadata memory metadata = credentialNFT.getCredentialMetadata(tokenId);
        
        // Only issuer or admin can revoke
        require(
            metadata.issuer == msg.sender || 
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "CredentialVerification: caller is not issuer or admin"
        );
        
        // Revoke credential
        credentialNFT.revokeCredential(tokenId, reason);
        
        // Record in verification history
        _verificationHistory[tokenId].push(VerificationRecord({
            timestamp: block.timestamp,
            verifier: msg.sender,
            status: CredentialStatus.REVOKED,
            notes: reason
        }));
        
        emit CredentialRevoked(tokenId, msg.sender, reason);
    }
    
    /**
     * @dev Get verification history for a credential
     * @param tokenId Token ID to query
     * @return Array of verification records
     */
    function getVerificationHistory(uint256 tokenId) 
        external 
        view 
        returns (VerificationRecord[] memory) 
    {
        return _verificationHistory[tokenId];
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
    
    /**
     * @dev Utility function to construct token URI JSON
     */
    function constructTokenURI(
        string memory name,
        string memory description,
        string memory metadataURI,
        address subject,
        address issuer,
        uint8 credentialType,
        uint256 validUntil
    ) 
        internal 
        pure 
        returns (string memory) 
    {
        // In a real implementation, we would construct proper JSON
        // For simplicity, we're just storing the metadataURI as is
        return metadataURI;
    }
}