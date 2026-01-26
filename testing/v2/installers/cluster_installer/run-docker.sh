#!/bin/bash
# Helper script to run the cluster installer in Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Calculate repo root: cluster_installer -> installers -> v2 -> testing -> repo root
# Path structure: testing/v2/installers/cluster_installer/
# So we need to go up 4 levels: ../../../..
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Verify we're in the right place
if [ ! -f "$REPO_ROOT/testing/v2/installers/cluster_installer/Dockerfile" ]; then
    echo -e "${RED}Error: Could not find Dockerfile${NC}"
    echo -e "${YELLOW}Expected at: $REPO_ROOT/testing/v2/installers/cluster_installer/Dockerfile${NC}"
    echo -e "${YELLOW}Script directory: $SCRIPT_DIR${NC}"
    echo -e "${YELLOW}Repo root: $REPO_ROOT${NC}"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

IMAGE_NAME="lme-cluster-installer"

echo -e "${GREEN}=== LME Cluster Installer - Docker Runner ===${NC}"

# Check for exporter.txt in current directory or parent directory
EXPORTER_FILE=""
if [ -f "$SCRIPT_DIR/exporter.txt" ]; then
    EXPORTER_FILE="$SCRIPT_DIR/exporter.txt"
elif [ -f "$(dirname "$SCRIPT_DIR")/exporter.txt" ]; then
    EXPORTER_FILE="$(dirname "$SCRIPT_DIR")/exporter.txt"
    echo -e "${YELLOW}Using exporter.txt from parent directory${NC}"
else
    echo -e "${RED}Error: exporter.txt not found in $SCRIPT_DIR or $(dirname "$SCRIPT_DIR")${NC}"
    echo -e "${YELLOW}Please create exporter.txt in one of these locations:${NC}"
    echo -e "  - $SCRIPT_DIR/exporter.txt"
    echo -e "  - $(dirname "$SCRIPT_DIR")/exporter.txt"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/output"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Build the image if it doesn't exist or if --rebuild is passed
if [ "$1" = "--rebuild" ] || ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo -e "${YELLOW}Building Docker image...${NC}"
    # Build from repo root with correct context
    cd "$REPO_ROOT"
    
    # Verify we're in the right place
    if [ ! -f "testing/v2/installers/cluster_installer/Dockerfile" ]; then
        echo -e "${RED}Error: Dockerfile not found${NC}"
        echo -e "${YELLOW}Current directory: $(pwd)${NC}"
        echo -e "${YELLOW}Expected Dockerfile at: testing/v2/installers/cluster_installer/Dockerfile${NC}"
        echo -e "${YELLOW}Repo root calculated as: $REPO_ROOT${NC}"
        exit 1
    fi
    
    # Verify the testing directory exists (needed for COPY in Dockerfile)
    if [ ! -d "testing" ]; then
        echo -e "${RED}Error: 'testing' directory not found in repo root${NC}"
        echo -e "${YELLOW}Current directory: $(pwd)${NC}"
        echo -e "${YELLOW}Repo root: $REPO_ROOT${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Building from: $(pwd)${NC}"
    docker build -f testing/v2/installers/cluster_installer/Dockerfile -t "$IMAGE_NAME" .
    echo -e "${GREEN}Image built successfully${NC}"
    # Remove --rebuild from arguments if present
    if [ "$1" = "--rebuild" ]; then
        shift
    fi
else
    echo -e "${GREEN}Using existing Docker image${NC}"
fi

# Run the container
echo -e "${GREEN}Running cluster installer...${NC}"
echo ""

# Build docker run command array
# Mount paths:
# - LME repo as read-only for reference
# - output directory for persisting generated files (password, machines.json)
# - exporter.txt for configuration
# - Azure credentials for authentication
DOCKER_ARGS=(
    run -it --rm
    --network host
    -v "$REPO_ROOT:/workspace/LME:ro"
    -v "$SCRIPT_DIR/output:/workspace/testing/v2/installers/cluster_installer/output"
    -v "$EXPORTER_FILE:/workspace/testing/v2/installers/exporter.txt:ro"
    -v "$HOME/.azure:/root/.azure:ro"
)

# Add Azure environment variables if they're set
if [ -n "$AZURE_CLIENT_ID" ]; then
    DOCKER_ARGS+=(-e "AZURE_CLIENT_ID=$AZURE_CLIENT_ID")
fi
if [ -n "$AZURE_CLIENT_SECRET" ]; then
    DOCKER_ARGS+=(-e "AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET")
fi
if [ -n "$AZURE_TENANT_ID" ]; then
    DOCKER_ARGS+=(-e "AZURE_TENANT_ID=$AZURE_TENANT_ID")
fi
if [ -n "$AZURE_SUBSCRIPTION_ID" ]; then
    DOCKER_ARGS+=(-e "AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID")
fi

# Build the command to run inside container
# Use printf %q to properly escape arguments
SCRIPT_CMD="cd /workspace/testing/v2/installers/cluster_installer && ./setup_cluster.sh"
if [ $# -gt 0 ]; then
    for arg in "$@"; do
        SCRIPT_CMD="$SCRIPT_CMD $(printf '%q' "$arg")"
    done
fi

# Add the image and command
DOCKER_ARGS+=(
    "$IMAGE_NAME"
    bash -c "$SCRIPT_CMD"
)

# Execute the command
docker "${DOCKER_ARGS[@]}"

# Check exit code
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=== Cluster setup completed successfully ===${NC}"
    echo -e "${YELLOW}Check the output/ directory for generated files${NC}"
else
    echo ""
    echo -e "${RED}=== Cluster setup failed (exit code: $EXIT_CODE) ===${NC}"
fi

exit $EXIT_CODE
