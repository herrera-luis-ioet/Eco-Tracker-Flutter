#!/bin/bash

# Exit on any error
set -e

# Configuration
FLUTTER_VERSION="3.16.5"  # Specify the Flutter version
FLUTTER_CHANNEL="stable"   # Use stable channel for production
FLUTTER_INSTALL_DIR="/opt/flutter"  # Installation directory

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Log function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running with sudo/root
if [ "$EUID" -ne 0 ]; then
    error "Please run with sudo or as root"
fi

# Create installation directory
log "Creating Flutter installation directory..."
mkdir -p "$FLUTTER_INSTALL_DIR"

# Download Flutter SDK
log "Downloading Flutter SDK..."
curl -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz || error "Failed to download Flutter SDK"

# Extract Flutter SDK
log "Extracting Flutter SDK..."
tar xf flutter.tar.xz -C "$FLUTTER_INSTALL_DIR" --strip-components=1 || error "Failed to extract Flutter SDK"

# Clean up downloaded archive
rm flutter.tar.xz

# Set up environment variables
log "Setting up environment variables..."
echo "export PATH=\$PATH:$FLUTTER_INSTALL_DIR/bin" > /etc/profile.d/flutter.sh
chmod +x /etc/profile.d/flutter.sh
source /etc/profile.d/flutter.sh

# Pre-download development binaries (running flutter doctor in CI mode)
log "Running initial setup..."
export CI=true
export FLUTTER_ROOT="$FLUTTER_INSTALL_DIR"
"$FLUTTER_INSTALL_DIR/bin/flutter" doctor --no-analytics || error "Flutter doctor failed"

# Precache Flutter dependencies
log "Precaching Flutter dependencies..."
"$FLUTTER_INSTALL_DIR/bin/flutter" precache || error "Flutter precache failed"

# Configure Flutter for CI environment
log "Configuring Flutter for CI environment..."
"$FLUTTER_INSTALL_DIR/bin/flutter" config --no-analytics || error "Failed to disable analytics"
"$FLUTTER_INSTALL_DIR/bin/flutter" config --enable-web || error "Failed to enable web support"
"$FLUTTER_INSTALL_DIR/bin/flutter" config --no-enable-android || error "Failed to configure Android settings"
"$FLUTTER_INSTALL_DIR/bin/flutter" config --no-enable-ios || error "Failed to configure iOS settings"

# Verify installation
log "Verifying Flutter installation..."
"$FLUTTER_INSTALL_DIR/bin/flutter" --version || error "Failed to verify Flutter installation"

log "Flutter SDK installation completed successfully!"