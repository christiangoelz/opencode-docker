#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env file if present
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Default values
WORKSPACE="${WORKSPACE_PATH:-$(pwd)/workspace}"
IMAGE_NAME="opencode-isolated"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Run OpenCode in an isolated Docker container."
    echo ""
    echo "Options:"
    echo "  --workspace PATH      Path to workspace directory (default: ./workspace)"
    echo "  --run                 Start opencode TUI immediately"
    echo "  --no-clipboard        Disable clipboard (X11) support"
    echo "  --network-host        Use host network mode (access localhost services like Ollama)"
    echo "  --help                Show this help message"
}

RUN_OPENCODE=false
NO_CLIPBOARD=false
NETWORK_HOST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --workspace)
            WORKSPACE="$2"
            shift 2
            ;;
        --run)
            RUN_OPENCODE=true
            shift
            ;;
        --no-clipboard)
            NO_CLIPBOARD=true
            shift
            ;;
        --network-host)
            NETWORK_HOST=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Ensure workspace exists
mkdir -p "$WORKSPACE"

# Ensure data directories exist with correct ownership (your user, not root)
mkdir -p "$PROJECT_DIR/data/config" "$PROJECT_DIR/data/share" "$PROJECT_DIR/data/share/log"

# Check if image exists
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "Image not found. Run ./scripts/setup.sh first."
    exit 1
fi

# Build environment flags - pass all API keys
# Terminal settings (critical for TUI)
ENV_FLAGS="-e TERM=${TERM:-xterm-256color}"
ENV_FLAGS="$ENV_FLAGS -e COLORTERM=${COLORTERM:-truecolor}"
ENV_FLAGS="$ENV_FLAGS -e LINES=${LINES:-$(tput lines 2>/dev/null || echo 24)}"
ENV_FLAGS="$ENV_FLAGS -e COLUMNS=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
ENV_FLAGS="$ENV_FLAGS -e HOME=/home/opencode"
# Pin XDG dirs to mounted volumes so auth + sessions persist across restarts
ENV_FLAGS="$ENV_FLAGS -e XDG_DATA_HOME=/home/opencode/.local/share"
ENV_FLAGS="$ENV_FLAGS -e XDG_CONFIG_HOME=/home/opencode/.config"

[ -n "$ANTHROPIC_API_KEY" ] && ENV_FLAGS="$ENV_FLAGS -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
[ -n "$OPENAI_API_KEY" ] && ENV_FLAGS="$ENV_FLAGS -e OPENAI_API_KEY=$OPENAI_API_KEY"
[ -n "$GEMINI_API_KEY" ] && ENV_FLAGS="$ENV_FLAGS -e GEMINI_API_KEY=$GEMINI_API_KEY"
[ -n "$GROQ_API_KEY" ] && ENV_FLAGS="$ENV_FLAGS -e GROQ_API_KEY=$GROQ_API_KEY"
[ -n "$OPENROUTER_API_KEY" ] && ENV_FLAGS="$ENV_FLAGS -e OPENROUTER_API_KEY=$OPENROUTER_API_KEY"
[ -n "$GITHUB_TOKEN" ] && ENV_FLAGS="$ENV_FLAGS -e GITHUB_TOKEN=$GITHUB_TOKEN"

# Local models (Ollama)
if [ -n "$LOCAL_ENDPOINT" ]; then
    ENV_FLAGS="$ENV_FLAGS -e LOCAL_ENDPOINT=$LOCAL_ENDPOINT"
elif [ -n "$OLLAMA_PORT" ] || [ -n "$OLLAMA_HOST" ]; then
    local_endpoint="http://${OLLAMA_HOST:-localhost}:${OLLAMA_PORT:-11434}"
    ENV_FLAGS="$ENV_FLAGS -e LOCAL_ENDPOINT=$local_endpoint"
fi

# Azure OpenAI
[ -n "$AZURE_OPENAI_ENDPOINT" ] && ENV_FLAGS="$ENV_FLAGS -e AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT"
[ -n "$AZURE_OPENAI_API_KEY" ] && ENV_FLAGS="$ENV_FLAGS -e AZURE_OPENAI_API_KEY=$AZURE_OPENAI_API_KEY"
[ -n "$AZURE_OPENAI_API_VERSION" ] && ENV_FLAGS="$ENV_FLAGS -e AZURE_OPENAI_API_VERSION=$AZURE_OPENAI_API_VERSION"

# AWS Bedrock
[ -n "$AWS_ACCESS_KEY_ID" ] && ENV_FLAGS="$ENV_FLAGS -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
[ -n "$AWS_SECRET_ACCESS_KEY" ] && ENV_FLAGS="$ENV_FLAGS -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
[ -n "$AWS_REGION" ] && ENV_FLAGS="$ENV_FLAGS -e AWS_REGION=$AWS_REGION"

# Volume mounts
VOLUME_FLAGS="-v $WORKSPACE:/workspace"
VOLUME_FLAGS="$VOLUME_FLAGS -v $PROJECT_DIR/data/config:/home/opencode/.config/opencode"
VOLUME_FLAGS="$VOLUME_FLAGS -v $PROJECT_DIR/data/share:/home/opencode/.local/share/opencode"

if [ "$NO_CLIPBOARD" = false ]; then
    if [ -d "/tmp/.X11-unix" ]; then
        VOLUME_FLAGS="$VOLUME_FLAGS -v /tmp/.X11-unix:/tmp/.X11-unix:ro"
        ENV_FLAGS="$ENV_FLAGS -e DISPLAY=${DISPLAY:-:0}"
    fi
fi

# Display startup info
echo "Starting OpenCode container..."
echo "  Workspace:  $WORKSPACE"
if [ "$NETWORK_HOST" = true ]; then
    echo "  Network:    host (can access localhost:11434 etc.)"
else
    echo "  Network:    bridge"
fi

# Build command
if [ "$RUN_OPENCODE" = true ]; then
    CMD="opencode"
else
    CMD=""
fi

# Build network flag and extra options for host networking
EXTRA_FLAGS=""
if [ "$NETWORK_HOST" = true ]; then
    NETWORK_FLAG="--network host"
    # With host networking, we need to ensure proper PTY handling
    # Mount the host's devpts to ensure TUI apps work correctly
    EXTRA_FLAGS="--privileged=false"
    # Pass through the actual TTY device for proper terminal handling
    if [ -t 0 ]; then
        TTY_DEVICE=$(tty 2>/dev/null || true)
        if [ -n "$TTY_DEVICE" ] && [ -c "$TTY_DEVICE" ]; then
            ENV_FLAGS="$ENV_FLAGS -e GPG_TTY=$TTY_DEVICE"
        fi
    fi
else
    NETWORK_FLAG=""
fi

# Remove old container if exists
docker rm -f opencode-sandbox 2>/dev/null || true

# Run container with proper TTY settings
# Note: Using 'docker run -it' allocates a pseudo-TTY
exec docker run --rm -it \
    --init \
    $VOLUME_FLAGS \
    $NETWORK_FLAG \
    $EXTRA_FLAGS \
    --name opencode-sandbox \
    $ENV_FLAGS \
    "$IMAGE_NAME" \
    $CMD
