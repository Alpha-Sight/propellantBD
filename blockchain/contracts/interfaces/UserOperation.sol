// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/**
 * @title UserOperation struct
 * @dev Defines the user operation structure as specified by ERC-4337
 */
struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}