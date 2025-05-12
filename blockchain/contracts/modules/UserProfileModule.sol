// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../base/AccessControl.sol";
import "../base/Pausable.sol";
import "../base/Upgradeable.sol";
import "./RoleModule.sol";

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