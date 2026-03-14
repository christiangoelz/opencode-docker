#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Clean up OpenCode Docker resources."
    echo ""
    echo "Options:"
    echo "  --full    Remove everything: containers, images, volumes, and config"
    echo "  --help    Show this help message"
    echo ""
    echo "Without --full, only stops running containers."
}

FULL_CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            FULL_CLEANUP=true
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

echo "Stopping OpenCode containers..."
docker stop opencode-sandbox 2>/dev/null || true
docker rm opencode-sandbox 2>/dev/null || true

if command -v docker compose &> /dev/null; then
    cd "$PROJECT_DIR"
    docker compose down 2>/dev/null || true
fi

if [ "$FULL_CLEANUP" = true ]; then
    echo "Removing OpenCode Docker image..."
    docker rmi opencode-isolated 2>/dev/null || true

    echo "Removing OpenCode volumes..."
    docker volume rm opencode-config 2>/dev/null || true
    docker volume rm opencode-data 2>/dev/null || true

    echo ""
    echo "Full cleanup complete. Run ./scripts/setup.sh to rebuild."
else
    echo ""
    echo "Containers stopped. Use --full to remove images and volumes."
fi
