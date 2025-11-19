#!/bin/bash
# Native Quickstart - Devnet Startup Script
# Brings up a devnet with L1 node, L2 node, and native sequencer

set -e

# ========================================
# Default Configuration
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${DATA_DIR:-$SCRIPT_DIR/data}"
GENESIS_DIR="${GENESIS_DIR:-$SCRIPT_DIR/genesis}"
NUM_WALLETS="${NUM_WALLETS:-10}"
WALLET_BALANCE="${WALLET_BALANCE:-100}"
L1_CHAIN_ID="${L1_CHAIN_ID:-61971}"
L2_CHAIN_ID="${L2_CHAIN_ID:-61972}"
L1_PORT="${L1_PORT:-8545}"
L2_PORT="${L2_PORT:-18545}"
L2_ENGINE_PORT="${L2_ENGINE_PORT:-18551}"
SEQUENCER_PORT="${SEQUENCER_PORT:-18547}"
SEQUENCER_METRICS_PORT="${SEQUENCER_METRICS_PORT:-9090}"
GETH_IMAGE="${GETH_IMAGE:-0xpartha/geth:latest}"
SEQUENCER_IMAGE="${SEQUENCER_IMAGE:-0xpartha/native-sequencer:latest}"
CLEAN_DATA="${CLEAN_DATA:-false}"
GENERATE_GENESIS="${GENERATE_GENESIS:-}"

# ========================================
# Usage and Help
# ========================================
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Brings up a devnet with:
  - L1 node (geth) on port ${L1_PORT}
  - L2 node (geth) on port ${L2_PORT}
  - Native sequencer on port ${SEQUENCER_PORT}

Options:
  --data-dir DIR          Data directory (default: ./data)
  --genesis-dir DIR       Genesis directory (default: ./genesis)
  --num-wallets N         Number of wallets to create (default: ${NUM_WALLETS})
  --wallet-balance ETH    Balance per wallet in ETH (default: ${WALLET_BALANCE})
  --l1-chain-id ID        L1 chain ID (default: ${L1_CHAIN_ID})
  --l2-chain-id ID        L2 chain ID (default: ${L2_CHAIN_ID})
  --l1-port PORT          L1 RPC port (default: ${L1_PORT})
  --l2-port PORT          L2 RPC port (default: ${L2_PORT})
  --l2-engine-port PORT   L2 Engine API port (default: ${L2_ENGINE_PORT})
  --sequencer-port PORT   Sequencer RPC port (default: ${SEQUENCER_PORT})
  --sequencer-metrics PORT Sequencer metrics port (default: ${SEQUENCER_METRICS_PORT})
  --geth-image IMAGE      Geth Docker image (default: ${GETH_IMAGE})
  --sequencer-image IMAGE Sequencer Docker image (default: ${SEQUENCER_IMAGE})
  --clean-data            Clean data directories before starting
  --generate-genesis      Generate genesis file (default: use existing)
  --no-genesis            Skip genesis generation (default behavior)
  --stop                  Stop all running containers
  --help                  Show this help message

Environment Variables:
  DATA_DIR                Data directory path
  GENESIS_DIR             Genesis directory path
  NUM_WALLETS             Number of wallets
  WALLET_BALANCE          Balance per wallet in ETH
  L1_CHAIN_ID             L1 chain ID
  L2_CHAIN_ID             L2 chain ID
  L1_PORT                 L1 RPC port
  L2_PORT                 L2 RPC port
  L2_ENGINE_PORT          L2 Engine API port
  SEQUENCER_PORT          Sequencer RPC port
  SEQUENCER_METRICS_PORT  Sequencer metrics port
  GETH_IMAGE              Geth Docker image
  SEQUENCER_IMAGE         Sequencer Docker image

Examples:
  # Start devnet with defaults
  $0

  # Start with custom ports
  $0 --l1-port 18545 --l2-port 18546 --sequencer-port 18547

  # Start with 20 wallets, 200 ETH each
  $0 --num-wallets 20 --wallet-balance 200

  # Clean start
  $0 --clean-data

  # Stop all containers
  $0 --stop

EOF
}

# ========================================
# Parse Arguments
# ========================================
STOP_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
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
        --l1-chain-id)
            L1_CHAIN_ID="$2"
            shift 2
            ;;
        --l2-chain-id)
            L2_CHAIN_ID="$2"
            shift 2
            ;;
        --l1-port)
            L1_PORT="$2"
            shift 2
            ;;
        --l2-port)
            L2_PORT="$2"
            shift 2
            ;;
        --l2-engine-port)
            L2_ENGINE_PORT="$2"
            shift 2
            ;;
        --sequencer-port)
            SEQUENCER_PORT="$2"
            shift 2
            ;;
        --sequencer-metrics)
            SEQUENCER_METRICS_PORT="$2"
            shift 2
            ;;
        --geth-image)
            GETH_IMAGE="$2"
            shift 2
            ;;
        --sequencer-image)
            SEQUENCER_IMAGE="$2"
            shift 2
            ;;
        --clean-data)
            CLEAN_DATA="true"
            shift
            ;;
        --generate-genesis)
            GENERATE_GENESIS="true"
            shift
            ;;
        --no-genesis)
            GENERATE_GENESIS="false"
            shift
            ;;
        --stop)
            STOP_ONLY=true
            shift
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
# Stop Containers
# ========================================
if [ "$STOP_ONLY" = true ]; then
    echo "🛑 Stopping all devnet containers..."
    docker stop native-quickstart-l1 native-quickstart-l2 native-quickstart-sequencer 2>/dev/null || true
    docker rm native-quickstart-l1 native-quickstart-l2 native-quickstart-sequencer 2>/dev/null || true
    NETWORK_NAME="native-quickstart-network"
    if docker network inspect "$NETWORK_NAME" &>/dev/null; then
        docker network rm "$NETWORK_NAME" 2>/dev/null || true
    fi
    echo "✅ All containers stopped"
    exit 0
fi

# ========================================
# Check Dependencies
# ========================================
echo "🔍 Checking dependencies..."

if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is required but not installed"
    echo "   Install from: https://docs.docker.com/get-docker/"
    exit 1
fi
echo "  ✅ docker found: $(which docker)"

if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 is required but not installed"
    exit 1
fi
echo "  ✅ python3 found: $(which python3)"

echo ""

# ========================================
# Create Docker Network
# ========================================
NETWORK_NAME="native-quickstart-network"
echo "🌐 Setting up Docker network..."
if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
    docker network create "$NETWORK_NAME"
    echo "  ✅ Created Docker network: $NETWORK_NAME"
else
    echo "  ℹ️  Docker network already exists: $NETWORK_NAME"
fi
echo ""

# ========================================
# Create Directories
# ========================================
echo "📂 Setting up directories..."
mkdir -p "$DATA_DIR/l1" "$DATA_DIR/l2" "$DATA_DIR/sequencer" "$GENESIS_DIR"
echo "  ✅ Data directory: $DATA_DIR"
echo "  ✅ Genesis directory: $GENESIS_DIR"
echo ""

# ========================================
# Clean Data if Requested
# ========================================
if [ "$CLEAN_DATA" = "true" ]; then
    echo "🧹 Cleaning data directories..."
    rm -rf "$DATA_DIR/l1" "$DATA_DIR/l2" "$DATA_DIR/sequencer"
    mkdir -p "$DATA_DIR/l1" "$DATA_DIR/l2" "$DATA_DIR/sequencer"
    echo "  ✅ Data directories cleaned"
    echo ""
fi

# ========================================
# Generate Genesis
# ========================================
GENESIS_FILE="$GENESIS_DIR/genesis.json"

# Determine if we should generate genesis
# Default: --no-genesis (skip generation, use existing)
# Only generate if --generate-genesis is explicitly set
if [ "$GENERATE_GENESIS" = "true" ]; then
    echo "🔧 Generating genesis file (--generate-genesis flag set)..."
    "$SCRIPT_DIR/generate-genesis.sh" \
        --genesis-dir "$GENESIS_DIR" \
        --num-wallets "$NUM_WALLETS" \
        --wallet-balance "$WALLET_BALANCE" \
        --chain-id "$L1_CHAIN_ID"
    echo ""
else
    # Default behavior: use existing genesis file (--no-genesis)
    if [ -f "$GENESIS_FILE" ]; then
        echo "ℹ️  Using existing genesis file: $GENESIS_FILE"
        echo ""
    else
        echo "❌ Error: Genesis file not found: $GENESIS_FILE"
        echo ""
        echo "   Please run the script with --generate-genesis option to create a new genesis file:"
        echo "   ./start-devnet.sh --generate-genesis"
        echo ""
        echo "   Or create genesis.json manually in $GENESIS_DIR"
        exit 1
    fi
fi

# ========================================
# Cleanup Existing Containers
# ========================================
echo "🧹 Cleaning up any existing containers..."
# Stop and remove all related containers
docker stop native-quickstart-l1 native-quickstart-l2 native-quickstart-sequencer 2>/dev/null || true
docker rm native-quickstart-l1 native-quickstart-l2 native-quickstart-sequencer 2>/dev/null || true

# Also check for containers using our ports and clean them up
for port in "$L1_PORT" "$L2_PORT" "$L2_ENGINE_PORT" "$SEQUENCER_PORT"; do
    CONTAINER_USING_PORT=$(docker ps -a --format "{{.ID}} {{.Ports}}" | grep ":$port->" | awk '{print $1}' | head -n 1)
    if [ -n "$CONTAINER_USING_PORT" ]; then
        echo "  🛑 Removing container $CONTAINER_USING_PORT using port $port"
        docker stop "$CONTAINER_USING_PORT" 2>/dev/null || true
        docker rm "$CONTAINER_USING_PORT" 2>/dev/null || true
    fi
done
echo ""

# ========================================
# Pull Docker Images
# ========================================
echo "📥 Pulling Docker images..."
docker pull "$GETH_IMAGE" || echo "  ⚠️  Failed to pull $GETH_IMAGE, will try to use local image"
docker pull "$SEQUENCER_IMAGE" || echo "  ⚠️  Failed to pull $SEQUENCER_IMAGE, will try to use local image"
echo ""

# ========================================
# Initialize L1 Node
# ========================================
echo "🚀 Initializing L1 node..."
if [ ! -d "$DATA_DIR/l1/geth" ]; then
    docker run --rm \
        -v "$GENESIS_DIR:/genesis" \
        -v "$DATA_DIR/l1:/data" \
        "$GETH_IMAGE" \
        init --datadir /data /genesis/genesis.json
    echo "  ✅ L1 node initialized"
else
    echo "  ℹ️  L1 node already initialized, skipping"
fi
echo ""

# ========================================
# Initialize L2 Node
# ========================================
echo "🚀 Initializing L2 node..."
if [ ! -d "$DATA_DIR/l2/geth" ]; then
    docker run --rm \
        -v "$GENESIS_DIR:/genesis" \
        -v "$DATA_DIR/l2:/data" \
        "$GETH_IMAGE" \
        init --datadir /data /genesis/genesis.json
    echo "  ✅ L2 node initialized"
else
    echo "  ℹ️  L2 node already initialized, skipping"
fi
echo ""

# ========================================
# Start L1 Node
# ========================================
echo "🌐 Starting L1 node..."

# Stop and remove existing container
docker stop native-quickstart-l1 2>/dev/null || true
docker rm native-quickstart-l1 2>/dev/null || true

# Check if port is already in use
if lsof -Pi :$L1_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "  ⚠️  Port $L1_PORT is already in use. Attempting to free it..."
    # Try to find and stop container using this port (check all containers)
    CONTAINER_USING_PORT=$(docker ps -a --format "{{.ID}} {{.Ports}}" | grep ":$L1_PORT" | awk '{print $1}' | head -n 1)
    if [ -n "$CONTAINER_USING_PORT" ]; then
        echo "  🛑 Stopping and removing container $CONTAINER_USING_PORT using port $L1_PORT"
        docker stop "$CONTAINER_USING_PORT" 2>/dev/null || true
        docker rm "$CONTAINER_USING_PORT" 2>/dev/null || true
    else
        echo "  ⚠️  Port $L1_PORT is in use but not by a Docker container. Please free the port manually."
        echo "  💡 You can check what's using it with: lsof -i :$L1_PORT"
    fi
    sleep 2
fi

# Get signer account (first account) for Clique block production
SIGNER_KEY_RAW=$(head -n 1 "$GENESIS_DIR/accounts.txt" | cut -d: -f2)
if [[ ! "$SIGNER_KEY_RAW" =~ ^0x ]]; then
    SIGNER_KEY="0x$SIGNER_KEY_RAW"
else
    SIGNER_KEY="$SIGNER_KEY_RAW"
fi
SIGNER_ADDRESS=$(head -n 1 "$GENESIS_DIR/accounts.txt" | cut -d: -f1)

# Create empty password file for unlocking accounts
echo "" > "$DATA_DIR/l1/password.txt"

docker run -d \
    --name native-quickstart-l1 \
    --network "$NETWORK_NAME" \
    -p "$L1_PORT:8545" \
    -p "$((L1_PORT + 1)):30303" \
    -v "$DATA_DIR/l1:/data" \
    "$GETH_IMAGE" \
    --datadir /data \
    --http \
    --http.addr 0.0.0.0 \
    --http.port 8545 \
    --http.api eth,net,web3,debug \
    --http.corsdomain "*" \
    --http.vhosts "*" \
    --networkid "$L1_CHAIN_ID" \
    --nodiscover \
    --override.osaka 0 \
    --verbosity 4 \
    --vmodule "rpc=5,http=5" \
    --unlock "$SIGNER_ADDRESS" \
    --password /data/password.txt \
    --allow-insecure-unlock \
    --mine \
    --miner.etherbase "$SIGNER_ADDRESS"

echo "  ✅ L1 node started on port $L1_PORT (PoA/Clique - auto-mining enabled)"
echo ""

# Wait for L1 to be ready
echo "⏳ Waiting for L1 node to be ready..."
for i in {1..30}; do
    if curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "http://localhost:$L1_PORT" > /dev/null 2>&1; then
        echo "  ✅ L1 node is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "  ⚠️  L1 node may not be ready yet, continuing anyway"
    fi
    sleep 1
done
echo ""

# ========================================
# Start L2 Node
# ========================================
echo "🌐 Starting L2 node..."

# Stop and remove existing container
docker stop native-quickstart-l2 2>/dev/null || true
docker rm native-quickstart-l2 2>/dev/null || true

# Check if port is already in use
if lsof -Pi :$L2_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "  ⚠️  Port $L2_PORT is already in use. Attempting to free it..."
    # Try to find and stop container using this port (check all containers)
    CONTAINER_USING_PORT=$(docker ps -a --format "{{.ID}} {{.Ports}}" | grep ":$L2_PORT" | awk '{print $1}' | head -n 1)
    if [ -n "$CONTAINER_USING_PORT" ]; then
        echo "  🛑 Stopping and removing container $CONTAINER_USING_PORT using port $L2_PORT"
        docker stop "$CONTAINER_USING_PORT" 2>/dev/null || true
        docker rm "$CONTAINER_USING_PORT" 2>/dev/null || true
    else
        echo "  ⚠️  Port $L2_PORT is in use but not by a Docker container. Please free the port manually."
        echo "  💡 You can check what's using it with: lsof -i :$L2_PORT"
    fi
    sleep 2
fi

# L2 node runs without mining - blocks are produced by the sequencer via Engine API
docker run -d \
    --name native-quickstart-l2 \
    --network "$NETWORK_NAME" \
    -p "$L2_PORT:8545" \
    -p "$L2_ENGINE_PORT:8551" \
    -p "$((L2_PORT + 1)):30303" \
    -v "$DATA_DIR/l2:/data" \
    "$GETH_IMAGE" \
    --datadir /data \
    --http \
    --http.addr 0.0.0.0 \
    --http.port 8545 \
    --http.api eth,net,web3,debug,engine \
    --http.corsdomain "*" \
    --http.vhosts "*" \
    --authrpc.addr 0.0.0.0 \
    --authrpc.port 8551 \
    --authrpc.vhosts "*" \
    --networkid "$L2_CHAIN_ID" \
    --nodiscover \
    --override.osaka 0 \
    --verbosity 4 \
    --vmodule "rpc=5,http=5"

echo "  ✅ L2 node started on port $L2_PORT (Engine API on $L2_ENGINE_PORT - blocks produced by sequencer)"
echo ""

# Wait for L2 to be ready
echo "⏳ Waiting for L2 node to be ready..."
for i in {1..30}; do
    if curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "http://localhost:$L2_PORT" > /dev/null 2>&1; then
        echo "  ✅ L2 node is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "  ⚠️  L2 node may not be ready yet, continuing anyway"
    fi
    sleep 1
done
echo ""

# ========================================
# Start Sequencer
# ========================================
echo "🎯 Starting native sequencer..."

# Get sequencer key (use first account's private key)
SEQUENCER_KEY_RAW=$(head -n 1 "$GENESIS_DIR/accounts.txt" | cut -d: -f2)
# Ensure key has 0x prefix
if [[ ! "$SEQUENCER_KEY_RAW" =~ ^0x ]]; then
    SEQUENCER_KEY="0x$SEQUENCER_KEY_RAW"
else
    SEQUENCER_KEY="$SEQUENCER_KEY_RAW"
fi

docker stop native-quickstart-sequencer 2>/dev/null || true
docker rm native-quickstart-sequencer 2>/dev/null || true

docker run -d \
    --name native-quickstart-sequencer \
    --network "$NETWORK_NAME" \
    -p "$SEQUENCER_PORT:8545" \
    -p "$SEQUENCER_METRICS_PORT:9090" \
    -v "$DATA_DIR/sequencer:/app/data" \
    -e L1_RPC_URL="http://native-quickstart-l1:8545" \
    -e L2_RPC_URL="http://native-quickstart-l2:8545" \
    -e L2_ENGINE_API_PORT="$L2_ENGINE_PORT" \
    -e L1_CHAIN_ID="$L1_CHAIN_ID" \
    -e L2_CHAIN_ID="$L2_CHAIN_ID" \
    -e SEQUENCER_KEY="$SEQUENCER_KEY" \
    -e API_PORT=8545 \
    -e METRICS_PORT=9090 \
    "$SEQUENCER_IMAGE"

echo "  ✅ Sequencer started on port $SEQUENCER_PORT (metrics on $SEQUENCER_METRICS_PORT)"
echo ""

# ========================================
# Deploy NativeRollup Contract
# ========================================
echo "📦 Deploying NativeRollup contract on L1..."
echo "  📍 Step 1/7: Preparing for deployment..."

# Wait for L1 to be fully ready and process some blocks
echo "  ⏳ Step 2/7: Waiting for L1 node to be fully ready..."
sleep 5

# Check L1 block number to ensure it's processing blocks
echo "  🔍 Step 3/7: Checking L1 node status..."
L1_BLOCK_NUMBER=$(cast block-number --rpc-url "http://localhost:$L1_PORT" 2>/dev/null || echo "")
if [ -n "$L1_BLOCK_NUMBER" ]; then
    echo "  ✅ L1 node is ready (current block: $L1_BLOCK_NUMBER)"
else
    echo "  ⚠️  Could not get L1 block number, but continuing..."
fi

# Additional wait to ensure everything is stable
echo "  ⏳ Step 4/7: Waiting additional 5 seconds for stability..."
sleep 5

# Check and install Foundry if needed
check_and_install_foundry() {
    echo "  🔍 Step 5/7: Checking for Foundry..."
    if command -v forge &> /dev/null; then
        echo "  ✅ Foundry is already installed"
        return 0
    fi
    
    echo "  ⚠️  Foundry (forge) not found. Attempting to install..."
    
    # Check if foundryup is available
    if command -v foundryup &> /dev/null; then
        echo "  📥 Installing Foundry using foundryup..."
        foundryup 2>&1 | head -20
        # Reload PATH to make forge available
        export PATH="$HOME/.foundry/bin:$PATH"
    else
        # Try to install foundryup first
        echo "  📥 Installing foundryup..."
        if command -v curl &> /dev/null; then
            curl -L https://foundry.paradigm.xyz | bash
            export PATH="$HOME/.foundry/bin:$PATH"
            # Run foundryup after installation
            if command -v foundryup &> /dev/null; then
                foundryup 2>&1 | head -20
            fi
        else
            echo "  ❌ curl not found. Cannot install Foundry automatically."
            echo "  💡 Please install Foundry manually: https://book.getfoundry.sh/getting-started/installation"
            return 1
        fi
    fi
    
    # Verify installation
    if command -v forge &> /dev/null; then
        echo "  ✅ Foundry installed successfully"
        return 0
    else
        echo "  ⚠️  Foundry installation may have failed. forge command not found."
        echo "  💡 Please install Foundry manually: https://book.getfoundry.sh/getting-started/installation"
        return 1
    fi
}

# Check and install Foundry if needed
if ! check_and_install_foundry; then
    echo "  ❌ Step 5/7 failed: Skipping NativeRollup deployment due to missing Foundry."
    NATIVE_ROLLUP_ADDRESS=""
else
    # Ensure forge is in PATH
    export PATH="$HOME/.foundry/bin:$PATH"
    
    if ! command -v forge &> /dev/null; then
        echo "  ❌ Foundry (forge) still not found after installation attempt."
        echo "  💡 Please install Foundry manually: https://book.getfoundry.sh/getting-started/installation"
        NATIVE_ROLLUP_ADDRESS=""
    else
        echo "  ✅ Step 5/7 complete: Foundry is ready"
        echo "  📍 Step 6/7: Preparing deployment parameters..."
        
        # Get deployer account (use first account from genesis)
        DEPLOYER_KEY_RAW=$(head -n 1 "$GENESIS_DIR/accounts.txt" | cut -d: -f2)
        # Ensure key has 0x prefix
        if [[ ! "$DEPLOYER_KEY_RAW" =~ ^0x ]]; then
            DEPLOYER_KEY="0x$DEPLOYER_KEY_RAW"
        else
            DEPLOYER_KEY="$DEPLOYER_KEY_RAW"
        fi
        
        # Get deployer address
        DEPLOYER_ADDRESS=$(head -n 1 "$GENESIS_DIR/accounts.txt" | cut -d: -f1)
        echo "  📝 Deployer address: $DEPLOYER_ADDRESS"
        echo "  📝 L2 Chain ID: $L2_CHAIN_ID"
        echo "  📝 RPC URL: http://localhost:$L1_PORT"
        
        # Check if native-rollup directory exists
        NATIVE_ROLLUP_DIR="$SCRIPT_DIR/native-rollup"
        if [ ! -d "$NATIVE_ROLLUP_DIR" ]; then
            echo "  ❌ Step 6/7 failed: NativeRollup contract directory not found at $NATIVE_ROLLUP_DIR"
            echo "  💡 Skipping NativeRollup deployment."
            NATIVE_ROLLUP_ADDRESS=""
        else
            echo "  ✅ Step 6/7 complete: Contract directory found: $NATIVE_ROLLUP_DIR"
            
            # Build the contract first
            echo "  📍 Step 7/7: Building and deploying contract..."
            echo "  🔨 Building NativeRollup contract..."
            cd "$NATIVE_ROLLUP_DIR"
            
            BUILD_OUTPUT=$(forge build 2>&1)
            BUILD_EXIT_CODE=$?
            
            if [ $BUILD_EXIT_CODE -ne 0 ]; then
                echo "  ❌ Build failed (exit code: $BUILD_EXIT_CODE)"
                echo "  📝 Build output:"
                echo "$BUILD_OUTPUT" | tail -30
                NATIVE_ROLLUP_ADDRESS=""
            else
                echo "  ✅ Contract built successfully"
                
                # Deploy using forge create (simpler and more reliable)
                echo "  🚀 Deploying NativeRollup contract..."
                echo "  📝 Deployment parameters:"
                echo "     - RPC URL: http://localhost:$L1_PORT"
                echo "     - Constructor args: L2_CHAIN_ID=$L2_CHAIN_ID"
                echo "     - Contract: src/NativeRollup.sol:NativeRollup"
                
                # Deploy contract with constructor argument (chainId)
                # Using forge create which handles transaction and receipt properly
                # Note: Contract validates L2 chainId from execute transactions
                echo "  ⏳ Sending deployment transaction..."
                DEPLOY_OUTPUT=$(forge create \
                    --rpc-url "http://localhost:$L1_PORT" \
                    --private-key "$DEPLOYER_KEY" \
                    --constructor-args "$L2_CHAIN_ID" \
                    --broadcast \
                    --json \
                    src/NativeRollup.sol:NativeRollup 2>&1)
                
                DEPLOY_EXIT_CODE=$?
                echo "  📝 Deployment command exit code: $DEPLOY_EXIT_CODE"
                
                # Check if forge create failed
                if [ $DEPLOY_EXIT_CODE -ne 0 ]; then
                    echo "  ❌ Deployment failed (exit code: $DEPLOY_EXIT_CODE)"
                    echo "  📝 Error output:"
                    echo "$DEPLOY_OUTPUT" | head -40
                    NATIVE_ROLLUP_ADDRESS=""
                elif [ -z "$DEPLOY_OUTPUT" ]; then
                    echo "  ⚠️  No output from forge create"
                    NATIVE_ROLLUP_ADDRESS=""
                else
                    echo "  ✅ Received response from forge create"
                    echo "  📝 Parsing deployment output..."
                    
                    # Extract contract address from forge create output
                    # Check if output is valid JSON
                    if ! echo "$DEPLOY_OUTPUT" | jq empty 2>/dev/null; then
                        echo "  ⚠️  Invalid JSON output from forge create"
                        echo "  📝 Raw output (first 30 lines):"
                        echo "$DEPLOY_OUTPUT" | head -30
                        NATIVE_ROLLUP_ADDRESS=""
                    else
                        echo "  ✅ Valid JSON response received"
                        echo "  📝 Extracting contract address..."
                        
                        # Try multiple possible JSON field names for the contract address
                        # forge create --json output structure may vary by version
                        NATIVE_ROLLUP_ADDRESS=$(echo "$DEPLOY_OUTPUT" | jq -r '.deployedTo // .contractAddress // .address // empty' 2>/dev/null)
                        
                        # Try to get transaction hash from various possible fields
                        TX_HASH=$(echo "$DEPLOY_OUTPUT" | jq -r '.deployment.transaction.hash // .transactionHash // .txHash // .hash // empty' 2>/dev/null)
                        
                        echo "  📝 Extracted address: ${NATIVE_ROLLUP_ADDRESS:-<none>}"
                        echo "  📝 Extracted tx hash: ${TX_HASH:-<none>}"
                        
                        # Debug: show the actual JSON structure if address not found
                        if [ -z "$NATIVE_ROLLUP_ADDRESS" ] || [ "$NATIVE_ROLLUP_ADDRESS" = "null" ]; then
                            echo "  ⚠️  Could not extract address from JSON response"
                            echo "  📝 Full JSON structure:"
                            echo "$DEPLOY_OUTPUT" | jq '.' 2>/dev/null | head -40
                            
                            # Try to extract from transaction receipt if we have a tx hash
                            if [ -n "$TX_HASH" ] && [ "$TX_HASH" != "null" ] && [ "$TX_HASH" != "" ]; then
                                echo "  📝 Transaction hash found: $TX_HASH"
                                echo "  ⏳ Waiting for transaction to be mined..."
                                sleep 3
                                echo "  📝 Fetching transaction receipt..."
                                RECEIPT=$(cast receipt "$TX_HASH" --rpc-url "http://localhost:$L1_PORT" --json 2>/dev/null)
                                if [ -n "$RECEIPT" ]; then
                                    echo "  ✅ Receipt retrieved"
                                    NATIVE_ROLLUP_ADDRESS=$(echo "$RECEIPT" | jq -r '.contractAddress // .to // empty' 2>/dev/null)
                                    if [ -n "$NATIVE_ROLLUP_ADDRESS" ] && [ "$NATIVE_ROLLUP_ADDRESS" != "null" ] && [ "$NATIVE_ROLLUP_ADDRESS" != "" ]; then
                                        echo "  ✅ NativeRollup deployed at: $NATIVE_ROLLUP_ADDRESS (from receipt)"
                                    else
                                        echo "  ⚠️  Could not extract address from receipt"
                                        echo "  📝 Receipt structure:"
                                        echo "$RECEIPT" | jq '.' 2>/dev/null | head -20
                                    fi
                                else
                                    echo "  ⚠️  Could not retrieve transaction receipt"
                                fi
                            fi
                        fi
                        
                        # Final check and report
                        if [ -n "$NATIVE_ROLLUP_ADDRESS" ] && [ "$NATIVE_ROLLUP_ADDRESS" != "null" ] && [ "$NATIVE_ROLLUP_ADDRESS" != "" ]; then
                            echo "  ✅ Step 7/7 complete: NativeRollup deployed successfully!"
                            echo "  📍 Contract address: $NATIVE_ROLLUP_ADDRESS"
                            if [ -n "$TX_HASH" ] && [ "$TX_HASH" != "null" ] && [ "$TX_HASH" != "" ]; then
                                echo "  📝 Transaction hash: $TX_HASH"
                            fi
                        else
                            echo "  ⚠️  Step 7/7 incomplete: Deployment may have succeeded but address could not be determined"
                            if [ -n "$TX_HASH" ] && [ "$TX_HASH" != "null" ] && [ "$TX_HASH" != "" ]; then
                                echo "  📝 Transaction hash: $TX_HASH"
                                echo "  💡 You can check the contract address manually using:"
                                echo "     cast receipt $TX_HASH --rpc-url http://localhost:$L1_PORT"
                            fi
                            NATIVE_ROLLUP_ADDRESS=""
                        fi
                    fi
                fi
            fi
            cd "$SCRIPT_DIR"
        fi
    fi
fi
echo ""

# ========================================
# Summary
# ========================================
echo "✅ Devnet started successfully!"
echo ""
echo "📊 Services:"
echo "  🌐 L1 Node:      http://localhost:$L1_PORT"
echo "  🌐 L2 Node:      http://localhost:$L2_PORT"
echo "  🔧 L2 Engine:    http://localhost:$L2_ENGINE_PORT"
echo "  🎯 Sequencer:    http://localhost:$SEQUENCER_PORT"
echo "  📈 Metrics:      http://localhost:$SEQUENCER_METRICS_PORT"
echo ""
if [ -n "$NATIVE_ROLLUP_ADDRESS" ]; then
    echo "📦 Contracts:"
    echo "  📄 NativeRollup:  $NATIVE_ROLLUP_ADDRESS (L2 Chain ID: $L2_CHAIN_ID)"
    echo ""
fi
echo "📝 Accounts:"
echo "  Generated $NUM_WALLETS wallets with ${WALLET_BALANCE} ETH each"
echo "  Account details: $GENESIS_DIR/accounts.txt"
echo ""
echo "🛑 To stop all services:"
echo "  $0 --stop"
echo ""
echo "📖 View logs:"
echo "  docker logs -f native-quickstart-l1"
echo "  docker logs -f native-quickstart-l2"
echo "  docker logs -f native-quickstart-sequencer"
echo ""

