// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title NativeRollupWithOpcode
 * @notice Contract that uses inline assembly to call the EXECUTE opcode (0xfc) directly
 * 
 * @dev The EXECUTE opcode (0xfc) is an EVM opcode that calls the EXECUTE precompile
 *      at address 0x12. This contract demonstrates how to use it via inline assembly.
 * 
 *      Note: The EXECUTE opcode signature in EVM:
 *      - Opcode: 0xfc
 *      - Stack: gas (temp), value, inOffset, inSize, retOffset, retSize
 *      - Calls: ExecutePrecompileAddress (0x12) with calldata from memory
 */
contract NativeRollupWithOpcode {
    /// @notice EXECUTE precompile address (0x12)
    address public constant EXECUTE_PRECOMPILE = address(0x12);
    
    /// @notice Error emitted when execute opcode call fails
    error ExecuteCallFailed(bytes returnData);
    
    /// @notice Event emitted when execute call succeeds
    event ExecuteCallSucceeded(uint256 gasConsumed, bytes returnData);
    
    /**
     * @notice Receives execute transaction calldata and calls the EXECUTE opcode (0xfc)
     * @param calldata_ The calldata to pass to the EXECUTE precompile
     * @return gasConsumed The total gas consumed by the execute operation
     * @return success Whether the execution succeeded
     * @return returnData The return data from the execute call
     */
    function receiveExecuteCall(
        bytes calldata calldata_
    ) external returns (uint256 gasConsumed, bool success, bytes memory returnData) {
        uint256 gasBefore = gasleft();
        
        // Call EXECUTE precompile using inline assembly
        // This mimics what the EXECUTE opcode (0xfc) does internally
        assembly {
            // Load calldata into memory
            let calldataLength := calldata_.length
            let inputPtr := mload(0x40)
            calldatacopy(inputPtr, calldata_.offset, calldataLength)
            
            // Allocate memory for return data
            let returnDataPtr := add(inputPtr, add(calldataLength, 0x20))
            let returnDataSize := 0
            
            // Call EXECUTE precompile at 0x12
            // This is equivalent to using the EXECUTE opcode (0xfc)
            let success_flag := staticcall(
                gas(),                    // Forward all gas
                0x12,                     // EXECUTE precompile at 0x12
                inputPtr,                 // Input offset
                calldataLength,           // Input size
                returnDataPtr,            // Output offset
                0                         // Output size (will be set by return)
            )
            
            // Get return data size
            returnDataSize := returndatasize()
            
            // Update free memory pointer
            mstore(0x40, add(returnDataPtr, add(returnDataSize, 0x20)))
            
            // Copy return data to our allocated memory
            if gt(returnDataSize, 0) {
                returndatacopy(returnDataPtr, 0, returnDataSize)
            }
            
            success := success_flag
            returnData := returnDataPtr
        }
        
        if (!success) {
            revert ExecuteCallFailed(returnData);
        }
        
        // Parse gas consumed from return data (first 32 bytes)
        if (returnData.length >= 32) {
            assembly {
                gasConsumed := mload(add(returnData, 0x20))
            }
        } else {
            gasConsumed = gasBefore - gasleft();
        }
        
        emit ExecuteCallSucceeded(gasConsumed, returnData);
    }
    
    /**
     * @notice Simplified version that returns only gas consumed
     * @param calldata_ The calldata to pass to the EXECUTE precompile
     * @return gasConsumed The total gas consumed by the execute operation
     */
    function executeAndReturnGas(
        bytes calldata calldata_
    ) external returns (uint256 gasConsumed) {
        uint256 gasBefore = gasleft();
        
        bool success;
        bytes memory returnData;
        
        assembly {
            // Load calldata into memory
            let calldataLength := calldata_.length
            let inputPtr := mload(0x40)
            calldatacopy(inputPtr, calldata_.offset, calldataLength)
            
            // Allocate memory for return data
            let returnDataPtr := add(inputPtr, add(calldataLength, 0x20))
            
            // Call EXECUTE precompile
            let success_flag := staticcall(
                gas(),
                0x12,                     // EXECUTE precompile address
                inputPtr,
                calldataLength,
                returnDataPtr,
                0
            )
            
            let returnDataSize := returndatasize()
            mstore(0x40, add(returnDataPtr, add(returnDataSize, 0x20)))
            
            if gt(returnDataSize, 0) {
                returndatacopy(returnDataPtr, 0, returnDataSize)
            }
            
            success := success_flag
            returnData := returnDataPtr
        }
        
        if (!success) {
            revert ExecuteCallFailed(returnData);
        }
        
        // Parse gas consumed from return data
        if (returnData.length >= 32) {
            assembly {
                gasConsumed := mload(add(returnData, 0x20))
            }
        } else {
            gasConsumed = gasBefore - gasleft();
        }
    }
    
    /**
     * @notice Fallback function to receive execute transaction calls directly
     */
    fallback() external {
        uint256 gasBefore = gasleft();
        
        bool success;
        bytes memory returnData;
        
        assembly {
            // Load msg.data into memory
            let dataLength := calldatasize()
            let inputPtr := mload(0x40)
            calldatacopy(inputPtr, 0, dataLength)
            
            // Allocate memory for return data
            let returnDataPtr := add(inputPtr, add(dataLength, 0x20))
            
            // Call EXECUTE precompile
            let success_flag := staticcall(
                gas(),
                0x12,                     // EXECUTE precompile address
                inputPtr,
                dataLength,
                returnDataPtr,
                0
            )
            
            let returnDataSize := returndatasize()
            mstore(0x40, add(returnDataPtr, add(returnDataSize, 0x20)))
            
            if gt(returnDataSize, 0) {
                returndatacopy(returnDataPtr, 0, returnDataSize)
            }
            
            success := success_flag
            returnData := returnDataPtr
        }
        
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
        
        // Return gas consumed
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, gasConsumed)
            mstore(0x40, add(ptr, 0x20))
            return(ptr, 0x20)
        }
    }
    
    receive() external payable {}
}

