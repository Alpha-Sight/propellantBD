// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./UserOperation.sol";
import "./IEntryPoint.sol";

/**
 * @title IPaymaster Interface
 * @dev Interface for paymasters as specified by ERC-4337
 */
interface IPaymaster {
    /**
     * @dev Validate paymaster user operation
     * @param userOp User operation to validate
     * @param userOpHash Hash of the user operation
     * @param maxCost Maximum cost of the operation
     * @return context Context data to be passed to postOp
     * @return validationData Encoded validation result
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData);

    /**
     * @dev Post operation processing
     * @param mode Operation mode
     * @param context Context data from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost of the operation
     */
    function postOp(
        IEntryPoint.PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external;
}

/**
 * @title BasePaymaster Abstract Contract
 * @dev Basic ERC-4337 paymaster implementation
 */
abstract contract BasePaymaster is IPaymaster {
    IEntryPoint public immutable entryPoint;
    
    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
    }
    
    /**
     * @dev Validate paymaster user operation
     * @param userOp User operation to validate
     * @param userOpHash Hash of the user operation
     * @param maxCost Maximum cost of the operation
     * @return context Context data to be passed to postOp
     * @return validationData Encoded validation result
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        require(msg.sender == address(entryPoint), "Paymaster: not from EntryPoint");
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }
    
    /**
     * @dev Post operation processing
     * @param mode Operation mode
     * @param context Context data from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost of the operation
     */
    function postOp(
        IEntryPoint.PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external override {
        require(msg.sender == address(entryPoint), "Paymaster: not from EntryPoint");
        _postOp(mode, context, actualGasCost);
    }
    
    /**
     * @dev Internal validation of paymaster user operation
     * @param userOp User operation to validate
     * @param userOpHash Hash of the user operation
     * @param maxCost Maximum cost of the operation
     * @return context Context data to be passed to postOp
     * @return validationData Encoded validation result
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) internal virtual returns (bytes memory context, uint256 validationData);
    
    /**
     * @dev Internal post operation processing
     * @param mode Operation mode
     * @param context Context data from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost of the operation
     */
    function _postOp(
        IEntryPoint.PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal virtual;
}