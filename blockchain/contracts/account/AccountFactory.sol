// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./PropellantBDAccount.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../modules/UserProfileModule.sol";

/**
 * @title PropellantBD AccountFactory
 * @dev Factory contract for creating PropellantBD smart contract wallets.
 * Supports counterfactual deployment of accounts (predict the address before actual deployment).
 */
contract PropellantBDAccountFactory is Ownable {
    // The EntryPoint contract reference
    IEntryPoint public immutable entryPoint;
    
    // The UserProfileModule contract reference
    UserProfileModule public immutable profileModule;
    
    // Mapping from owner address to their account address
    mapping(address => address) public getAccount;
    
    // Events
    event AccountCreated(address indexed account, address indexed owner);
    event AccountInitialized(address indexed account, address indexed owner);
    
    /**
     * @dev Constructor for the factory
     * @param _entryPoint The EntryPoint contract address
     * @param _profileModule The UserProfileModule contract address
     */
    constructor(IEntryPoint _entryPoint, UserProfileModule _profileModule) {
        require(address(_entryPoint) != address(0), "AccountFactory: entryPoint is zero address");
        require(address(_profileModule) != address(0), "AccountFactory: profileModule is zero address");
        
        entryPoint = _entryPoint;
        profileModule = _profileModule;
    }
    
    /**
     * @dev Creates a new account for an owner
     * @param owner The owner address of the new account
     * @param salt Additional salt for address calculation
     * @return account The address of the newly created account
     */
    function createAccount(address owner, uint256 salt) public returns (PropellantBDAccount account) {
        address addr = getAccountAddress(owner, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return PropellantBDAccount(payable(addr));
        }
        
        account = new PropellantBDAccount{salt: bytes32(salt)}(entryPoint, profileModule);
        account.initialize(owner);
        
        getAccount[owner] = address(account);
        
        emit AccountCreated(address(account), owner);
    }
    
    /**
     * @dev Creates a new account and initializes it with a profile in one transaction
     * @param owner The owner address of the new account
     * @param salt Additional salt for address calculation
     * @param name User's display name
     * @param bio User's bio description
     * @param email User's email
     * @param avatar User's avatar IPFS hash
     * @return account The address of the newly created account
     */
    function createAccountWithProfile(
        address owner,
        uint256 salt,
        string memory name,
        string memory bio,
        string memory email,
        string memory avatar
    ) external returns (PropellantBDAccount account) {
        account = createAccount(owner, salt);
        
        // Initialize the profile
        account.initializeWithProfile(name, bio, email, avatar);
        
        emit AccountInitialized(address(account), owner);
        
        return account;
    }
    
    /**
     * @dev Calculate the counterfactual address of an account
     * @param owner The owner address of the account
     * @param salt Additional salt for address calculation
     * @return The counterfactual address of the account
     */
    function getAccountAddress(address owner, uint256 salt) public view returns (address) {
        return Create2.computeAddress(
            bytes32(salt),
            keccak256(
                abi.encodePacked(
                    type(PropellantBDAccount).creationCode,
                    abi.encode(entryPoint, profileModule)
                )
            )
        );
    }
}