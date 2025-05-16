// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./UserOperation.sol";

/**
 * @title IEntryPoint Interface
 * @dev Interface for the EntryPoint contract as specified by ERC-4337
 */
interface IEntryPoint {
    /**
     * @dev Deposit funds for a paymaster or sender address
     */
    function depositTo(address account) external payable;

    /**
     * @dev Withdraw funds from the EntryPoint
     */
    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external;

    /**
     * @dev Get the deposit info for an account
     * @return amount - The deposit amount
     * @return staked - Whether the deposit is staked
     * @return stake - The staked amount
     * @return unstakeDelaySec - The unstake delay in seconds
     * @return withdrawTime - The time when the deposit can be withdrawn
     */
    function getDepositInfo(address account) external view returns (
        uint112 amount,
        bool staked,
        uint112 stake,
        uint32 unstakeDelaySec,
        uint64 withdrawTime
    );

    /**
     * @dev Execution mode for postOp
     */
    enum PostOpMode {
        opSucceeded, // Operation succeeded
        opReverted, // Operation reverted
        postOpReverted // Post operation reverted
    }

    /**
     * @dev Handle user operations
     */
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external;

    /**
     * @dev Get the sender address from a UserOperation
     */
    function getSenderAddress(bytes calldata initCode) external returns (address);
}