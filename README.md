# Native Quickstart

A tool to quickly bring up a devnet with:
- **L1 node** running `0xpartha/geth:latest`
- **L2 node** running `0xpartha/geth:latest`
- **Native sequencer** running `0xpartha/native-sequencer:latest`

## Features

- ✅ **Optional Genesis Generation**: Generate genesis file with `--generate-genesis` flag (10 wallets, 100 ETH each by default)
- ✅ **Pre-configured Accounts**: All accounts are pre-funded and ready to use
- ✅ **Safe Defaults**: Uses existing genesis file by default (prevents accidental overwrites)
- ✅ **Easy Configuration**: Configurable via command-line arguments or environment variables
- ✅ **Docker-based**: Uses Docker containers for easy setup and cleanup
- ✅ **Single Command**: Start everything with one command

## Requirements

- **Docker**: Required to run geth and sequencer containers
  - Install from: [Docker Desktop](https://docs.docker.com/get-docker/)
- **Python 3**: Required for genesis generation
- **curl**: Required for health checks (usually pre-installed)

### Optional

- **eth-account** Python library: For proper Ethereum address derivation
  ```bash
  pip install eth-account
  ```
  If not installed, the script uses a deterministic fallback method suitable for devnets.

## Quick Start

### Basic Usage

```bash
# First time: Generate genesis file and start devnet
./start-devnet.sh --generate-genesis

# Subsequent runs: Use existing genesis file (default behavior)
./start-devnet.sh

# Stop all services
./start-devnet.sh --stop
```

**Important**: The script uses existing genesis files by default. If no genesis file exists, you'll get an error prompting you to use `--generate-genesis`.

### Custom Configuration

```bash
# Generate genesis with custom parameters and start
./start-devnet.sh --generate-genesis --num-wallets 20 --wallet-balance 200

# Start with custom ports (uses existing genesis)
./start-devnet.sh --l1-port 8545 --l2-port 18545 --sequencer-port 18547

# Clean start (removes existing data, then use existing genesis)
./start-devnet.sh --clean-data

# Clean start with new genesis generation
./start-devnet.sh --clean-data --generate-genesis

# Explicitly generate genesis file (overwrites existing)
./start-devnet.sh --generate-genesis

# Skip genesis generation (use existing genesis file - default behavior)
./start-devnet.sh --no-genesis

# Use custom Docker images
./start-devnet.sh --geth-image mygeth:latest --sequencer-image mysequencer:latest
```

## Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--data-dir DIR` | Data directory | `./data` |
| `--genesis-dir DIR` | Genesis directory | `./genesis` |
| `--num-wallets N` | Number of wallets to create | `10` |
| `--wallet-balance ETH` | Balance per wallet in ETH | `100` |
| `--l1-chain-id ID` | L1 chain ID | `61971` |
| `--l2-chain-id ID` | L2 chain ID | `61972` |
| `--l1-port PORT` | L1 RPC port | `8545` |
| `--l2-port PORT` | L2 RPC port | `18545` |
| `--l2-engine-port PORT` | L2 Engine API port | `18551` |
| `--sequencer-port PORT` | Sequencer RPC port | `18547` |
| `--sequencer-metrics PORT` | Sequencer metrics port | `9090` |
| `--geth-image IMAGE` | Geth Docker image | `0xpartha/geth:latest` |
| `--sequencer-image IMAGE` | Sequencer Docker image | `0xpartha/native-sequencer:latest` |
| `--clean-data` | Clean data directories before starting | `false` |
| `--generate-genesis` | Generate genesis file (overwrites existing) | `false` (use existing) |
| `--no-genesis` | Skip genesis generation (default behavior) | `true` (default) |
| `--stop` | Stop all running containers | - |
| `--help` | Show help message | - |

**Note**: `--no-genesis` is the default behavior. The script will use existing genesis files and fail with a clear error message if the genesis file doesn't exist, prompting you to use `--generate-genesis`.

## Environment Variables

All command-line options can also be set via environment variables:

```bash
export DATA_DIR=./my-data
export NUM_WALLETS=20
export WALLET_BALANCE=200
export L1_PORT=8545
export L2_PORT=18545
./start-devnet.sh
```

## Services

After starting, the following services are available:

- **L1 Node**: `http://localhost:8545` (default)
- **L2 Node**: `http://localhost:18545` (default)
- **L2 Engine API**: `http://localhost:18551` (default)
- **Sequencer**: `http://localhost:18547` (default)
- **Sequencer Metrics**: `http://localhost:9090` (default)

## Account Management

### Generated Accounts

When you generate a genesis file (with `--generate-genesis`), accounts are created and saved to:
- `genesis/accounts.txt` - Contains addresses and private keys in format: `address:private_key`
- `genesis/genesis.json` - Genesis file with pre-funded accounts

### Using Accounts

You can use the accounts in your applications:

```bash
# View accounts
cat genesis/accounts.txt

# Extract first account address
head -n 1 genesis/accounts.txt | cut -d: -f1

# Extract first account private key
head -n 1 genesis/accounts.txt | cut -d: -f2
```

### Example: Send Transaction

```bash
# Get first account
ACCOUNT=$(head -n 1 genesis/accounts.txt | cut -d: -f1)
PRIVATE_KEY=$(head -n 1 genesis/accounts.txt | cut -d: -f2)

# Send transaction via L1
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"eth_sendTransaction\",
    \"params\": [{
      \"from\": \"$ACCOUNT\",
      \"to\": \"0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb\",
      \"value\": \"0x2386f26fc10000\"
    }],
    \"id\": 1
  }"
```

## Monitoring

### View Logs

```bash
# L1 node logs
docker logs -f native-quickstart-l1

# L2 node logs
docker logs -f native-quickstart-l2

# Sequencer logs
docker logs -f native-quickstart-sequencer
```

### Check Status

```bash
# Check if containers are running
docker ps | grep native-quickstart

# Check L1 node
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Check L2 node
curl -X POST http://localhost:18545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Check sequencer metrics
curl http://localhost:9090
```

## Stopping the Devnet

```bash
# Stop all containers
./start-devnet.sh --stop

# Or manually
docker stop native-quickstart-l1 native-quickstart-l2 native-quickstart-sequencer
docker rm native-quickstart-l1 native-quickstart-l2 native-quickstart-sequencer
```

## Data Persistence

Data is stored in the `data/` directory by default:
- `data/l1/` - L1 node data
- `data/l2/` - L2 node data
- `data/sequencer/` - Sequencer data

To start fresh:
```bash
./start-devnet.sh --clean-data
```

## Genesis File

The genesis file is generated in `genesis/genesis.json` and includes:
- Pre-funded accounts (10 wallets with 100 ETH each by default)
- Chain configuration
- Network ID

### Genesis Generation Behavior

The script defaults to using existing genesis files for safety:
- **Default (`--no-genesis`)**: Use existing genesis file
  - If genesis file exists: Uses it and starts the devnet
  - If genesis file doesn't exist: Shows error message prompting to use `--generate-genesis`
- **`--generate-genesis`**: Generate a new genesis file (overwrites existing if present)

**Error Message**: If you run the script without `--generate-genesis` and no genesis file exists, you'll see:
```
❌ Error: Genesis file not found: ./genesis/genesis.json

   Please run the script with --generate-genesis option to create a new genesis file:
   ./start-devnet.sh --generate-genesis

   Or create genesis.json manually in ./genesis
```

Examples:
```bash
# First time setup: Generate genesis and start
./start-devnet.sh --generate-genesis

# Subsequent runs: Use existing genesis (default)
./start-devnet.sh

# Regenerate genesis with custom parameters
./start-devnet.sh --generate-genesis --num-wallets 20 --wallet-balance 200

# Generate genesis file manually, then start
./generate-genesis.sh --num-wallets 10 --wallet-balance 100
./start-devnet.sh
```

## Troubleshooting

### Port Already in Use

If a port is already in use, specify different ports:
```bash
./start-devnet.sh --l1-port 28545 --l2-port 28546 --sequencer-port 28547
```

### Container Won't Start

Check logs:
```bash
docker logs native-quickstart-l1
docker logs native-quickstart-l2
docker logs native-quickstart-sequencer
```

### Genesis File Issues

**Error: "Genesis file not found"**
```
❌ Error: Genesis file not found: ./genesis/genesis.json

   Please run the script with --generate-genesis option to create a new genesis file:
   ./start-devnet.sh --generate-genesis
```

Solution: Run with `--generate-genesis` flag:
```bash
./start-devnet.sh --generate-genesis
```

**Regenerate existing genesis file:**
```bash
./start-devnet.sh --generate-genesis
```

**Clean start with new genesis:**
```bash
./start-devnet.sh --clean-data --generate-genesis
```

### Docker Image Pull Fails

The script will try to use local images if pull fails. Make sure you have the images:
```bash
docker pull 0xpartha/geth:latest
docker pull 0xpartha/native-sequencer:latest
```

### Account Generation Issues

If you encounter issues with account generation, install the eth-account library:
```bash
pip install eth-account
```

## Advanced Usage

### Custom Chain IDs

```bash
# Use custom chain IDs (defaults are 61971 for L1, 61972 for L2)
./start-devnet.sh --l1-chain-id 1337 --l2-chain-id 1338
```

### Multiple Devnets

Run multiple devnets on different ports:
```bash
# Devnet 1
DATA_DIR=./data1 ./start-devnet.sh --l1-port 8545 --l2-port 18545 --sequencer-port 18547

# Devnet 2
DATA_DIR=./data2 ./start-devnet.sh --l1-port 28545 --l2-port 28546 --sequencer-port 28547
```

### Integration with Other Tools

The devnet can be integrated with other development tools:

```bash
# Set environment variables for your tools
export L1_RPC_URL=http://localhost:8545
export L2_RPC_URL=http://localhost:18545
export SEQUENCER_RPC_URL=http://localhost:18547

# Your tool can now connect to the devnet
```

## License

See LICENSE file.

