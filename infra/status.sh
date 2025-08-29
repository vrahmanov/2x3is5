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

echo -e "${BLUE}Infrastructure Status Check${NC}"
echo "============================="

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

# Check K3D cluster
echo ""
echo "=== K3D Cluster Status ==="
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    print_status "K3D cluster '$CLUSTER_NAME' found"
    k3d cluster list | grep "$CLUSTER_NAME"
else
    print_error "K3D cluster '$CLUSTER_NAME' not found"
fi

# Check kubectl context
echo ""
echo "=== Kubernetes Context ==="
current_context=$(kubectl config current-context)
print_status "Current context: $current_context"

# Check ArgoCD
echo ""
echo "=== ArgoCD Status ==="
if kubectl get namespace argocd &> /dev/null; then
    print_status "ArgoCD namespace exists"
    echo "ArgoCD pods:"
    kubectl get pods -n argocd
else
    print_error "ArgoCD namespace not found"
fi

# Check Ingress Controller
echo ""
echo "=== Ingress Controller Status ==="
if kubectl get namespace ingress-nginx &> /dev/null; then
    print_status "Nginx Ingress Controller found"
    kubectl get pods -n ingress-nginx
else
    print_warning "Nginx Ingress Controller not found"
fi

# Check Prometheus/Grafana
echo ""
echo "=== Monitoring Stack Status ==="
if kubectl get namespace monitoring &> /dev/null; then
    print_status "Monitoring namespace exists"
    kubectl get pods -n monitoring
else
    print_warning "Monitoring stack not found"
fi

# Check Kubernetes Dashboard
echo ""
echo "=== Kubernetes Dashboard Status ==="
if kubectl get namespace kubernetes-dashboard &> /dev/null; then
    print_status "Kubernetes Dashboard found"
    kubectl get pods -n kubernetes-dashboard
else
    print_warning "Kubernetes Dashboard not found"
fi

# Check host entries
echo ""
echo "=== Host Entries ==="
if grep -q "$CLUSTER_DOMAIN" /etc/hosts; then
    print_status "Host entries found for $CLUSTER_DOMAIN:"
    grep "$CLUSTER_DOMAIN" /etc/hosts
else
    print_warning "No host entries found for $CLUSTER_DOMAIN"
fi

# Check Docker
echo ""
echo "=== Docker Status ==="
if docker info &> /dev/null; then
    print_status "Docker is running"
else
    print_error "Docker is not running"
fi

echo ""
echo "=== Infrastructure Status Complete ==="
