// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {NativeRollup} from "../src/NativeRollup.sol";
import {NativeRollupWithOpcode} from "../src/NativeRollupWithOpcode.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Get chainId from environment variable, default to 61972 (L2 chain ID)
        uint256 chainId = vm.envOr("CHAIN_ID", uint256(61972));
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying NativeRollup with chainId:", chainId);
        NativeRollup recipient = new NativeRollup(chainId);
        console.log("NativeRollup deployed at:", address(recipient));
        console.log("Chain ID:", recipient.chainId());
        
        console.log("Deploying NativeRollupWithOpcode...");
        NativeRollupWithOpcode recipientWithOpcode = new NativeRollupWithOpcode();
        console.log("NativeRollupWithOpcode deployed at:", address(recipientWithOpcode));
        
        vm.stopBroadcast();
    }
}

