// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@account-abstraction/contracts/core/EntryPoint.sol";

/**
 * @title PropellantBD EntryPoint
 * @dev This contract serves as the entry point for all UserOperations in the PropellantBD ecosystem.
 * It extends the standard ERC-4337 EntryPoint implementation with minimal modifications to ensure
 * maximum compatibility with the ERC-4337 standard.
 * 
 * The EntryPoint is responsible for:
 * - Validating UserOperations
 * - Executing transactions after validation
 * - Managing gas payments and refunds
 * - Interfacing with bundlers, accounts, and paymasters
 */
contract PropellantBDEntryPoint is EntryPoint {
    // Version identifier for this implementation
    string public constant PROPELLANT_BD_VERSION = "1.0.0";
    
    // We use the constructor from the parent EntryPoint contract
    constructor() EntryPoint() {}
    
    /**
     * @dev Returns the version of the PropellantBD EntryPoint implementation
     * @return The version string
     */
    function version() external pure returns (string memory) {
        return PROPELLANT_BD_VERSION;
    }
}