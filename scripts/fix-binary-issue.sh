#!/bin/bash

# Fix Binary Architecture Issue Script
# ====================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${BLUE}Fixing Binary Architecture Issue${NC}"
echo "====================================="
echo ""

# Detect current architecture
print_status "Detecting system architecture..."
CURRENT_ARCH=$(uname -m)
print_success "Current architecture: $CURRENT_ARCH"

# Clean up existing resources
print_status "Cleaning up existing deployment..."
kubectl delete namespace music-app --force --grace-period=0 2>/dev/null || true

# Remove existing Docker image
print_status "Removing existing Docker image..."
docker rmi music-app:latest 2>/dev/null || true

# Rebuild with correct architecture
print_status "Rebuilding application with correct architecture..."
make app_build

if [ $? -eq 0 ]; then
    print_success "Application rebuilt successfully!"
    
    # Deploy the application
    print_status "Deploying application..."
    make app_deploy
    
    if [ $? -eq 0 ]; then
        print_success "Deployment completed successfully!"
        echo ""
        echo "Testing the application..."
        sleep 10
        
        # Test the application
        if curl -s http://music.local.io:44134/health >/dev/null 2>&1; then
            print_success "Application is responding correctly!"
            echo ""
            echo "Access your application at:"
            echo "  http://music.local.io:44134"
            echo "  http://music.local.io:44134/api/v1/music-albums?key=100"
        else
            print_warning "Application may still be starting up..."
            echo "Check status with: kubectl get pods -n music-app"
        fi
    else
        print_error "Deployment failed"
        exit 1
    fi
else
    print_error "Build failed"
    exit 1
fi
