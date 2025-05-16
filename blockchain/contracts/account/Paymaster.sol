// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IPaymaster.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../modules/UserProfileModule.sol";
import "../modules/RoleModule.sol";

/**
 * @title PropellantBD Paymaster
 * @dev Paymaster contract that allows sponsoring transactions for PropellantBD users.
 * Supports different sponsorship strategies based on user roles, profiles, and usage limits.
 */
contract PropellantBDPaymaster is BasePaymaster, Ownable {
    // Reference to the PropellantBD UserProfileModule
    UserProfileModule public immutable profileModule;
    
    // Reference to the RoleModule
    RoleModule public immutable roleModule;
    
    // Address of the token used for gas payments (if any)
    IERC20 public immutable token;
    
    // Indicates if the paymaster is currently accepting new operations
    bool public isAcceptingOperations;
    
    // Maximum gas limit for sponsored operations
    uint256 public maxGasLimit;
    
    // Daily sponsorship limit per user in wei
    uint256 public dailySponsorshipLimit;
    
    // Mapping to track daily usage per user address
    mapping(address => uint256) public dailyUsage;
    
    // Mapping to track last usage timestamp per user address
    mapping(address => uint256) public lastUsageTimestamp;
    
    // Role constants from RoleModule
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TALENT_ROLE = keccak256("TALENT_ROLE");
    bytes32 public constant ORGANIZATION_ROLE = keccak256("ORGANIZATION_ROLE");
    
    // Events
    event SponsorshipUsed(address indexed account, uint256 amount);
    event SponsorshipLimitUpdated(uint256 newLimit);
    event MaxGasLimitUpdated(uint256 newLimit);
    event AcceptingOperationsUpdated(bool isAccepting);
    
    /**
     * @dev Constructor for the PropellantBD Paymaster
     * @param _entryPoint The EntryPoint contract address
     * @param _profileModule The UserProfileModule contract address
     * @param _roleModule The RoleModule contract address
     * @param _token Address of the ERC20 token used for gas payments (use address(0) for native token)
     */
    constructor(
        IEntryPoint _entryPoint,
        UserProfileModule _profileModule,
        RoleModule _roleModule,
        IERC20 _token
    ) 
        BasePaymaster(_entryPoint)
        Ownable(msg.sender) // Fix: Pass msg.sender as initialOwner to Ownable
    {
        require(address(_profileModule) != address(0), "Paymaster: profileModule is zero address");
        require(address(_roleModule) != address(0), "Paymaster: roleModule is zero address");
        
        profileModule = _profileModule;
        roleModule = _roleModule;
        token = _token;
        
        isAcceptingOperations = true;
        maxGasLimit = 1_000_000;  // 1M gas units
        dailySponsorshipLimit = 0.01 ether;  // 0.01 native token per day
    }
    
    /**
     * @dev Validates a user operation request for sponsorship
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) 
        internal 
        override 
        returns (bytes memory context, uint256 validationData) 
    {
        // Check if the paymaster is accepting new operations
        require(isAcceptingOperations, "Paymaster: not accepting operations");
        
        // Extract the sender from the userOp
        address sender = userOp.sender;
        
        // Validate gas limits
        require(userOp.callGasLimit + userOp.verificationGasLimit + userOp.preVerificationGas <= maxGasLimit, 
                "Paymaster: gas limit too high");
        
        // Check if the sender has a profile
        require(profileModule.profileExists(sender), "Paymaster: sender has no profile");
        
        // Reset daily usage if it's a new day
        if (block.timestamp - lastUsageTimestamp[sender] >= 1 days) {
            dailyUsage[sender] = 0;
        }
        
        // Check if the daily limit is not exceeded
        require(dailyUsage[sender] + maxCost <= dailySponsorshipLimit, "Paymaster: daily limit exceeded");
        
        // Update usage tracking
        dailyUsage[sender] += maxCost;
        lastUsageTimestamp[sender] = block.timestamp;
        
        // Pack the sender address into the context for use in postOp
        context = abi.encode(sender, maxCost);
        
        // Return validationData (no time range, valid signature)
        return (context, 0);
    }
    
    /**
     * @dev Post-operation handling, called after the user operation has been executed
     */
    function _postOp(
        IEntryPoint.PostOpMode mode,  // FIXED: Added IEntryPoint namespace
        bytes calldata context,
        uint256 actualGasCost
    ) 
        internal 
        override 
    {
        // Extract sender and maxCost from context
        (address sender, uint256 maxCost) = abi.decode(context, (address, uint256));
        
        // If the operation reverted, we might need to refund some of the daily usage
        if (mode == IEntryPoint.PostOpMode.opReverted) {  // FIXED: Added IEntryPoint namespace
            // In case of revert, we still charge for the validation gas but not the execution gas
            // This is a simplified approach - in production, you might want a more precise calculation
            uint256 refund = maxCost - actualGasCost;
            if (refund > 0) {
                dailyUsage[sender] -= refund;
            }
        }
        
        emit SponsorshipUsed(sender, actualGasCost);
    }
    
    /**
     * @dev Updates the daily sponsorship limit
     * @param newLimit The new daily limit in wei
     */
    function setDailySponsorshipLimit(uint256 newLimit) external onlyOwner {
        dailySponsorshipLimit = newLimit;
        emit SponsorshipLimitUpdated(newLimit);
    }
    
    /**
     * @dev Updates the maximum gas limit for operations
     * @param newLimit The new gas limit
     */
    function setMaxGasLimit(uint256 newLimit) external onlyOwner {
        maxGasLimit = newLimit;
        emit MaxGasLimitUpdated(newLimit);
    }
    
    /**
     * @dev Toggles whether the paymaster is accepting new operations
     * @param accepting The new accepting state
     */
    function setAcceptingOperations(bool accepting) external onlyOwner {
        isAcceptingOperations = accepting;
        emit AcceptingOperationsUpdated(accepting);
    }
    
    /**
     * @dev Deposits funds to the EntryPoint contract
     */
    function deposit() public payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }
    
    /**
     * @dev Withdraws funds from the EntryPoint contract
     * @param amount The amount to withdraw
     */
    function withdrawFromEntryPoint(uint256 amount) external onlyOwner {
        entryPoint.withdrawTo(payable(owner()), amount);
    }
}