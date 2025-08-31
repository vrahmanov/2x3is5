#!/bin/bash

# Troubleshooting Script for Music App Deployment
# ===============================================

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

print_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
    echo ""
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main troubleshooting function
main() {
    echo -e "${BLUE}Music App Deployment Troubleshooting${NC}"
    echo "============================================="
    echo ""
    
    print_section "1. Checking K3D Cluster Status"
    
    if ! command_exists k3d; then
        print_error "k3d is not installed"
        echo "Install with: curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
        exit 1
    fi
    
    local cluster_name="localdev"
    if k3d cluster list | grep -q "$cluster_name"; then
        print_success "K3D cluster '$cluster_name' exists"
        
        # Check cluster status
        if k3d cluster list | grep "$cluster_name" | grep -q "running"; then
            print_success "Cluster is running"
        else
            print_error "Cluster is not running"
            echo "Start with: k3d cluster start $cluster_name"
            exit 1
        fi
    else
        print_error "K3D cluster '$cluster_name' does not exist"
        echo "Create with: make infra_setup"
        exit 1
    fi
    
    print_section "2. Checking Docker Image"
    
    if ! command_exists docker; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if docker images | grep -q "music-app.*latest"; then
        print_success "Docker image 'music-app:latest' exists locally"
    else
        print_warning "Docker image 'music-app:latest' not found locally"
        echo "Build with: make app_build"
    fi
    
    print_section "3. Checking Kubernetes Context"
    
    if kubectl config current-context | grep -q "k3d-$cluster_name"; then
        print_success "Kubernetes context is set to K3D cluster"
    else
        print_warning "Kubernetes context may not be set correctly"
        echo "Current context: $(kubectl config current-context)"
        echo "Expected: k3d-$cluster_name"
    fi
    
    print_section "4. Checking Namespace and Resources"
    
    if kubectl get namespace music-app >/dev/null 2>&1; then
        print_success "Namespace 'music-app' exists"
        
        # Check pods
        echo ""
        print_status "Pod Status:"
        kubectl get pods -n music-app
        
        # Check services
        echo ""
        print_status "Service Status:"
        kubectl get svc -n music-app
        
        # Check ingress
        echo ""
        print_status "Ingress Status:"
        kubectl get ingress -n music-app
        
    else
        print_warning "Namespace 'music-app' does not exist"
        echo "Deploy with: make app_deploy"
    fi
    
    print_section "5. Checking Pod Details (if any exist)"
    
    local music_pods=$(kubectl get pods -n music-app -l app=music-app --no-headers 2>/dev/null | wc -l)
    if [ "$music_pods" -gt 0 ]; then
        echo ""
        print_status "Music App Pod Details:"
        kubectl describe pods -n music-app -l app=music-app
        
        echo ""
        print_status "Music App Pod Logs:"
        kubectl logs -n music-app -l app=music-app --tail=20
    else
        print_warning "No music app pods found"
    fi
    
    print_section "6. Common Solutions"
    
    echo "If you're experiencing issues, try these solutions in order:"
    echo ""
    echo "1. Build the application first:"
    echo "   make app_build"
    echo ""
    echo "2. Then deploy:"
    echo "   make app_deploy"
    echo ""
    echo "3. Or run the complete workflow:"
    echo "   make all"
    echo ""
    echo "4. If pods are stuck, check events:"
    echo "   kubectl get events -n music-app --sort-by='.lastTimestamp'"
    echo ""
    echo "5. If image pull issues, rebuild and reload:"
    echo "   make app_build"
    echo "   k3d image import music-app:latest -c localdev"
    echo ""
    echo "6. Clean up and start fresh:"
    echo "   make clean-all"
    echo "   make all"
    
    print_section "7. Quick Fix Commands"
    
    echo "Run these commands to fix common issues:"
    echo ""
    echo "# If cluster doesn't exist:"
    echo "make infra_setup"
    echo ""
    echo "# If image is missing:"
    echo "make app_build"
    echo ""
    echo "# If deployment failed:"
    echo "kubectl delete namespace music-app --force --grace-period=0"
    echo "make app_deploy"
    echo ""
    echo "# Complete reset:"
    echo "make clean-all && make all"
}

# Run main function
main "$@"
