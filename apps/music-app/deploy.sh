#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_DOMAIN=${CLUSTER_DOMAIN:-"local.io"}
HTTP_PORT=${HTTP_PORT:-"44134"}
HTTPS_PORT=${HTTPS_PORT:-"6600"}

echo -e "${BLUE}Music App Deployment Script${NC}"
echo "================================"

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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

# Check if cluster is accessible
print_status "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Prepare manifests
print_status "Preparing manifests..."

# Create Redis data ConfigMap
print_status "Creating Redis data ConfigMap..."
kubectl create configmap redis-data --from-file=dump.rdb="$PROJECT_ROOT/configs/data.rdb" -n music-app --dry-run=client -o yaml > "$SCRIPT_DIR/k8s/k8s/05-redis-data.yaml"

# Update ingress with correct domain
print_status "Updating ingress with cluster domain: $CLUSTER_DOMAIN"
sed "s/{{CLUSTER_DOMAIN}}/$CLUSTER_DOMAIN/g" "$SCRIPT_DIR/k8s/k8s/04-ingress.yaml" > "$SCRIPT_DIR/k8s/k8s/04-ingress-updated.yaml"

# Apply manifests
print_status "Applying Kubernetes manifests..."

# Create namespace first
kubectl apply -f "$SCRIPT_DIR/k8s/k8s/01-namespace.yaml"

# Apply secrets and configmaps
kubectl apply -f "$SCRIPT_DIR/k8s/k8s/05-secrets-configmaps.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/k8s/05-redis-data.yaml"

# Apply Redis deployment
kubectl apply -f "$SCRIPT_DIR/k8s/k8s/02-redis-deployment.yaml"

# Wait for Redis to be ready
print_status "Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=redis -n music-app --timeout=300s

# Apply music app deployment
kubectl apply -f "$SCRIPT_DIR/k8s/k8s/03-music-app-deployment.yaml"

# Wait for music app to be ready
print_status "Waiting for music app to be ready..."
kubectl wait --for=condition=ready pod -l app=music-app -n music-app --timeout=300s

# Apply ingress
kubectl apply -f "$SCRIPT_DIR/k8s/k8s/04-ingress-updated.yaml"

# Add host entry
print_status "Adding host entry to /etc/hosts..."
if ! grep -q "music.$CLUSTER_DOMAIN" /etc/hosts; then
    echo "127.0.0.1 music.$CLUSTER_DOMAIN" | sudo tee -a /etc/hosts
    print_status "Host entry added"
else
    print_status "Host entry already exists"
fi

# Wait for ingress to be ready
print_status "Waiting for ingress to be ready..."
sleep 10

print_status "Deployment completed successfully!"
echo ""
echo "Music App Access Information:"
echo "============================="
echo "HTTP URL: http://music.$CLUSTER_DOMAIN:$HTTP_PORT"
echo ""
echo "API Endpoint: /api/v1/music-albums?key=<INT>"
echo "Example: http://music.$CLUSTER_DOMAIN:$HTTP_PORT/api/v1/music-albums?key=100"
echo ""
echo "Redis Password: musicapp123"
