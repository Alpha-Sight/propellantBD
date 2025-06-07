// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../modules/RoleModule.sol";
import "../modules/UserProfileModule.sol";

/**
 * @title CredentialNFT
 * @dev ERC721 implementation for PropellantBD credential certificates
 */
contract CredentialNFT is ERC721URIStorage, ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    
    // Token ID counter
    Counters.Counter private _tokenIdCounter;
    
    // Reference to the roles module
    RoleModule private immutable _roleModule;
    
    // Reference to user profile module
    UserProfileModule private immutable _userProfileModule;
    
    // Role constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Credential metadata struct
    struct CredentialMetadata {
        address issuer;
        uint8 credentialType;
        uint256 issuedAt;
        uint256 validUntil;
        uint8 verificationStatus; // 0: Pending, 1: Verified, 2: Rejected, 3: Revoked
        bytes32 evidenceHash;
    }
    
    // Mapping from token ID to credential metadata
    mapping(uint256 => CredentialMetadata) private _credentialMetadata;
    
    // Mapping from subject address to their token IDs
    mapping(address => uint256[]) private _subjectCredentials;
    
    // Mapping from issuer address to their issued token IDs
    mapping(address => uint256[]) private _issuerCredentials;
    
    // Events
    event CredentialMinted(uint256 indexed tokenId, address indexed issuer, address indexed subject);
    event CredentialVerificationChanged(uint256 indexed tokenId, uint8 status, address verifier);
    event CredentialRevoked(uint256 indexed tokenId, address revoker, string reason);
    
    /**
     * @dev Constructor
     * @param roleModuleAddr Address of the RoleModule contract
     * @param userProfileModuleAddr Address of the UserProfileModule contract
     */
    constructor(
        address roleModuleAddr,
        address userProfileModuleAddr
    ) ERC721("PropellantBD Credential", "PBDCRED") {
        require(roleModuleAddr != address(0), "CredentialNFT: roleModule is zero address");
        require(userProfileModuleAddr != address(0), "CredentialNFT: userProfileModule is zero address");
        
        _roleModule = RoleModule(roleModuleAddr);
        _userProfileModule = UserProfileModule(userProfileModuleAddr);
        
        // Setup roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }
    
    /**
     * @dev Mint a new credential NFT
     * @param subject Address that will own the credential
     * @param issuer Address that issues the credential
     * @param tokenURI URI for token metadata
     * @param credentialType Type of credential
     * @param validUntil Expiration timestamp (0 for no expiration)
     * @param evidenceHash Hash of evidence supporting this credential
     * @return tokenId The ID of the newly minted token
     */
    function mintCredential(
        address subject,
        address issuer,
        string memory tokenURI,
        uint8 credentialType,
        uint256 validUntil,
        bytes32 evidenceHash
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(_userProfileModule.profileExists(subject), "CredentialNFT: subject has no profile");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(subject, tokenId);
        _setTokenURI(tokenId, tokenURI);
        
        _credentialMetadata[tokenId] = CredentialMetadata({
            issuer: issuer,
            credentialType: credentialType,
            issuedAt: block.timestamp,
            validUntil: validUntil,
            verificationStatus: 0, // Pending
            evidenceHash: evidenceHash
        });
        
        _subjectCredentials[subject].push(tokenId);
        _issuerCredentials[issuer].push(tokenId);
        
        emit CredentialMinted(tokenId, issuer, subject);
        
        return tokenId;
    }
    
    /**
     * @dev Update verification status of a credential
     * @param tokenId Token ID to update
     * @param status New verification status (1: Verified, 2: Rejected, 3: Revoked)
     */
    function updateVerificationStatus(uint256 tokenId, uint8 status) 
        external 
        onlyRole(MINTER_ROLE) 
    {
        require(_exists(tokenId), "CredentialNFT: nonexistent token");
        require(status > 0 && status <= 3, "CredentialNFT: invalid status");
        
        _credentialMetadata[tokenId].verificationStatus = status;
        
        emit CredentialVerificationChanged(tokenId, status, msg.sender);
    }
    
    /**
     * @dev Revoke a credential NFT
     * @param tokenId Token ID to revoke
     * @param reason Reason for revocation
     */
    function revokeCredential(uint256 tokenId, string memory reason) 
        external 
    {
        require(_exists(tokenId), "CredentialNFT: nonexistent token");
        require(
            _credentialMetadata[tokenId].issuer == msg.sender || 
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "CredentialNFT: caller is not issuer or admin"
        );
        
        _credentialMetadata[tokenId].verificationStatus = 3; // Revoked
        
        emit CredentialRevoked(tokenId, msg.sender, reason);
    }
    
    /**
     * @dev Get metadata for a specific credential
     * @param tokenId Token ID to query
     * @return Credential metadata
     */
    function getCredentialMetadata(uint256 tokenId) 
        external 
        view 
        returns (CredentialMetadata memory) 
    {
        require(_exists(tokenId), "CredentialNFT: nonexistent token");
        return _credentialMetadata[tokenId];
    }
    
    /**
     * @dev Get all credential IDs owned by a subject
     * @param subject Address to query
     * @return Array of token IDs
     */
    function getSubjectCredentials(address subject) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return _subjectCredentials[subject];
    }
    
    /**
     * @dev Get all credential IDs issued by an issuer
     * @param issuer Address to query
     * @return Array of token IDs
     */
    function getIssuerCredentials(address issuer) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return _issuerCredentials[issuer];
    }
    
    /**
     * @dev Check if a credential is valid (verified and not expired)
     * @param tokenId Token ID to check
     * @return True if valid, false otherwise
     */
    function isCredentialValid(uint256 tokenId) 
        external 
        view 
        returns (bool) 
    {
        require(_exists(tokenId), "CredentialNFT: nonexistent token");
        
        CredentialMetadata memory metadata = _credentialMetadata[tokenId];
        
        // Status must be VERIFIED (1)
        if (metadata.verificationStatus != 1) {
            return false;
        }
        
        // Check expiration
        if (metadata.validUntil > 0 && block.timestamp > metadata.validUntil) {
            return false;
        }
        
        return true;
    }
    
    // Override required functions for compatibility with both ERC721 extensions
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        
        // If this is a transfer (not minting or burning)
        if (from != address(0) && to != address(0)) {
            // Remove from old owner's list
            uint256[] storage fromCredentials = _subjectCredentials[from];
            for (uint i = 0; i < fromCredentials.length; i++) {
                if (fromCredentials[i] == tokenId) {
                    // Swap with the last element and pop
                    fromCredentials[i] = fromCredentials[fromCredentials.length - 1];
                    fromCredentials.pop();
                    break;
                }
            }
            
            // Add to new owner's list
            _subjectCredentials[to].push(tokenId);
        }
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}