// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title NativeRollup
 * @notice Contract that receives execute transaction calls and validates witness data
 *         using the EXECUTE precompile at address 0x12. The EXECUTE precompile performs
 *         stateless execution using witness data and returns the gas consumed.
 * 
 * @dev The EXECUTE opcode (0xfc) internally calls the precompile at 0x12.
 *      We call the precompile directly using staticcall, which is functionally equivalent
 *      to using the opcode. No Solidity compiler changes are needed.
 * 
 *      Note: To use the opcode 0xfc directly in inline assembly, you would need to:
 *      1. Set up the stack with: gas, value, inOffset, inSize, retOffset, retSize
 *      2. Use a low-level assembly operation to invoke opcode 0xfc
 *      However, calling the precompile directly is simpler and equivalent.
 */
contract NativeRollup {
    /// @notice EXECUTE precompile address (0x12)
    address public constant EXECUTE_PRECOMPILE = address(0x12);
    
    /// @notice Chain ID for this rollup
    uint256 public immutable chainId;
    
    /// @notice Error emitted when execute precompile call fails
    error ExecuteCallFailed(bytes returnData);
    
    /// @notice Error emitted when chainId in calldata doesn't match contract's chainId
    error InvalidChainId(uint256 expected, uint256 provided);
    
    /// @notice Event emitted when execute call succeeds
    event ExecuteCallSucceeded(uint256 gasConsumed, bytes returnData);
    
    /**
     * @notice Constructor to initialize the contract with a chain ID
     * @param chainId_ The chain ID for this rollup
     */
    constructor(uint256 chainId_) {
        chainId = chainId_;
    }
    
    /**
     * @notice Receives execute transaction calldata and calls the EXECUTE precompile
     * @param calldata_ The calldata to pass to the EXECUTE precompile
     *                   Format: See EXECUTE_IMPLEMENTATION.md for calldata structure
     * @return gasConsumed The total gas consumed by the execute operation (from precompile return)
     * @return success Whether the execution succeeded
     * @return returnData The return data from the execute call
     * 
     * @dev This function calls the EXECUTE precompile directly. The EXECUTE opcode (0xfc)
     *      does the same thing - it's just a convenience wrapper that always calls address 0x12.
     *      No Solidity compiler changes are needed because we can call precompiles directly.
     */
    function receiveExecuteCall(
        bytes calldata calldata_
    ) external returns (uint256 gasConsumed, bool success, bytes memory returnData) {
        // Validate chainId from calldata (first 32 bytes)
        _validateChainId(calldata_);
        
        uint256 gasBefore = gasleft();
        
        // Call the EXECUTE precompile at address 0x12
        // This is functionally equivalent to using the EXECUTE opcode (0xfc)
        // The opcode is just a convenience wrapper that calls this precompile
        (success, returnData) = EXECUTE_PRECOMPILE.staticcall(calldata_);
        
        uint256 gasAfter = gasleft();
        uint256 actualGasUsed = gasBefore - gasAfter;
        
        if (!success) {
            revert ExecuteCallFailed(returnData);
        }
        
        // Parse gas consumed from return data
        // The EXECUTE precompile returns gas consumed as the first 32 bytes (uint256)
        if (returnData.length >= 32) {
            assembly {
                gasConsumed := mload(add(returnData, 0x20))
            }
        } else {
            // Fallback to actual gas used if precompile doesn't return gas consumed
            gasConsumed = actualGasUsed;
        }
        
        emit ExecuteCallSucceeded(gasConsumed, returnData);
    }
    
    /**
     * @notice Simplified version that calls execute and returns only gas consumed
     * @param calldata_ The calldata to pass to the EXECUTE precompile
     * @return gasConsumed The total gas consumed by the execute operation
     */
    function executeAndReturnGas(
        bytes calldata calldata_
    ) external returns (uint256 gasConsumed) {
        // Validate chainId from calldata (first 32 bytes)
        _validateChainId(calldata_);
        
        uint256 gasBefore = gasleft();
        
        (bool success, bytes memory returnData) = EXECUTE_PRECOMPILE.staticcall(calldata_);
        
        if (!success) {
            revert ExecuteCallFailed(returnData);
        }
        
        // Parse gas consumed from return data (first 32 bytes)
        if (returnData.length >= 32) {
            assembly {
                gasConsumed := mload(add(returnData, 0x20))
            }
        } else {
            // Fallback to actual gas used
            gasConsumed = gasBefore - gasleft();
        }
    }
    
    /**
     * @notice Fallback function to receive execute transaction calls directly
     * @dev This allows the contract to receive execute transactions and process them
     *      The calldata is forwarded directly to the EXECUTE precompile
     */
    fallback() external {
        // Validate chainId from calldata (first 32 bytes)
        _validateChainId(msg.data);
        
        uint256 gasBefore = gasleft();
        
        (bool success, bytes memory returnData) = EXECUTE_PRECOMPILE.staticcall(msg.data);
        
        if (!success) {
            revert ExecuteCallFailed(returnData);
        }
        
        // Parse gas consumed from return data
        uint256 gasConsumed;
        if (returnData.length >= 32) {
            assembly {
                gasConsumed := mload(add(returnData, 0x20))
            }
        } else {
            gasConsumed = gasBefore - gasleft();
        }
        
        // Return gas consumed (32 bytes)
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, gasConsumed)
            mstore(0x40, add(ptr, 0x20))
            return(ptr, 0x20)
        }
    }
    
    /**
     * @notice Internal function to validate chainId from execute transaction calldata
     * @param calldata_ The calldata containing the execute transaction
     * @dev The chainId is the first 32 bytes of the calldata
     */
    function _validateChainId(bytes calldata calldata_) internal view {
        // Chain ID is the first 32 bytes of the execute transaction calldata
        if (calldata_.length < 32) {
            revert InvalidChainId(chainId, 0);
        }
        
        uint256 providedChainId;
        assembly {
            // Extract first 32 bytes (chainId) from calldata
            providedChainId := calldataload(calldata_.offset)
        }
        
        if (providedChainId != chainId) {
            revert InvalidChainId(chainId, providedChainId);
        }
    }
    
    /**
     * @notice Receive function (empty to allow contract to receive ETH)
     */
    receive() external payable {}
}
