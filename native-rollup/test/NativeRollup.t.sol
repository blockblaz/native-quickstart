// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {NativeRollup} from "../src/NativeRollup.sol";
import {NativeRollupWithOpcode} from "../src/NativeRollupWithOpcode.sol";

contract NativeRollupTest is Test {
    NativeRollup public recipient;
    NativeRollupWithOpcode public recipientWithOpcode;
    
    // EXECUTE precompile address
    address constant EXECUTE_PRECOMPILE = address(0x12);
    
    // Test chain ID
    uint256 constant TEST_CHAIN_ID = 61972;
    
    function setUp() public {
        recipient = new NativeRollup(TEST_CHAIN_ID);
        recipientWithOpcode = new NativeRollupWithOpcode();
    }
    
    function test_ExecutePrecompileAddress() public view {
        assertEq(recipient.EXECUTE_PRECOMPILE(), EXECUTE_PRECOMPILE);
        assertEq(recipientWithOpcode.EXECUTE_PRECOMPILE(), EXECUTE_PRECOMPILE);
    }
    
    function test_ChainId() public view {
        assertEq(recipient.chainId(), TEST_CHAIN_ID);
    }
    
    function test_InvalidChainId() public {
        // Create calldata with wrong chainId (first 32 bytes)
        bytes memory invalidCalldata = abi.encodePacked(
            uint256(999), // Wrong chainId
            bytes32(0),   // Pre-state hash
            uint64(100000), // Gas limit
            uint32(0),    // Witness size + Withdrawals size
            address(0),   // Coinbase
            uint64(1),    // Block number
            uint64(1000), // Gas price
            uint64(1000)  // Timestamp
        );
        
        vm.expectRevert(abi.encodeWithSelector(
            NativeRollup.InvalidChainId.selector,
            TEST_CHAIN_ID,
            uint256(999)
        ));
        recipient.receiveExecuteCall(invalidCalldata);
    }
    
    function test_InvalidChainId_ShortCalldata() public {
        // Calldata shorter than 32 bytes (minimum for chainId)
        bytes memory shortCalldata = hex"1234";
        
        vm.expectRevert(abi.encodeWithSelector(
            NativeRollup.InvalidChainId.selector,
            TEST_CHAIN_ID,
            uint256(0)
        ));
        recipient.receiveExecuteCall(shortCalldata);
    }
    
    function test_ReceiveExecuteCall_InvalidCalldata() public {
        // Test with invalid/empty calldata - should fail chainId validation first
        bytes memory invalidCalldata = hex"";
        
        vm.expectRevert(abi.encodeWithSelector(
            NativeRollup.InvalidChainId.selector,
            TEST_CHAIN_ID,
            uint256(0)
        ));
        recipient.receiveExecuteCall(invalidCalldata);
    }
    
    function test_ExecuteAndReturnGas_InvalidCalldata() public {
        // Test with invalid/empty calldata - should fail chainId validation first
        bytes memory invalidCalldata = hex"";
        
        vm.expectRevert(abi.encodeWithSelector(
            NativeRollup.InvalidChainId.selector,
            TEST_CHAIN_ID,
            uint256(0)
        ));
        recipient.executeAndReturnGas(invalidCalldata);
    }
    
    // Note: To test with valid execute calldata, you would need to construct
    // proper execute transaction calldata with witness data, which requires
    // knowledge of the exact format expected by the EXECUTE precompile.
    // See EXECUTE_IMPLEMENTATION.md for the calldata structure.
}

