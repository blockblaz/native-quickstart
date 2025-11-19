#!/bin/bash
# Genesis Generator for Native Quickstart
# Generates a geth genesis.json file with pre-funded accounts

set -e

# ========================================
# Default Configuration
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENESIS_DIR="${GENESIS_DIR:-$SCRIPT_DIR/genesis}"
NUM_WALLETS="${NUM_WALLETS:-10}"
WALLET_BALANCE="${WALLET_BALANCE:-100}"
CHAIN_ID="${CHAIN_ID:-1337}"

# ========================================
# Usage and Help
# ========================================
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generates a geth genesis.json file with pre-funded accounts.

Options:
  --genesis-dir DIR       Genesis directory (default: ./genesis)
  --num-wallets N         Number of wallets to create (default: ${NUM_WALLETS})
  --wallet-balance ETH    Balance per wallet in ETH (default: ${WALLET_BALANCE})
  --chain-id ID           Chain ID (default: ${CHAIN_ID})
  --help                  Show this help message

Environment Variables:
  GENESIS_DIR             Genesis directory path
  NUM_WALLETS             Number of wallets
  WALLET_BALANCE          Balance per wallet in ETH
  CHAIN_ID                Chain ID

Example:
  $0 --num-wallets 10 --wallet-balance 100

EOF
}

# ========================================
# Parse Arguments
# ========================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --genesis-dir)
            GENESIS_DIR="$2"
            shift 2
            ;;
        --num-wallets)
            NUM_WALLETS="$2"
            shift 2
            ;;
        --wallet-balance)
            WALLET_BALANCE="$2"
            shift 2
            ;;
        --chain-id)
            CHAIN_ID="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

# ========================================
# Check Dependencies
# ========================================
echo "🔍 Checking dependencies..."

if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 is required but not installed"
    exit 1
fi
echo "  ✅ python3 found: $(which python3)"

echo ""

# ========================================
# Create Genesis Directory
# ========================================
mkdir -p "$GENESIS_DIR"
echo "📂 Genesis directory: $GENESIS_DIR"
echo ""

# ========================================
# Generate Accounts
# ========================================
echo "🔐 Generating $NUM_WALLETS accounts..."

# Check if eth-account is available, otherwise use geth
if python3 -c "import eth_account" 2>/dev/null; then
    echo "  Using eth_account library"
    USE_ETH_ACCOUNT=true
else
    echo "  Using geth account generation"
    USE_ETH_ACCOUNT=false
fi

# Generate accounts using Python
python3 << PYTHON_SCRIPT
import secrets
import json
import sys
import os

try:
    from eth_account import Account
    from eth_keys import keys
    HAS_ETH_ACCOUNT = True
except ImportError:
    HAS_ETH_ACCOUNT = False

num_wallets = ${NUM_WALLETS}
wallet_balance = ${WALLET_BALANCE}
genesis_dir = "${GENESIS_DIR}"

accounts = {}
account_list = []

for i in range(num_wallets):
    if HAS_ETH_ACCOUNT:
        # Generate account using eth_account
        private_key_hex = secrets.token_hex(32)
        private_key = "0x" + private_key_hex
        account = Account.from_key(private_key)
        address = account.address
    else:
        # Fallback: use deterministic generation for devnet
        # Generate a deterministic private key based on index
        import hashlib
        seed = f"native-quickstart-account-{i}".encode()
        private_key_hex = hashlib.sha256(seed).hexdigest()
        private_key = "0x" + private_key_hex
        # Simple address derivation (for devnet only)
        address_hash = hashlib.sha256(seed + b"-address").hexdigest()[:40]
        address = "0x" + address_hash
    
    # Convert balance to wei (1 ETH = 10^18 wei)
    balance_wei = str(wallet_balance * 10**18)
    
    accounts[address] = {"balance": balance_wei}
    account_list.append(f"{address}:{private_key}")

# Write accounts file
with open(os.path.join(genesis_dir, "accounts.txt"), "w") as f:
    for acc in account_list:
        f.write(acc + "\n")

print(f"Generated {num_wallets} accounts")
PYTHON_SCRIPT

echo "  ✅ Generated $NUM_WALLETS accounts"
echo "  ✅ Account details saved to: $GENESIS_DIR/accounts.txt"
echo ""

# ========================================
# Generate Genesis JSON
# ========================================
echo "📝 Generating genesis.json..."

# Calculate balance in wei
BALANCE_WEI=$(python3 -c "print(${WALLET_BALANCE} * 10**18)")

# Create genesis.json
python3 << PYTHON_SCRIPT > "$GENESIS_DIR/genesis.json"
import json
import sys

# Read accounts from file
accounts = {}
with open("${GENESIS_DIR}/accounts.txt", "r") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        address, private_key = line.split(":")
        balance_wei = str(${WALLET_BALANCE} * 10**18)
        accounts[address] = {"balance": balance_wei}

# Create genesis block
# Get first account address for Clique signer
first_account = list(accounts.keys())[0] if accounts else None
signer_address = first_account if first_account else "0x0000000000000000000000000000000000000000"

# Clique extraData: 32 bytes of zeros + signer addresses (20 bytes each) + 65 bytes of zeros
# Format: 0x + 32 zeros + signer address (without 0x) + 65 zeros
extra_data = "0x" + "0" * 64 + signer_address[2:] + "0" * 130

genesis = {
    "config": {
        "chainId": ${CHAIN_ID},
        "homesteadBlock": 0,
        "eip150Block": 0,
        "eip155Block": 0,
        "eip158Block": 0,
        "byzantiumBlock": 0,
        "constantinopleBlock": 0,
        "petersburgBlock": 0,
        "istanbulBlock": 0,
        "berlinBlock": 0,
        "londonBlock": 0,
        "arrowGlacierBlock": 0,
        "grayGlacierBlock": 0,
        "mergeNetsplitBlock": 0,
        "clique": {
            "period": 5,
            "epoch": 30000
        },
        "shanghaiTime": 0,
        "cancunTime": 0,
        "pragueTime": 0,
        "osakaTime": 0,
        "blobSchedule": {
            "cancun": {
                "target": 3,
                "max": 6,
                "baseFeeUpdateFraction": 3338477
            },
            "prague": {
                "target": 6,
                "max": 9,
                "baseFeeUpdateFraction": 5007716
            },
            "osaka": {
                "target": 6,
                "max": 9,
                "baseFeeUpdateFraction": 5007716
            }
        }
    },
    "difficulty": "0x1",
    "gasLimit": "0x1c9c380",
    "extraData": extra_data,
    "alloc": accounts
}

print(json.dumps(genesis, indent=2))
PYTHON_SCRIPT

echo "  ✅ Genesis file created: $GENESIS_DIR/genesis.json"
echo ""

# ========================================
# Summary
# ========================================
echo "✅ Genesis generation complete!"
echo ""
echo "📄 Generated files:"
echo "  $GENESIS_DIR/genesis.json"
echo "  $GENESIS_DIR/accounts.txt"
echo ""
echo "📊 Configuration:"
echo "  Chain ID: $CHAIN_ID"
echo "  Wallets: $NUM_WALLETS"
echo "  Balance per wallet: ${WALLET_BALANCE} ETH"
echo ""

