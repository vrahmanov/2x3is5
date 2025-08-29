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
CLUSTER_DOMAIN=${CLUSTER_DOMAIN:-"local.io"}

echo -e "${BLUE}Infrastructure Cleanup${NC}"
echo "======================="

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

# Confirm cleanup
echo ""
echo -e "${YELLOW}WARNING: This will delete the entire K3D cluster and all infrastructure!${NC}"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled"
    exit 0
fi

# Delete K3D cluster
echo ""
print_status "Deleting K3D cluster '$CLUSTER_NAME'..."
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    k3d cluster delete "$CLUSTER_NAME"
    print_status "K3D cluster deleted"
else
    print_warning "K3D cluster '$CLUSTER_NAME' not found"
fi

# Remove host entries
echo ""
print_status "Removing host entries for $CLUSTER_DOMAIN..."
if grep -q "$CLUSTER_DOMAIN" /etc/hosts; then
    sudo sed -i.bak "/$CLUSTER_DOMAIN/d" /etc/hosts
    print_status "Host entries removed"
else
    print_warning "No host entries found for $CLUSTER_DOMAIN"
fi

# Clean up Docker images
echo ""
print_status "Cleaning up Docker images..."
docker image prune -f
print_status "Docker images cleaned"

# Clean up Docker volumes
echo ""
print_status "Cleaning up Docker volumes..."
docker volume prune -f
print_status "Docker volumes cleaned"

# Clean up temporary files
echo ""
print_status "Cleaning up temporary files..."
rm -rf k3dvol
rm -f /tmp/argocd_port_forward.pid
print_status "Temporary files cleaned"

echo ""
print_status "Infrastructure cleanup completed successfully!"
