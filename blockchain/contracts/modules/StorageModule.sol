// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../base/AccessControl.sol";
import "../base/Pausable.sol";
import "../base/Upgradeable.sol";
import "./RoleModule.sol";

/**
 * @title StorageModule
 * @dev Contract module for managing IPFS storage references in the PropellantBD ecosystem.
 * Handles storage of IPFS hashes, access control, and ownership tracking.
 */
contract StorageModule is AccessControl, Pausable, Upgradeable {
    // Role constants (imported from RoleModule)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TALENT_ROLE = keccak256("TALENT_ROLE");
    bytes32 public constant ORGANIZATION_ROLE = keccak256("ORGANIZATION_ROLE");
    
    // Reference to RoleModule for role checks
    RoleModule private _roleModule;
    
    // Storage item types
    enum StorageType {
        PROFILE_DATA,
        CREDENTIAL,
        PORTFOLIO,
        DOCUMENT,
        OTHER
    }
    
    // Access level
    enum AccessLevel {
        PRIVATE,      // Only owner can access
        RESTRICTED,   // Owner and specific addresses
        ROLE_BASED,   // Owner and users with specific roles
        PUBLIC        // Anyone can access
    }
    
    // Storage content structure
    struct StorageItem {
        bytes32 id;
        address owner;
        string ipfsHash;
        string name;
        string description;
        StorageType storageType;
        AccessLevel accessLevel;
        uint256 creationTime;
        uint256 lastUpdateTime;
        bool active;
    }
    
    // Mappings for storage data
    mapping(bytes32 => StorageItem) private _storageItems;
    mapping(address => bytes32[]) private _userStorageItems;
    mapping(bytes32 => address[]) private _itemSpecificAccess;
    mapping(bytes32 => bytes32[]) private _itemAllowedRoles;
    
    // Events
    event StorageItemAdded(bytes32 indexed id, address indexed owner, string ipfsHash, StorageType storageType);
    event StorageItemUpdated(bytes32 indexed id, string ipfsHash);
    event StorageItemAccessChanged(bytes32 indexed id, AccessLevel accessLevel);
    event StorageItemAccessGranted(bytes32 indexed id, address indexed user);
    event StorageItemAccessRevoked(bytes32 indexed id, address indexed user);
    event StorageItemRoleAccessGranted(bytes32 indexed id, bytes32 indexed role);
    event StorageItemRoleAccessRevoked(bytes32 indexed id, bytes32 indexed role);
    event StorageItemDeactivated(bytes32 indexed id);
    event StorageItemReactivated(bytes32 indexed id);
    
    /**
     * @dev Modifier to ensure the caller is the storage item owner or an admin
     */
    modifier onlyItemOwnerOrAdmin(bytes32 id) {
        require(
            _storageItems[id].owner == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "StorageModule: caller is not item owner or admin"
        );
        _;
    }
    
    /**
     * @dev Modifier to check if the caller has access to the storage item
     */
    modifier hasAccess(bytes32 id) {
        require(_hasAccess(id, msg.sender), "StorageModule: caller doesn't have access");
        _;
    }
    
    /**
     * @dev Constructor that sets the role module address
     */
    constructor(address payable roleModuleAddress) {
        require(roleModuleAddress != address(0), "StorageModule: role module address is zero");
        _roleModule = RoleModule(roleModuleAddress);
    }
    
    /**
     * @dev Adds a new storage item
     * @param ipfsHash IPFS hash of the content
     * @param name Display name for the content
     * @param description Brief description of the content
     * @param storageType Type of content being stored
     * @param accessLevel Initial access level
     */
    function addStorageItem(
        string memory ipfsHash,
        string memory name,
        string memory description,
        StorageType storageType,
        AccessLevel accessLevel
    ) 
        external 
        whenNotPaused 
        returns (bytes32)
    {
        require(bytes(ipfsHash).length > 0, "StorageModule: ipfsHash cannot be empty");
        
        // Generate a unique ID for the storage item
        bytes32 id = keccak256(abi.encodePacked(msg.sender, ipfsHash, block.timestamp));
        
        // Ensure the ID is unique
        require(_storageItems[id].creationTime == 0, "StorageModule: ID collision - try again");
        
        // Create and store the new item
        _storageItems[id] = StorageItem({
            id: id,
            owner: msg.sender,
            ipfsHash: ipfsHash,
            name: name,
            description: description,
            storageType: storageType,
            accessLevel: accessLevel,
            creationTime: block.timestamp,
            lastUpdateTime: block.timestamp,
            active: true
        });
        
        // Add to user's storage items
        _userStorageItems[msg.sender].push(id);
        
        emit StorageItemAdded(id, msg.sender, ipfsHash, storageType);
        
        return id;
    }
    
    /**
     * @dev Updates the IPFS hash of an existing storage item
     * @param id ID of the storage item
     * @param ipfsHash New IPFS hash
     */
    function updateStorageItem(bytes32 id, string memory ipfsHash) 
        external 
        whenNotPaused 
        onlyItemOwnerOrAdmin(id) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        require(_storageItems[id].active, "StorageModule: item is not active");
        require(bytes(ipfsHash).length > 0, "StorageModule: ipfsHash cannot be empty");
        
        _storageItems[id].ipfsHash = ipfsHash;
        _storageItems[id].lastUpdateTime = block.timestamp;
        
        emit StorageItemUpdated(id, ipfsHash);
    }
    
    /**
     * @dev Updates the metadata of an existing storage item
     * @param id ID of the storage item
     * @param name New display name
     * @param description New description
     */
    function updateStorageItemMetadata(
        bytes32 id, 
        string memory name, 
        string memory description
    ) 
        external 
        whenNotPaused 
        onlyItemOwnerOrAdmin(id) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        require(_storageItems[id].active, "StorageModule: item is not active");
        
        _storageItems[id].name = name;
        _storageItems[id].description = description;
        _storageItems[id].lastUpdateTime = block.timestamp;
    }
    
    /**
     * @dev Changes the access level of a storage item
     * @param id ID of the storage item
     * @param accessLevel New access level
     */
    function changeAccessLevel(bytes32 id, AccessLevel accessLevel) 
        external 
        whenNotPaused 
        onlyItemOwnerOrAdmin(id) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        
        _storageItems[id].accessLevel = accessLevel;
        _storageItems[id].lastUpdateTime = block.timestamp;
        
        emit StorageItemAccessChanged(id, accessLevel);
    }
    
    /**
     * @dev Grants access to a specific user for a restricted storage item
     * @param id ID of the storage item
     * @param user Address of the user
     */
    function grantAccess(bytes32 id, address user) 
        external 
        whenNotPaused 
        onlyItemOwnerOrAdmin(id) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        require(_storageItems[id].accessLevel == AccessLevel.RESTRICTED, "StorageModule: item is not restricted");
        require(user != address(0), "StorageModule: zero address");
        
        // Add user to access list if not already there
        bool found = false;
        for (uint256 i = 0; i < _itemSpecificAccess[id].length; i++) {
            if (_itemSpecificAccess[id][i] == user) {
                found = true;
                break;
            }
        }
        
        if (!found) {
            _itemSpecificAccess[id].push(user);
            emit StorageItemAccessGranted(id, user);
        }
    }
    
    /**
     * @dev Revokes access from a specific user for a restricted storage item
     * @param id ID of the storage item
     * @param user Address of the user
     */
    function revokeAccess(bytes32 id, address user) 
        external 
        whenNotPaused 
        onlyItemOwnerOrAdmin(id) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        require(_storageItems[id].accessLevel == AccessLevel.RESTRICTED, "StorageModule: item is not restricted");
        
        // Find and remove user from access list
        bool removed = false;
        for (uint256 i = 0; i < _itemSpecificAccess[id].length; i++) {
            if (_itemSpecificAccess[id][i] == user) {
                // Move the last element to this position
                if (i < _itemSpecificAccess[id].length - 1) {
                    _itemSpecificAccess[id][i] = _itemSpecificAccess[id][_itemSpecificAccess[id].length - 1];
                }
                // Remove the last element
                _itemSpecificAccess[id].pop();
                removed = true;
                break;
            }
        }
        
        if (removed) {
            emit StorageItemAccessRevoked(id, user);
        }
    }
    
    /**
     * @dev Grants access to users with a specific role
     * @param id ID of the storage item
     * @param role Role that should have access
     */
    function grantRoleAccess(bytes32 id, bytes32 role) 
        external 
        whenNotPaused 
        onlyItemOwnerOrAdmin(id) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        require(_storageItems[id].accessLevel == AccessLevel.ROLE_BASED, "StorageModule: item is not role-based");
        
        // Add role to allowed roles if not already there
        bool found = false;
        for (uint256 i = 0; i < _itemAllowedRoles[id].length; i++) {
            if (_itemAllowedRoles[id][i] == role) {
                found = true;
                break;
            }
        }
        
        if (!found) {
            _itemAllowedRoles[id].push(role);
            emit StorageItemRoleAccessGranted(id, role);
        }
    }
    
    /**
     * @dev Revokes access from users with a specific role
     * @param id ID of the storage item
     * @param role Role to revoke access from
     */
    function revokeRoleAccess(bytes32 id, bytes32 role) 
        external 
        whenNotPaused 
        onlyItemOwnerOrAdmin(id) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        require(_storageItems[id].accessLevel == AccessLevel.ROLE_BASED, "StorageModule: item is not role-based");
        
        // Find and remove role from allowed roles
        bool removed = false;
        for (uint256 i = 0; i < _itemAllowedRoles[id].length; i++) {
            if (_itemAllowedRoles[id][i] == role) {
                // Move the last element to this position
                if (i < _itemAllowedRoles[id].length - 1) {
                    _itemAllowedRoles[id][i] = _itemAllowedRoles[id][_itemAllowedRoles[id].length - 1];
                }
                // Remove the last element
                _itemAllowedRoles[id].pop();
                removed = true;
                break;
            }
        }
        
        if (removed) {
            emit StorageItemRoleAccessRevoked(id, role);
        }
    }
    
    /**
     * @dev Deactivates a storage item
     * @param id ID of the storage item
     */
    function deactivateStorageItem(bytes32 id) 
        external 
        whenNotPaused 
        onlyItemOwnerOrAdmin(id) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        require(_storageItems[id].active, "StorageModule: item is already deactivated");
        
        _storageItems[id].active = false;
        _storageItems[id].lastUpdateTime = block.timestamp;
        
        emit StorageItemDeactivated(id);
    }
    
    /**
     * @dev Reactivates a storage item
     * @param id ID of the storage item
     */
    function reactivateStorageItem(bytes32 id) 
        external 
        whenNotPaused 
        onlyItemOwnerOrAdmin(id) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        require(!_storageItems[id].active, "StorageModule: item is already active");
        
        _storageItems[id].active = true;
        _storageItems[id].lastUpdateTime = block.timestamp;
        
        emit StorageItemReactivated(id);
    }
    
    /**
     * @dev Gets a storage item's data
     * @param id ID of the storage item
     */
    function getStorageItem(bytes32 id) 
        external 
        view 
        hasAccess(id) 
        returns (
            address owner,
            string memory ipfsHash,
            string memory name,
            string memory description,
            StorageType storageType,
            AccessLevel accessLevel,
            uint256 creationTime,
            uint256 lastUpdateTime,
            bool active
        ) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        
        StorageItem storage item = _storageItems[id];
        return (
            item.owner,
            item.ipfsHash,
            item.name,
            item.description,
            item.storageType,
            item.accessLevel,
            item.creationTime,
            item.lastUpdateTime,
            item.active
        );
    }
    
    /**
     * @dev Gets all storage IDs owned by a user
     * @param user Address of the user
     */
    function getUserStorageItems(address user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return _userStorageItems[user];
    }
    
    /**
     * @dev Gets all addresses with specific access to a storage item
     * @param id ID of the storage item
     */
    function getItemSpecificAccess(bytes32 id) 
        external 
        view 
        onlyItemOwnerOrAdmin(id) 
        returns (address[] memory) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        return _itemSpecificAccess[id];
    }
    
    /**
     * @dev Gets all roles with access to a storage item
     * @param id ID of the storage item
     */
    function getItemRoleAccess(bytes32 id) 
        external 
        view 
        onlyItemOwnerOrAdmin(id) 
        returns (bytes32[] memory) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        return _itemAllowedRoles[id];
    }
    
    /**
     * @dev Checks if an item exists
     * @param id ID of the storage item
     */
    function itemExists(bytes32 id) 
        external 
        view 
        returns (bool) 
    {
        return _storageItems[id].creationTime > 0;
    }
    
    /**
     * @dev Checks if an item is active
     * @param id ID of the storage item
     */
    function isItemActive(bytes32 id) 
        external 
        view 
        hasAccess(id) 
        returns (bool) 
    {
        require(_storageItems[id].creationTime > 0, "StorageModule: item does not exist");
        return _storageItems[id].active;
    }
    
    /**
     * @dev Internal function to check if a user has access to a storage item
     * @param id ID of the storage item
     * @param user Address of the user
     */
    function _hasAccess(bytes32 id, address user) 
        internal 
        view 
        returns (bool) 
    {
        StorageItem storage item = _storageItems[id];
        
        // Item doesn't exist
        if (item.creationTime == 0) {
            return false;
        }
        
        // Owner always has access
        if (item.owner == user) {
            return true;
        }
        
        // Admins always have access
        if (hasRole(ADMIN_ROLE, user)) {
            return true;
        }
        
        // Check access level
        if (item.accessLevel == AccessLevel.PUBLIC) {
            return true;
        } else if (item.accessLevel == AccessLevel.PRIVATE) {
            return false;
        } else if (item.accessLevel == AccessLevel.RESTRICTED) {
            // Check specific access list
            for (uint256 i = 0; i < _itemSpecificAccess[id].length; i++) {
                if (_itemSpecificAccess[id][i] == user) {
                    return true;
                }
            }
            return false;
        } else if (item.accessLevel == AccessLevel.ROLE_BASED) {
            // Check role-based access
            for (uint256 i = 0; i < _itemAllowedRoles[id].length; i++) {
                if (_roleModule.hasRole(_itemAllowedRoles[id][i], user)) {
                    return true;
                }
            }
            return false;
        }
        
        return false;
    }
}