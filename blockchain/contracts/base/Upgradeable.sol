// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./AccessControl.sol";

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