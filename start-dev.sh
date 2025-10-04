#!/bin/bash

# Quick Start Script for BeatMap Development Environment
# This is a simple wrapper that calls the main setup script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Forward all arguments to the main setup script
exec "$SCRIPT_DIR/src/docker-compose-dev-setup.sh" "$@"
