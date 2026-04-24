#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Setting up OpenCode Docker environment..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker compose &> /dev/null; then
    echo "Note: Docker Compose not found. Will use docker commands instead."
    USE_COMPOSE=false
else
    USE_COMPOSE=true
fi

# Create .env from template if it doesn't exist
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "Creating .env from template..."
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
else
    echo "  .env file already exists, skipping."
fi

# Create workspace directory if it doesn't exist
echo "Creating workspace directory..."
mkdir -p "$PROJECT_DIR/workspace"

# Create data directories for OpenCode config
echo "Creating data directories..."
mkdir -p "$PROJECT_DIR/data/config" "$PROJECT_DIR/data/share"

# Create default OpenCode config with Ollama provider
echo "Creating OpenCode config with Ollama provider..."
OPENCODE_CONFIG_DIR="$PROJECT_DIR/data/config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

# Default config that will be merged with Ollama models at runtime
cat > "$OPENCODE_CONFIG_DIR/opencode.json" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        "llama3.3:70b": {
          "name": "Llama 3.3 70B"
        },
        "qwen3-coder-next:q4_K_M": {
          "name": "Qwen3 Coder Next"
        },
        "gemma4:31b": {
          "name": "Gemma 4 31B"
        }
      }
    }
  },
  "model": "ollama/llama3.3:70b"
}
EOF

# Build the Docker image
echo "Building Docker image..."
if [ "$USE_COMPOSE" = true ]; then
    docker compose -f "$PROJECT_DIR/docker-compose.yml" build
else
    docker build -t opencode-isolated "$PROJECT_DIR"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Quick start:"
echo "  1. ./scripts/run.sh                    # Start container"
echo "  2. opencode auth login                 # Authenticate (OAuth)"
echo "  3. opencode                            # Start coding!"
echo ""
echo "Or use API keys instead:"
echo "  1. nano .env                           # Add your API key(s)"
echo "  2. ./scripts/run.sh --run              # Start OpenCode directly"
echo ""
echo "See README.md for more information."
