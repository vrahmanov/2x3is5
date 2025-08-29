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

# Build for Linux (for Docker container)
print_status "Building for Linux architecture..."
GOOS=linux GOARCH=amd64 go build -o server main.go

if [ $? -eq 0 ]; then
    print_status "Go application built successfully"
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
