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

echo -e "${BLUE}Overall Project Status${NC}"
echo "======================"

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

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check infrastructure status
echo ""
echo "=== Infrastructure Status ==="
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    print_success "K3D cluster '$CLUSTER_NAME' is running"
    k3d cluster list | grep "$CLUSTER_NAME"
else
    print_error "K3D cluster '$CLUSTER_NAME' is not running"
fi

# Check kubectl context
current_context=$(kubectl config current-context 2>/dev/null || echo "none")
if [ "$current_context" = "k3d-$CLUSTER_NAME" ]; then
    print_success "Using correct kubectl context: $current_context"
else
    print_warning "Using kubectl context: $current_context (expected: k3d-$CLUSTER_NAME)"
fi

# Check ArgoCD
echo ""
echo "=== ArgoCD Status ==="
if kubectl get namespace argocd &> /dev/null; then
    print_success "ArgoCD namespace exists"
    argocd_pods=$(kubectl get pods -n argocd --no-headers | grep -c "Running" 2>/dev/null || echo "0")
    total_argocd_pods=$(kubectl get pods -n argocd --no-headers | wc -l 2>/dev/null || echo "0")
    if [ "$argocd_pods" -gt 0 ]; then
        print_success "ArgoCD pods: $argocd_pods/$total_argocd_pods running"
    else
        print_warning "ArgoCD pods not running"
    fi
else
    print_error "ArgoCD namespace not found"
fi

# Check Ingress Controller
echo ""
echo "=== Ingress Controller Status ==="
if kubectl get namespace ingress-nginx &> /dev/null; then
    print_success "Nginx Ingress Controller found"
    ingress_pods=$(kubectl get pods -n ingress-nginx --no-headers | grep -c "Running" 2>/dev/null || echo "0")
    total_ingress_pods=$(kubectl get pods -n ingress-nginx --no-headers | wc -l 2>/dev/null || echo "0")
    if [ "$ingress_pods" -gt 0 ]; then
        print_success "Ingress pods: $ingress_pods/$total_ingress_pods running"
    else
        print_warning "Ingress pods not running"
    fi
else
    print_warning "Nginx Ingress Controller not found"
fi

# Check Music App
echo ""
echo "=== Music App Status ==="
if kubectl get namespace music-app &> /dev/null; then
    print_success "Music app namespace exists"
    
    # Check music app pods
    music_app_pods=$(kubectl get pods -n music-app -l app=music-app --no-headers | grep -c "Running" 2>/dev/null || echo "0")
    total_music_app_pods=$(kubectl get pods -n music-app -l app=music-app --no-headers | wc -l 2>/dev/null || echo "0")
    if [ "$music_app_pods" -gt 0 ]; then
        print_success "Music app pods: $music_app_pods/$total_music_app_pods running"
    else
        print_warning "Music app pods not running"
    fi
    
    # Check Redis pods
    redis_pods=$(kubectl get pods -n music-app -l app=redis --no-headers | grep -c "Running" 2>/dev/null || echo "0")
    total_redis_pods=$(kubectl get pods -n music-app -l app=redis --no-headers | wc -l 2>/dev/null || echo "0")
    if [ "$redis_pods" -gt 0 ]; then
        print_success "Redis pods: $redis_pods/$total_redis_pods running"
    else
        print_warning "Redis pods not running"
    fi
    
    # Check services
    if kubectl get svc music-app -n music-app &> /dev/null; then
        print_success "Music app service exists"
    else
        print_warning "Music app service not found"
    fi
    
    if kubectl get svc redis -n music-app &> /dev/null; then
        print_success "Redis service exists"
    else
        print_warning "Redis service not found"
    fi
    
    # Check ingress
    if kubectl get ingress -n music-app &> /dev/null; then
        print_success "Music app ingress exists"
    else
        print_warning "Music app ingress not found"
    fi
else
    print_warning "Music app namespace not found"
fi

# Check host entries
echo ""
echo "=== Host Entries ==="
if grep -q "$CLUSTER_DOMAIN" /etc/hosts; then
    print_success "Host entries found for $CLUSTER_DOMAIN:"
    grep "$CLUSTER_DOMAIN" /etc/hosts
else
    print_warning "No host entries found for $CLUSTER_DOMAIN"
fi

# Check Docker
echo ""
echo "=== Docker Status ==="
if docker info &> /dev/null; then
    print_success "Docker is running"
    
    # Check if music-app image exists
    if docker images | grep -q "music-app"; then
        print_success "Music app Docker image exists"
    else
        print_warning "Music app Docker image not found"
    fi
else
    print_error "Docker is not running"
fi

# Test application connectivity
echo ""
echo "=== Application Connectivity ==="
health_response=$(curl -s -o /dev/null -w "%{http_code}" "http://music.$CLUSTER_DOMAIN:$HTTP_PORT/health" 2>/dev/null || echo "000")
if [ "$health_response" = "200" ]; then
    print_success "Health endpoint responding (HTTP 200)"
else
    print_warning "Health endpoint failed (HTTP $health_response)"
fi

api_response=$(curl -s "http://music.$CLUSTER_DOMAIN:$HTTP_PORT/api/v1/music-albums?key=100" 2>/dev/null || echo "ERROR")
if echo "$api_response" | grep -q "Iron Maiden"; then
    print_success "API endpoint working correctly"
else
    print_warning "API endpoint test failed"
fi

# Summary
echo ""
echo "=== Summary ==="
print_status "Overall project status check completed"

echo ""
echo "Access URLs:"
echo "  Music App: http://music.$CLUSTER_DOMAIN:$HTTP_PORT"
echo "  ArgoCD: http://argocd.$CLUSTER_DOMAIN:$HTTP_PORT"
echo "  API: http://music.$CLUSTER_DOMAIN:$HTTP_PORT/api/v1/music-albums?key=100"
echo "  Health: http://music.$CLUSTER_DOMAIN:$HTTP_PORT/health"

echo ""
echo "Management Commands:"
echo "  make infra_status    # Check infrastructure status"
echo "  make app_logs        # Show application logs"
echo "  make app_test        # Test application"
echo "  make clean           # Clean application"
echo "  make clean-all       # Clean everything"
