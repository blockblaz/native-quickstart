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
    --override.osaka 0

echo "  ✅ L1 node started on port $L1_PORT"
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
    --override.osaka 0

echo "  ✅ L2 node started on port $L2_PORT (Engine API on $L2_ENGINE_PORT)"
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

