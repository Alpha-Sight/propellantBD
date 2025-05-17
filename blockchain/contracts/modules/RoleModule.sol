// filepath: /home/kingtom/Documents/blockchain/propellantBD/blockchain/contracts/modules/RoleModule.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../base/AccessControl.sol";
import "../base/Pausable.sol";
import "../base/Upgradeable.sol";

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