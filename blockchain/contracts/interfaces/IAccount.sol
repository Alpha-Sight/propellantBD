// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./UserOperation.sol";
import "./IEntryPoint.sol";

/**
 * @title IAccount Interface
 * @dev Base account interface as specified by ERC-4337
 */
interface IAccount {
    /**
     * @dev Validate user operation
     * @param userOp User operation to validate
     * @param userOpHash Hash of the user operation
     * @param missingAccountFunds Missing funds on the account
     * @return validationData Encoded validation result
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

/**
 * @title BaseAccount Abstract Contract
 * @dev Basic ERC-4337 implementation
 */
abstract contract BaseAccount is IAccount {
    IEntryPoint private immutable _entryPoint;

    /**
     * @dev Constructor for BaseAccount
     * @param anEntryPoint The EntryPoint contract
     */
    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
    }

    /**
     * @dev Return the EntryPoint for this account
     */
    function entryPoint() public view virtual returns (IEntryPoint) {
        return _entryPoint;
    }

    /**
     * @dev Validation logic for user operations
     * @param userOp User operation to validate
     * @param userOpHash Hash of the user operation
     * @return validationData Encoded validation result
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external virtual override returns (uint256 validationData) {
        address sender = msg.sender;
        require(sender == address(entryPoint()), "Account: not from EntryPoint");
        
        // Pay prefund (missing gas) if needed
        if (missingAccountFunds > 0) {
            (bool success,) = payable(sender).call{value: missingAccountFunds}("");
            (success); // silence unused variable warning
            // If transfer fails, validateUserOp will revert
        }
        
        return _validateSignature(userOp, userOpHash);
    }
    
    /**
     * @dev Internal validation of signature
     * @param userOp User operation to validate
     * @param userOpHash Hash of the user operation 
     * @return validationData 0 if signature is valid, 1 if invalid
     */
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual returns (uint256);
}