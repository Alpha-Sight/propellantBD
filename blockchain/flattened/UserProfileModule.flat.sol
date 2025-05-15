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


// File contracts/modules/UserProfileModule.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.23;




/**
 * @title UserProfileModule
 * @dev Contract module for managing user profiles in the PropellantBD ecosystem.
 * Handles profile storage, social handles, and verification.
 */
contract UserProfileModule is AccessControl, Pausable, Upgradeable {
    // Role constants (imported from RoleModule)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TALENT_ROLE = keccak256("TALENT_ROLE");
    bytes32 public constant ORGANIZATION_ROLE = keccak256("ORGANIZATION_ROLE");
    
    // Reference to RoleModule for role checks
    RoleModule private _roleModule;
    
    // Profile structure
    struct Profile {
        address owner;
        string name;
        string bio;
        string email;
        string avatar;
        uint256 creationTime;
        uint256 lastUpdateTime;
        bool active;
    }
    
    // Social handle structure
    struct SocialHandle {
        string platform;
        string handle;
        bool verified;
        uint256 verificationTime;
        bytes32 verificationHash;
    }
    
    // Mappings for profile data
    mapping(address => Profile) private _profiles;
    mapping(address => SocialHandle[]) private _socialHandles;
    mapping(address => mapping(string => uint256)) private _platformHandleIndex; // Maps platform to index in array
    mapping(string => address) private _emailToAddress;
    
    // Events
    event ProfileCreated(address indexed user, string name, string email);
    event ProfileUpdated(address indexed user, string name, string bio);
    event ProfileDeactivated(address indexed user);
    event ProfileReactivated(address indexed user);
    event SocialHandleAdded(address indexed user, string platform, string handle);
    event SocialHandleVerified(address indexed user, string platform, string handle);
    event SocialHandleRemoved(address indexed user, string platform);
    
    /**
     * @dev Modifier to ensure the caller is the profile owner or an admin
     */
    modifier onlyProfileOwnerOrAdmin(address profileOwner) {
        require(
            msg.sender == profileOwner || hasRole(ADMIN_ROLE, msg.sender),
            "UserProfileModule: caller is not profile owner or admin"
        );
        _;
    }
    
    /**
     * @dev Constructor that sets the role module address
     */
    constructor(address payable roleModuleAddress) {
        require(roleModuleAddress != address(0), "UserProfileModule: role module address is zero");
        _roleModule = RoleModule(roleModuleAddress);
    }
    
    /**
     * @dev Creates a new user profile
     * @param name User's full name
     * @param bio Short biography or description
     * @param email User's email address
     * @param avatar IPFS hash of user's avatar
     */
    function createProfile(
        string memory name,
        string memory bio,
        string memory email,
        string memory avatar
    ) 
        external 
        whenNotPaused 
    {
        require(_profiles[msg.sender].creationTime == 0, "UserProfileModule: profile already exists");
        require(bytes(name).length > 0, "UserProfileModule: name cannot be empty");
        require(bytes(email).length > 0, "UserProfileModule: email cannot be empty");
        require(_emailToAddress[email] == address(0), "UserProfileModule: email already registered");
        
        _profiles[msg.sender] = Profile({
            owner: msg.sender,
            name: name,
            bio: bio,
            email: email,
            avatar: avatar,
            creationTime: block.timestamp,
            lastUpdateTime: block.timestamp,
            active: true
        });
        
        _emailToAddress[email] = msg.sender;
        
        // Give the user a TALENT role by default
        if (!_roleModule.hasRole(TALENT_ROLE, msg.sender)) {
            if (_roleModule.hasRole(ADMIN_ROLE, address(this))) {
                _roleModule.grantRoleSafe(TALENT_ROLE, msg.sender);
            }
        }
        
        emit ProfileCreated(msg.sender, name, email);
    }
    
    /**
     * @dev Updates an existing user profile
     * @param name User's full name
     * @param bio Short biography or description
     * @param avatar IPFS hash of user's avatar
     */
    function updateProfile(
        string memory name,
        string memory bio,
        string memory avatar
    ) 
        external 
        whenNotPaused 
    {
        require(_profiles[msg.sender].creationTime > 0, "UserProfileModule: profile does not exist");
        require(_profiles[msg.sender].active, "UserProfileModule: profile is not active");
        
        Profile storage profile = _profiles[msg.sender];
        
        if (bytes(name).length > 0) {
            profile.name = name;
        }
        
        profile.bio = bio;
        profile.avatar = avatar;
        profile.lastUpdateTime = block.timestamp;
        
        emit ProfileUpdated(msg.sender, name, bio);
    }
    
    /**
     * @dev Deactivates a user profile
     * @param user Address of the profile to deactivate
     */
    function deactivateProfile(address user) 
        external 
        whenNotPaused 
        onlyProfileOwnerOrAdmin(user) 
    {
        require(_profiles[user].creationTime > 0, "UserProfileModule: profile does not exist");
        require(_profiles[user].active, "UserProfileModule: profile already deactivated");
        
        _profiles[user].active = false;
        _profiles[user].lastUpdateTime = block.timestamp;
        
        emit ProfileDeactivated(user);
    }
    
    /**
     * @dev Reactivates a user profile
     * @param user Address of the profile to reactivate
     */
    function reactivateProfile(address user) 
        external 
        whenNotPaused 
        onlyProfileOwnerOrAdmin(user) 
    {
        require(_profiles[user].creationTime > 0, "UserProfileModule: profile does not exist");
        require(!_profiles[user].active, "UserProfileModule: profile already active");
        
        _profiles[user].active = true;
        _profiles[user].lastUpdateTime = block.timestamp;
        
        emit ProfileReactivated(user);
    }
    
    /**
     * @dev Adds a social handle for a user
     * @param platform Social media platform name (e.g., "twitter", "github")
     * @param handle User's handle on that platform
     */
    function addSocialHandle(string memory platform, string memory handle) 
        external 
        whenNotPaused 
    {
        require(_profiles[msg.sender].creationTime > 0, "UserProfileModule: profile does not exist");
        require(_profiles[msg.sender].active, "UserProfileModule: profile is not active");
        require(bytes(platform).length > 0, "UserProfileModule: platform cannot be empty");
        require(bytes(handle).length > 0, "UserProfileModule: handle cannot be empty");
        
        // Check if platform already exists
        if (_platformHandleIndex[msg.sender][platform] > 0) {
            // Update existing handle
            uint256 index = _platformHandleIndex[msg.sender][platform] - 1;
            _socialHandles[msg.sender][index].handle = handle;
            _socialHandles[msg.sender][index].verified = false;
            _socialHandles[msg.sender][index].verificationTime = 0;
            _socialHandles[msg.sender][index].verificationHash = bytes32(0);
        } else {
            // Add new handle
            SocialHandle memory newHandle = SocialHandle({
                platform: platform,
                handle: handle,
                verified: false,
                verificationTime: 0,
                verificationHash: bytes32(0)
            });
            
            _socialHandles[msg.sender].push(newHandle);
            _platformHandleIndex[msg.sender][platform] = _socialHandles[msg.sender].length;
        }
        
        emit SocialHandleAdded(msg.sender, platform, handle);
    }
    
    /**
     * @dev Removes a social handle for a user
     * @param platform Social media platform name to remove
     */
    function removeSocialHandle(string memory platform) 
        external 
        whenNotPaused 
    {
        require(_profiles[msg.sender].creationTime > 0, "UserProfileModule: profile does not exist");
        require(_platformHandleIndex[msg.sender][platform] > 0, "UserProfileModule: platform not found");
        
        uint256 index = _platformHandleIndex[msg.sender][platform] - 1;
        uint256 lastIndex = _socialHandles[msg.sender].length - 1;
        
        // If it's not the last element, move the last element to the removed position
        if (index != lastIndex) {
            SocialHandle memory lastHandle = _socialHandles[msg.sender][lastIndex];
            _socialHandles[msg.sender][index] = lastHandle;
            _platformHandleIndex[msg.sender][lastHandle.platform] = index + 1;
        }
        
        // Remove the last element
        _socialHandles[msg.sender].pop();
        delete _platformHandleIndex[msg.sender][platform];
        
        emit SocialHandleRemoved(msg.sender, platform);
    }
    
    /**
     * @dev Generates a verification hash for social handle verification
     * @param user Address of the user
     * @param platform Social media platform name
     * @param nonce Random nonce for uniqueness
     */
    function generateVerificationHash(address user, string memory platform, uint256 nonce) 
        public 
        view 
        returns (bytes32) 
    {
        require(_profiles[user].creationTime > 0, "UserProfileModule: profile does not exist");
        require(_platformHandleIndex[user][platform] > 0, "UserProfileModule: platform not found");
        
        uint256 index = _platformHandleIndex[user][platform] - 1;
        string memory handle = _socialHandles[user][index].handle;
        
        return keccak256(abi.encodePacked(user, platform, handle, nonce));
    }
    
    /**
     * @dev Verifies a social handle using off-chain verification
     * @param user Address of the user
     * @param platform Social media platform name
     * @param verificationHash Hash that was verified off-chain
     */
    function verifySocialHandle(address user, string memory platform, bytes32 verificationHash) 
        external 
        whenNotPaused 
        onlyRole(ADMIN_ROLE) 
    {
        require(_profiles[user].creationTime > 0, "UserProfileModule: profile does not exist");
        require(_platformHandleIndex[user][platform] > 0, "UserProfileModule: platform not found");
        
        uint256 index = _platformHandleIndex[user][platform] - 1;
        _socialHandles[user][index].verified = true;
        _socialHandles[user][index].verificationTime = block.timestamp;
        _socialHandles[user][index].verificationHash = verificationHash;
        
        emit SocialHandleVerified(user, platform, _socialHandles[user][index].handle);
    }
    
    /**
     * @dev Gets a user's profile data
     * @param user Address of the user
     */
    function getProfile(address user) 
        external 
        view 
        returns (
            string memory name,
            string memory bio,
            string memory email,
            string memory avatar,
            uint256 creationTime,
            uint256 lastUpdateTime,
            bool active
        ) 
    {
        require(_profiles[user].creationTime > 0, "UserProfileModule: profile does not exist");
        
        Profile storage profile = _profiles[user];
        return (
            profile.name,
            profile.bio,
            profile.email,
            profile.avatar,
            profile.creationTime,
            profile.lastUpdateTime,
            profile.active
        );
    }
    
    /**
     * @dev Gets a user's social handles
     * @param user Address of the user
     */
    function getSocialHandles(address user) 
        external 
        view 
        returns (SocialHandle[] memory) 
    {
        require(_profiles[user].creationTime > 0, "UserProfileModule: profile does not exist");
        return _socialHandles[user];
    }
    
    /**
     * @dev Checks if a user has a verified social handle on a specific platform
     * @param user Address of the user
     * @param platform Social media platform name
     */
    function isHandleVerified(address user, string memory platform) 
        external 
        view 
        returns (bool) 
    {
        if (_profiles[user].creationTime == 0 || _platformHandleIndex[user][platform] == 0) {
            return false;
        }
        
        uint256 index = _platformHandleIndex[user][platform] - 1;
        return _socialHandles[user][index].verified;
    }
    
    /**
     * @dev Gets the address associated with an email
     * @param email Email to look up
     */
    function getAddressByEmail(string memory email) 
        external 
        view 
        returns (address) 
    {
        return _emailToAddress[email];
    }
    
    /**
     * @dev Checks if a profile exists
     * @param user Address to check
     */
    function profileExists(address user) 
        external 
        view 
        returns (bool) 
    {
        return _profiles[user].creationTime > 0;
    }
    
    /**
     * @dev Checks if a profile is active
     * @param user Address to check
     */
    function isProfileActive(address user) 
        external 
        view 
        returns (bool) 
    {
        if (_profiles[user].creationTime == 0) {
            return false;
        }
        
        return _profiles[user].active;
    }
}
