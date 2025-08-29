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

echo -e "${BLUE}Music App GitOps Cleanup Script${NC}"
echo "====================================="
echo ""

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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if ArgoCD is available
check_argocd() {
    if ! command -v argocd &> /dev/null; then
        print_error "ArgoCD CLI is not installed"
        exit 1
    fi
}

# Delete ArgoCD Application
delete_argocd_app() {
    print_step "Deleting ArgoCD Application..."
    
    if argocd app get music-app &> /dev/null; then
        print_status "Deleting music-app ArgoCD Application..."
        argocd app delete music-app --yes
        print_status "ArgoCD Application deleted"
    else
        print_status "ArgoCD Application not found"
    fi
}

# Delete namespace and resources
delete_namespace() {
    print_step "Deleting music-app namespace..."
    
    if kubectl get namespace music-app &> /dev/null; then
        print_status "Deleting music-app namespace and all resources..."
        kubectl delete namespace music-app
        print_status "Namespace deleted"
    else
        print_status "Namespace not found"
    fi
}

# Remove Docker image
remove_docker_image() {
    print_step "Removing Docker image..."
    
    if docker images | grep -q "music-app"; then
        print_status "Removing music-app Docker image..."
        docker rmi music-app:latest
        print_status "Docker image removed"
    else
        print_status "Docker image not found"
    fi
}

# Remove host entry
remove_host_entry() {
    print_step "Removing host entry..."
    
    local host_entry="127.0.0.1 music.$CLUSTER_DOMAIN"
    
    if grep -q "music.$CLUSTER_DOMAIN" /etc/hosts; then
        print_status "Removing host entry: $host_entry"
        sudo sed -i.bak "/music\.$CLUSTER_DOMAIN/d" /etc/hosts
        print_status "Host entry removed"
    else
        print_status "Host entry not found"
    fi
}

# Clean up temporary files
cleanup_temp_files() {
    print_step "Cleaning up temporary files..."
    
    local files_to_remove=(
        "music-app-deployment/k8s/05-redis-data.yaml"
        "music-app-deployment/k8s/04-ingress-updated.yaml"
        "music-app-deployment/argocd/Application-updated.yaml"
        "redis-data-configmap.yaml"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            rm "$file"
            print_status "Removed: $file"
        fi
    done
}

# Show cleanup summary
show_cleanup_summary() {
    print_step "Cleanup completed successfully!"
    echo ""
    echo "The following resources have been removed:"
    echo "  - ArgoCD Application: music-app"
    echo "  - Kubernetes namespace: music-app"
    echo "  - Docker image: music-app:latest"
    echo "  - Host entry: music.$CLUSTER_DOMAIN"
    echo "  - Temporary files"
    echo ""
    echo "The music app deployment has been completely removed."
}

# Main execution
main() {
    check_argocd
    delete_argocd_app
    delete_namespace
    remove_docker_image
    remove_host_entry
    cleanup_temp_files
    show_cleanup_summary
}

# Run main function
main "$@"
