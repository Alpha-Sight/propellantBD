// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./AccessControl.sol";

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