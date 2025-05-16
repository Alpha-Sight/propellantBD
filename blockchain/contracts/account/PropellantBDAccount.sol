// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IAccount.sol";
import "../interfaces/UserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../modules/UserProfileModule.sol";

/**
 * @title PropellantBD Account
 * @dev Smart contract wallet implementation for PropellantBD users.
 * Based on ERC-4337 BaseAccount with integration to the PropellantBD profile system.
 */
contract PropellantBDAccount is BaseAccount, Initializable {
    using ECDSA for bytes32; // Define usage of ECDSA for bytes32
    using Address for address;

    // The owner of this account
    address private _owner;
    
    // Reference to the PropellantBD UserProfileModule
    UserProfileModule private immutable _profileModule;
    
    // Whether the account has been initialized with a profile
    bool private _profileInitialized;
    
    // Events
    event ProfileLinked(address account, address owner);
    event AccountInitialized(address indexed account, address indexed owner);
    event OwnerUpdated(address indexed previousOwner, address indexed newOwner);
    
    /**
     * @dev Only owner modifier
     */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Sender not an owner");
        _;
    }
    
    /**
     * @dev EntryPoint modifier
     */
    modifier onlyEntryPoint() {
        require(msg.sender == address(entryPoint()), "Only EntryPoint");
        _;
    }
    
    /**
     * @dev Constructor for the PropellantBD account
     * @param entryPointAddr The EntryPoint contract address
     * @param profileModuleAddr The UserProfileModule contract address
     */
    constructor(IEntryPoint entryPointAddr, UserProfileModule profileModuleAddr) 
        BaseAccount(entryPointAddr)
    {
        require(address(profileModuleAddr) != address(0), "PropellantBDAccount: profile module is zero address");
        _profileModule = profileModuleAddr;
    }
    
    /**
     * @dev Initialize the account with an owner
     * @param ownerAddr The owner's address
     */
    function initialize(address ownerAddr) public initializer {
        require(ownerAddr != address(0), "PropellantBDAccount: zero owner");
        _owner = ownerAddr;
        emit OwnerUpdated(address(0), ownerAddr);
    }
    
    /**
     * @dev Initialize the account with a profile
     * @param name User's display name
     * @param bio User's bio description
     * @param email User's email
     * @param avatar User's avatar IPFS hash
     */
    function initializeWithProfile(
        string memory name,
        string memory bio,
        string memory email,
        string memory avatar
    ) 
        external 
        onlyOwner 
    {
        require(!_profileInitialized, "PropellantBDAccount: profile already initialized");
        
        // Create a profile for the owner
        _profileModule.createProfile(name, bio, email, avatar);
        
        _profileInitialized = true;
        
        emit ProfileLinked(address(this), _owner);
    }
    
    /**
     * @dev Implements the ERC-4337 validation logic
     */
    function _validateSignature(
        UserOperation calldata userOp, 
        bytes32 userOpHash
    ) 
        internal 
        virtual 
        override 
        returns (uint256) 
    {
        // Use MessageHashUtils for toEthSignedMessageHash
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        
        // If signer is owner, return 0 (valid signature)
        if (_owner == ECDSA.recover(hash, userOp.signature)) {
            return 0;
        }
        // Otherwise return 1 (invalid signature)
        return 1;
    }
    
    /**
     * @dev Returns the owner of this account
     */
    function owner() public view returns (address) {
        return _owner;
    }
    
    /**
     * @dev Checks if the account has an associated profile
     * @return True if the account has a profile, false otherwise
     */
    function hasProfile() external view returns (bool) {
        return _profileInitialized && _profileModule.profileExists(_owner);
    }
    
    /**
     * @dev Returns the profile module address
     * @return The UserProfileModule contract address
     */
    function profileModule() external view returns (address) {
        return address(_profileModule);
    }
    
    /**
     * @dev Updates an existing profile linked to this account
     * @param name New display name
     * @param bio New bio description
     * @param avatar New avatar IPFS hash
     */
    function updateProfile(
        string memory name,
        string memory bio,
        string memory avatar
    ) 
        external 
        onlyOwner 
    {
        require(_profileInitialized, "PropellantBDAccount: profile not initialized");
        
        // Update the owner's profile
        _profileModule.updateProfile(name, bio, avatar);
    }
    
    /**
     * @dev Adds a social handle to the user's profile
     * @param platform Social platform name
     * @param handle User's handle on the platform
     */
    function addSocialHandle(string memory platform, string memory handle) 
        external 
        onlyOwner 
    {
        require(_profileInitialized, "PropellantBDAccount: profile not initialized");
        
        _profileModule.addSocialHandle(platform, handle);
    }
    
    /**
     * @dev Removes a social handle from the user's profile
     * @param platform Social platform to remove
     */
    function removeSocialHandle(string memory platform) 
        external 
        onlyOwner 
    {
        require(_profileInitialized, "PropellantBDAccount: profile not initialized");
        
        _profileModule.removeSocialHandle(platform);
    }
    
    /**
     * @dev Execute a transaction
     * @param target Target address to call
     * @param value Ether value to send
     * @param data Call data to send
     */
    function execute(address target, uint256 value, bytes calldata data) 
        external 
        onlyEntryPoint 
        returns (bytes memory result) 
    {
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        if (!success) {
            // If the call failed, revert with the error message if any
            if (returndata.length > 0) {
                // The assembly block extracts the revert reason from returndata
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("PropellantBDAccount: execution failed");
            }
        }
        return returndata;
    }
    
    /**
     * @dev Execute a batch of transactions
     * @param calls Array of call structs (target, value, data)
     */
    function executeBatch(
        Call[] calldata calls
    ) 
        external 
        onlyEntryPoint 
    {
        for (uint256 i = 0; i < calls.length; i++) {
            Call calldata call = calls[i];
            (bool success, bytes memory result) = call.target.call{value: call.value}(call.data);
            
            // Replace verifyCallResult with direct error handling
            if (!success) {
                // If there's return data, it contains the revert reason
                if (result.length > 0) {
                    assembly {
                        let returndata_size := mload(result)
                        revert(add(32, result), returndata_size)
                    }
                } else {
                    revert("PropellantBDAccount: batch execution failed");
                }
            }
        }
    }
    
    /**
     * @dev struct for batched transactions
     */
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }
    
    /**
     * @dev Enable receiving ETH
     */
    receive() external payable {}
}