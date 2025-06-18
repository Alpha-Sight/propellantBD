// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title CredentialNFT
 * @dev ERC721 implementation for PropellantBD credential certificates
 */
contract CredentialNFT is ERC721URIStorage, ERC721Enumerable, AccessControl {
    // Replace Counters with simple uint256
    uint256 private _tokenIdCounter;
    
    // Role constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Credential metadata struct
    struct CredentialMetadata {
        address issuer;
        address subject;
        string name;
        string description;
        uint8 credentialType;
        uint256 validUntil;
        bytes32 evidenceHash;
        bool revocable;
    }
    
    // Token ID to metadata mapping
    mapping(uint256 => CredentialMetadata) private _credentialMetadata;
    
    // Events
    event CredentialMinted(uint256 indexed tokenId, address indexed issuer, address indexed subject);
    event CredentialRevoked(uint256 indexed tokenId, address indexed revoker);
    
    /**
     * @dev Constructor
     */
    constructor() ERC721("PropellantBD Credential", "PBDC") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    /**
     * @dev Mint a new credential NFT
     */
    function mint(
        address to,
        string memory name,
        string memory description,
        string memory _tokenURI,
        uint8 credentialType,
        uint256 validUntil,
        bytes32 evidenceHash,
        bool revocable
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        _credentialMetadata[tokenId] = CredentialMetadata({
            issuer: msg.sender,
            subject: to,
            name: name,
            description: description,
            credentialType: credentialType,
            validUntil: validUntil,
            evidenceHash: evidenceHash,
            revocable: revocable
        });
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        
        emit CredentialMinted(tokenId, msg.sender, to);
        
        return tokenId;
    }
    
    // Override required functions and other methods...
    
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId) 
        public 
        view 
        override(ERC721, ERC721URIStorage) 
        returns (string memory) 
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721Enumerable, ERC721URIStorage, AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}