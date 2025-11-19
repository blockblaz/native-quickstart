# NativeRollup Contract

A Solidity contract that receives execute transaction calls and validates witness data using the EXECUTE precompile at address `0x12`.

## Overview

This contract demonstrates how to:
- Receive execute transaction calldata
- Call the EXECUTE precompile (address `0x12`) to validate witness data
- Return the total gas consumed or handle errors

The EXECUTE precompile performs stateless execution using witness data and returns the gas consumed during execution.

## Contracts

### NativeRollup

Main contract that calls the EXECUTE precompile directly using Solidity's `staticcall`.

**Functions:**
- `receiveExecuteCall(bytes calldata)`: Receives calldata and calls EXECUTE precompile, returns gas consumed, success status, and return data
- `executeAndReturnGas(bytes calldata)`: Simplified version that returns only gas consumed
- `fallback()`: Receives execute transactions directly and processes them

### NativeRollupWithOpcode

Alternative implementation using inline assembly to call the EXECUTE precompile (mimics the EXECUTE opcode `0xfc` behavior).

## EXECUTE Precompile

- **Address**: `0x12`
- **Opcode**: `0xfc` (EXECUTE)
- **Purpose**: Performs stateless execution using witness data
- **Returns**: Gas consumed (first 32 bytes) + execution return data

## Calldata Format

The EXECUTE precompile expects calldata in the following format (see `EXECUTE_IMPLEMENTATION.md`):

```
[Chain ID (32 bytes)]
[Pre-state hash (32 bytes)]
[Gas limit (8 bytes, little-endian)]
[Witness size + Withdrawals size (4 bytes, parsed as two uint16)]
[Coinbase address (20 bytes)]
[Block number (8 bytes, little-endian)]
[Gas price (8 bytes, little-endian)]
[Timestamp (8 bytes, little-endian)]
[Witness data (RLP-encoded, variable length)]
[Withdrawals data (variable length)]
[Blob hashes (skipped)]
[Execution target: To address (20 bytes), Value (32 bytes), Data length (4 bytes), Data (variable length)]
```

## Building

```bash
# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Run tests with verbose output
forge test -vvv
```

## Testing

The test suite includes:
- Basic contract deployment tests
- Invalid calldata handling tests
- Error handling verification

To test with valid execute transaction calldata, you'll need to construct proper calldata with witness data according to the EXECUTE precompile specification.

## Usage

### Deploy the Contract

```solidity
NativeRollup recipient = new NativeRollup();
```

### Call with Execute Transaction Calldata

```solidity
bytes memory executeCalldata = /* construct execute calldata */;
(uint256 gasConsumed, bool success, bytes memory returnData) = 
    recipient.receiveExecuteCall(executeCalldata);
```

### Simplified Gas Check

```solidity
bytes memory executeCalldata = /* construct execute calldata */;
uint256 gasConsumed = recipient.executeAndReturnGas(executeCalldata);
```

## Error Handling

The contract emits `ExecuteCallFailed` error when:
- The EXECUTE precompile call fails
- Invalid calldata is provided
- Witness data validation fails

## Events

- `ExecuteCallSucceeded(uint256 gasConsumed, bytes returnData)`: Emitted when execute call succeeds

## Requirements

- Solidity ^0.8.0
- Foundry framework
- Network with Osaka fork enabled (EXECUTE precompile available)

## License

MIT
