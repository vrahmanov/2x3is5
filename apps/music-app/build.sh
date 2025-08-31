#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME=${CLUSTER_NAME:-"localdev"}

echo -e "${BLUE}Music App Build Script${NC}"
echo "========================"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Go is available
if ! command -v go &> /dev/null; then
    print_error "Go is not installed"
    echo ""
    echo "Please install Go:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  brew install go"
    else
        echo "  sudo apt install golang-go"
    fi
    exit 1
fi

# Build Go application
print_status "Building Go application..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/src"

# Check if main.go exists
if [ ! -f "main.go" ]; then
    print_error "main.go not found in src directory"
    exit 1
fi

# Detect target architecture for Docker
print_status "Detecting target architecture..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # On macOS, check if it's Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        TARGET_ARCH="arm64"
        print_status "Detected Apple Silicon (ARM64)"
    else
        TARGET_ARCH="amd64"
        print_status "Detected Intel Mac (AMD64)"
    fi
else
    # On Linux, check the architecture
    if [[ $(uname -m) == "aarch64" ]]; then
        TARGET_ARCH="arm64"
        print_status "Detected ARM64 Linux"
    else
        TARGET_ARCH="amd64"
        print_status "Detected AMD64 Linux"
    fi
fi

# Build for Linux with detected architecture
print_status "Building for Linux $TARGET_ARCH architecture..."
GOOS=linux GOARCH=$TARGET_ARCH go build -o server main.go

if [ $? -eq 0 ]; then
    print_status "Go application built successfully"
    
    # Verify the binary
    if [ -f "server" ]; then
        print_status "Binary verification:"
        if command -v file >/dev/null 2>&1; then
            file server
        else
            print_warning "file command not available, skipping binary type check"
        fi
        ls -la server
    else
        print_error "Binary 'server' not found after build"
        exit 1
    fi
else
    print_error "Failed to build Go application"
    exit 1
fi

# Build Docker image
print_status "Building Docker image..."
cd "$SCRIPT_DIR/k8s/docker"

# Copy the built binary
cp "$SCRIPT_DIR/src/server" .

# Build the image
docker build -t music-app:latest .

# Clean up
rm server

if [ $? -eq 0 ]; then
    print_status "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Load image into K3D
print_status "Loading Docker image into K3D cluster..."
k3d image import music-app:latest -c "$CLUSTER_NAME"

if [ $? -eq 0 ]; then
    print_status "Docker image loaded into K3D successfully"
else
    print_error "Failed to load Docker image into K3D"
    exit 1
fi

print_status "Application build completed successfully!"
