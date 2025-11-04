#!/bin/bash

# Docker Compose Development Environment Setup
# Ensures all prerequisites are met before starting services

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}INFO:${NC} $*"; }
success() { echo -e "${GREEN}SUCCESS:${NC} $*"; }
warn() { echo -e "${YELLOW}WARNING:${NC} $*"; }
error() { echo -e "${RED}ERROR:${NC} $*"; }

# Parse command line arguments
CLEAN=false
NO_CACHE=false
DETACHED=false
SKIP_PROMPT=false

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --clean         Clean up old containers and images before starting
    --no-cache      Build images without using cache
    --detached, -d  Run containers in detached mode (background)
    --yes, -y       Skip confirmation prompts
    --help, -h      Show this help message

Examples:
    $0                      # Interactive setup and start
    $0 --clean --yes        # Clean rebuild and start without prompts
    $0 -d -y                # Start in background without prompts
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --detached|-d)
            DETACHED=true
            shift
            ;;
        --yes|-y)
            SKIP_PROMPT=true
            shift
            ;;
        --help|-h)
            show_usage
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            ;;
    esac
done

echo ""
echo "════════════════════════════════════════════════"
echo "  BeatMap Local Development Setup"
echo "════════════════════════════════════════════════"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Step 1: Check Docker
info "Checking Docker..."
if ! command -v docker &> /dev/null; then
    error "Docker is not installed"
    error "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

if ! docker info &> /dev/null; then
    error "Docker daemon is not running"
    error "Please start Docker Desktop and try again"
    exit 1
fi
success "Docker is running"

# Step 2: Check docker-compose
info "Checking docker-compose..."
if ! command -v docker-compose &> /dev/null; then
    error "docker-compose is not installed"
    error "Please install docker-compose"
    exit 1
fi
success "docker-compose is available"

# Step 3: Ensure SSL certificates exist
info "Ensuring SSL certificates exist..."
if bash "$PROJECT_ROOT/ssl/ensure-dev-certs.sh"; then
    success "SSL certificates ready"
else
    error "Failed to ensure SSL certificates"
    exit 1
fi

# Step 4: Check for .env file
info "Checking for .env file..."
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    warn ".env file not found"
    info "Creating .env file from template..."

    cat > "$SCRIPT_DIR/.env" << 'EOF'
# API Keys - Replace with your actual keys
JAMBASE_API_KEY=your_jambase_api_key_here
TM_API_SECRET=your_ticketmaster_secret_here
TM_API_KEY=your_ticketmaster_key_here
GROQ_API_KEY=your_groq_api_key_here

# Ticketmaster Configuration
TM_BASE_URL=https://app.ticketmaster.com/discovery/v2
EOF

    warn "Created .env file - Please update with your API keys"
    warn "Edit $SCRIPT_DIR/.env and add your API keys"

    if [ "$SKIP_PROMPT" = false ]; then
        read -p "Press Enter to continue once you've updated the .env file..."
    fi
else
    success ".env file found"
fi

# Step 5: Clean up if requested
if [ "$CLEAN" = true ]; then
    echo ""
    info "Cleaning up Docker environment..."
    cd "$SCRIPT_DIR"

    # Stop and remove containers
    if docker-compose -f docker-compose.dev.yml ps -q 2>/dev/null | grep -q .; then
        info "Stopping existing containers..."
        docker-compose -f docker-compose.dev.yml down --volumes || true
    fi

    # Remove old images for beatmap services
    info "Removing old BeatMap images..."
    docker images | grep -E "beatmap|concert_backend|ticketmaster_provider|jambase_provider|groq_provider" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

    success "Cleanup complete"
fi

echo ""
echo "════════════════════════════════════════════════"
echo "  Setup Complete!"
echo "════════════════════════════════════════════════"
echo ""

# Determine if we should start services
START_SERVICES=false
if [ "$SKIP_PROMPT" = true ]; then
    START_SERVICES=true
else
    read -p "Start development environment now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        START_SERVICES=true
    fi
fi

if [ "$START_SERVICES" = true ]; then
    info "Starting development environment..."
    cd "$SCRIPT_DIR"

    # Build docker-compose command
    COMPOSE_CMD="docker-compose -f docker-compose.dev.yml up"

    if [ "$NO_CACHE" = true ]; then
        info "Building without cache..."
        COMPOSE_CMD="$COMPOSE_CMD --build --force-recreate"
    else
        COMPOSE_CMD="$COMPOSE_CMD --build"
    fi

    if [ "$DETACHED" = true ]; then
        COMPOSE_CMD="$COMPOSE_CMD -d"
    fi

    echo ""
    info "Running: $COMPOSE_CMD"
    eval "$COMPOSE_CMD"

    if [ "$DETACHED" = true ]; then
        echo ""
        success "Development environment is running in the background!"
        echo ""
        info "Access the application at:"
        echo "  Frontend: http://localhost (or https://localhost if SSL is configured)"
        echo "  Backend:  https://localhost:8443"
        echo ""
        info "To view logs:"
        echo "  docker-compose -f docker-compose.dev.yml logs -f"
        echo ""
        info "To stop services:"
        echo "  docker-compose -f docker-compose.dev.yml down"
        echo ""
    fi
else
    echo ""
    info "To start the development environment later, run:"
    echo "  cd $SCRIPT_DIR"
    echo "  docker-compose -f docker-compose.dev.yml up --build"
    echo ""
    info "Or use this script with options:"
    echo "  $0 --yes              # Start without prompts"
    echo "  $0 --clean --yes      # Clean rebuild"
    echo "  $0 -d -y              # Start in background"
    echo ""
fi
