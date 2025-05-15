// Sources flattened with hardhat v2.24.0 https://hardhat.org

// SPDX-License-Identifier: MIT

// File contracts/base/AccessControl.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title AccessControl
 * @dev Contract module that allows children to implement role-based access control mechanisms.
 */
contract AccessControl {
    // Role => Address => Boolean
    mapping(bytes32 => mapping(address => bool)) private _roles;
    
    // Events
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    
    // Roles
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    
    /**
     * @dev Modifier that checks if an account has a specific role.
     */
    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: sender doesn't have role");
        _;
    }
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }
    
    /**
     * @dev Grants `role` to `account`.
     * Only callable by accounts with the DEFAULT_ADMIN_ROLE.
     */
    function grantRole(bytes32 role, address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }
    
    /**
     * @dev Revokes `role` from `account`.
     * Only callable by accounts with the DEFAULT_ADMIN_ROLE.
     */
    function revokeRole(bytes32 role, address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(role, account);
    }
    
    /**
     * @dev Revokes `role` from the calling account.
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     */
    function renounceRole(bytes32 role) public {
        _revokeRole(role, msg.sender);
    }
    
    /**
     * @dev Grants `role` to `account`.
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }
    
    /**
     * @dev Revokes `role` from `account`.
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
}


// File contracts/base/Pausable.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Pausable
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 */
contract Pausable is AccessControl {
    // Paused state
    bool private _paused;
    
    // Role
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Events
    event Paused(address account);
    event Unpaused(address account);
    
    /**
     * @dev Constructor that grants the DEFAULT_ADMIN_ROLE and PAUSER_ROLE to the
     * deployer.
     */
    constructor() {
        _grantRole(PAUSER_ROLE, msg.sender);
    }
    
    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    
    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }
    
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }
    
    /**
     * @dev Triggers stopped state.
     * Requirements:
     * - The contract must not be paused.
     * - The caller must have the PAUSER_ROLE.
     */
    function pause() public whenNotPaused onlyRole(PAUSER_ROLE) {
        _paused = true;
        emit Paused(msg.sender);
    }
    
    /**
     * @dev Returns to normal state.
     * Requirements:
     * - The contract must be paused.
     * - The caller must have the PAUSER_ROLE.
     */
    function unpause() public whenPaused onlyRole(PAUSER_ROLE) {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}


// File contracts/base/Upgradeable.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Upgradeable
 * @dev Contract module that helps make smart contracts upgradeable.
 * It implements a transparent proxy pattern.
 */
contract Upgradeable is AccessControl {
    // Implementation address
    address private _implementation;
    
    // Role
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // Events
    event Upgraded(address indexed implementation);
    
    /**
     * @dev Constructor that grants the DEFAULT_ADMIN_ROLE and UPGRADER_ROLE to the
     * deployer.
     */
    constructor() {
        _grantRole(UPGRADER_ROLE, msg.sender);
    }
    
    /**
     * @dev Returns the current implementation address.
     */
    function implementation() public view returns (address) {
        return _implementation;
    }
    
    /**
     * @dev Upgrades the implementation to a new address.
     * Requirements:
     * - The caller must have the UPGRADER_ROLE.
     * - The new implementation must be a contract.
     */
    function upgradeTo(address newImplementation) public onlyRole(UPGRADER_ROLE) {
        require(newImplementation != address(0), "Upgradeable: zero address implementation");
        require(newImplementation != _implementation, "Upgradeable: same implementation");
        
        // Check that the new implementation is a contract
        uint256 size;
        assembly { size := extcodesize(newImplementation) }
        require(size > 0, "Upgradeable: not a contract");
        
        _implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
    
    /**
     * @dev Fallback function that delegates calls to the implementation.
     * Will run if no other function in the contract matches the call data.
     */
    fallback() external payable {
        _delegate(_implementation);
    }
    
    /**
     * @dev Receive function that delegates calls to the implementation.
     * Will run if calldata is empty.
     */
    receive() external payable {
        _delegate(_implementation);
    }
    
    /**
     * @dev Delegates the current call to `implementation`.
     */
    function _delegate(address implementation_) internal {
        require(implementation_ != address(0), "Upgradeable: implementation not set");
        
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())
            
            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation_, 0, calldatasize(), 0, 0)
            
            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())
            
            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}


// File contracts/modules/RoleModule.sol

// filepath: /home/kingtom/Documents/blockchain/propellantBD/blockchain/contracts/modules/RoleModule.sol
// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.23;



/**
 * @title RoleModule
 * @dev Contract module for managing roles in the PropellantBD ecosystem.
 * Defines Admin, Talent, and Organization roles with specific permissions.
 */
contract RoleModule is AccessControl, Pausable, Upgradeable {
    // Role constants
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TALENT_ROLE = keccak256("TALENT_ROLE");
    bytes32 public constant ORGANIZATION_ROLE = keccak256("ORGANIZATION_ROLE");
    
    // Role metadata
    struct RoleMetadata {
        string name;
        string description;
        uint256 creationTime;
        bool active;
    }
    
    // Mapping from role to role metadata
    mapping(bytes32 => RoleMetadata) private _roleMetadata;
    
    // Mapping from address to roles count
    mapping(address => uint256) private _userRolesCount;
    
    // Events
    event RoleMetadataUpdated(bytes32 indexed role, string name, string description);
    event RoleStatusChanged(bytes32 indexed role, bool active);
    
    /**
     * @dev Constructor that sets up the initial role metadata
     */
    constructor() {
        // Initialize the role metadata
        _setRoleMetadata(
            DEFAULT_ADMIN_ROLE, 
            "Default Admin", 
            "Full access to all functions, can grant and revoke roles",
            true
        );
        
        _setRoleMetadata(
            ADMIN_ROLE, 
            "Admin", 
            "Administrative capabilities for platform management",
            true
        );
        
        _setRoleMetadata(
            TALENT_ROLE, 
            "Talent", 
            "Users providing services and creating profiles",
            true
        );
        
        _setRoleMetadata(
            ORGANIZATION_ROLE, 
            "Organization", 
            "Entities seeking talent and verifying credentials",
            true
        );
        
        // Grant admin role to deployer
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Returns the metadata for a specific role.
     */
    function getRoleMetadata(bytes32 role) public view returns (
        string memory name,
        string memory description,
        uint256 creationTime,
        bool active
    ) {
        RoleMetadata storage metadata = _roleMetadata[role];
        return (
            metadata.name,
            metadata.description,
            metadata.creationTime,
            metadata.active
        );
    }
    
    /**
     * @dev Updates the metadata for a specific role.
     * Requirements:
     * - The caller must have the ADMIN_ROLE.
     */
    function updateRoleMetadata(
        bytes32 role,
        string memory name,
        string memory description,
        bool active
    ) 
        public 
        whenNotPaused 
        onlyRole(ADMIN_ROLE) 
    {
        _setRoleMetadata(role, name, description, active);
    }
    
    /**
     * @dev Grants a role to an account, with additional validation.
     * Requirements:
     * - Role must be active
     * - The caller must have the ADMIN_ROLE.
     */
    function grantRoleSafe(bytes32 role, address account) 
        public 
        whenNotPaused 
        onlyRole(ADMIN_ROLE) 
    {
        require(_roleMetadata[role].active, "RoleModule: role is not active");
        super.grantRole(role, account);
        _userRolesCount[account]++;
    }
    
    /**
     * @dev Revokes a role from an account, with additional accounting.
     * Requirements:
     * - The caller must have the ADMIN_ROLE.
     */
    function revokeRoleSafe(bytes32 role, address account) 
        public 
        whenNotPaused 
        onlyRole(ADMIN_ROLE) 
    {
        super.revokeRole(role, account);
        if (_userRolesCount[account] > 0) {
            _userRolesCount[account]--;
        }
    }
    
    /**
     * @dev Checks if an account has any active role.
     */
    function hasAnyRole(address account) public view returns (bool) {
        return _userRolesCount[account] > 0;
    }
    
    /**
     * @dev Internal function to set role metadata.
     */
    function _setRoleMetadata(
        bytes32 role,
        string memory name,
        string memory description,
        bool active
    ) 
        internal 
    {
        RoleMetadata storage metadata = _roleMetadata[role];

        bool originalActiveStatus = metadata.active;
        
        if (metadata.creationTime == 0) {
            metadata.creationTime = block.timestamp;
        }
        
        metadata.name = name;
        metadata.description = description;
        metadata.active = active;
        
        emit RoleMetadataUpdated(role, name, description);
        
        if (originalActiveStatus != active) {
            emit RoleStatusChanged(role, active);
        }
    }
}


// File contracts/modules/StorageModule.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.23;




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
