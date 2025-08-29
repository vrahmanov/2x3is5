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
GIT_REPO_URL=${GIT_REPO_URL:-"https://github.com/your-username/your-repo.git"}

echo -e "${BLUE}Music App GitOps Deployment Script${NC}"
echo "=========================================="
echo "This script will deploy the music app using ArgoCD GitOps"
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

# Check dependencies
check_dependencies() {
    print_step "Checking dependencies..."
    
    local missing_deps=()
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_deps+=("kubectl")
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    # Check k3d
    if ! command -v k3d &> /dev/null; then
        missing_deps+=("k3d")
    fi
    
    # Check argocd CLI
    if ! command -v argocd &> /dev/null; then
        missing_deps+=("argocd")
    fi
    
    # Check go (for building the application)
    if ! command -v go &> /dev/null; then
        print_warning "Go is not installed. Will use existing server binary if available."
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install the missing dependencies:"
        echo ""
        
        # Detect OS and provide installation instructions
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "macOS detected. Install using Homebrew:"
            echo "brew install kubectl docker k3d argocd"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "Linux detected. Install using package manager:"
            echo ""
            echo "For Ubuntu/Debian:"
            echo "sudo apt update"
            echo "sudo apt install -y kubectl docker.io"
            echo ""
            echo "Install k3d:"
            echo "curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
            echo ""
            echo "Install ArgoCD CLI:"
            echo "curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
            echo "sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd"
            echo "rm argocd-linux-amd64"
        fi
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        echo ""
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Please start Docker Desktop on macOS"
        else
            echo "Please start Docker daemon: sudo systemctl start docker"
        fi
        exit 1
    fi
    
    print_status "All dependencies are available"
}

# Check K3D cluster
check_k3d_cluster() {
    print_step "Checking K3D cluster..."
    
    if ! k3d cluster list | grep -q "localdev"; then
        print_error "K3D cluster 'localdev' not found"
        echo ""
        echo "Please run the infrastructure setup first:"
        echo "./infra_gen.sh"
        exit 1
    fi
    
    # Check if cluster is running (simplified check)
    if ! k3d cluster list | grep "localdev" | grep -q "true"; then
        print_error "K3D cluster 'localdev' is not running properly"
        echo ""
        echo "Please start the cluster:"
        echo "k3d cluster start localdev"
        exit 1
    fi
    
    print_status "K3D cluster is running"
}

# Check kubectl context
check_kubectl_context() {
    print_step "Checking kubectl context..."
    
    local current_context=$(kubectl config current-context)
    if [[ "$current_context" != "k3d-localdev" ]]; then
        print_warning "Current kubectl context is '$current_context', switching to 'k3d-localdev'"
        kubectl config use-context k3d-localdev
    fi
    
    print_status "Using kubectl context: $(kubectl config current-context)"
}

# Check ArgoCD
check_argocd() {
    print_step "Checking ArgoCD..."
    
    if ! kubectl get namespace argocd &> /dev/null; then
        print_error "ArgoCD namespace not found"
        echo ""
        echo "Please run the infrastructure setup first:"
        echo "./infra_gen.sh"
        exit 1
    fi
    
    # Wait for ArgoCD to be ready
    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    
    # Login to ArgoCD using port-forward
    print_status "Logging into ArgoCD..."
    local argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    # Start port-forward in background
    kubectl port-forward svc/argocd-server 8080:80 -n argocd &
    local port_forward_pid=$!
    
    # Wait for port-forward to be ready
    sleep 3
    
    # Login to ArgoCD
    argocd login localhost:8080 --username admin --password "$argocd_password" --insecure
    
    # Store PID for cleanup
    echo $port_forward_pid > /tmp/argocd_port_forward.pid
    
    print_status "ArgoCD is ready and authenticated"
}

# Build and prepare the application
build_application() {
    print_step "Building the music application..."
    
    # Check if server binary exists, build if not
    if [ ! -f "music_app/server" ]; then
        if command -v go &> /dev/null; then
            print_status "Server binary not found, building Go application..."
            cd music_app
            GOOS=linux GOARCH=amd64 go build -o server main.go
            cd ..
        else
            print_error "Server binary not found and Go is not installed. Please build the server manually or install Go."
            exit 1
        fi
    fi
    
    # Build Docker image
    print_status "Building Docker image..."
    cd music-app-deployment/docker
    cp ../../music_app/server .
    docker build -t music-app:latest .
    rm server
    cd ../..
    
    # Load image into K3D
    print_status "Loading Docker image into K3D cluster..."
    k3d image import music-app:latest -c localdev
    
    print_status "Application built and loaded successfully"
}

# Prepare manifests for GitOps
prepare_manifests() {
    print_step "Preparing manifests for GitOps..."
    
    # Create Redis data ConfigMap
    print_status "Creating Redis data ConfigMap..."
    kubectl create configmap redis-data --from-file=dump.rdb=data.rdb -n music-app --dry-run=client -o yaml > music-app-deployment/k8s/05-redis-data.yaml
    
    # Update ingress with correct domain
    print_status "Updating ingress with cluster domain: $CLUSTER_DOMAIN"
    sed "s/{{CLUSTER_DOMAIN}}/$CLUSTER_DOMAIN/g" music-app-deployment/k8s/04-ingress.yaml > music-app-deployment/k8s/04-ingress-updated.yaml
    
    print_status "Manifests prepared successfully"
}

# Deploy using ArgoCD
deploy_with_argocd() {
    print_step "Deploying with ArgoCD..."
    
    # Update the ArgoCD Application with correct repo URL
    sed "s|https://github.com/your-username/your-repo.git|$GIT_REPO_URL|g" music-app-deployment/argocd/Application.yaml > music-app-deployment/argocd/Application-updated.yaml
    
    # Apply the ArgoCD Application
    print_status "Creating ArgoCD Application..."
    kubectl apply -f music-app-deployment/argocd/Application-updated.yaml
    
    # Wait for ArgoCD to sync
    print_status "Waiting for ArgoCD to sync the application..."
    sleep 10
    
    # Check sync status
    local sync_status=""
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        sync_status=$(argocd app get music-app --output json | jq -r '.status.sync.status' 2>/dev/null || echo "Unknown")
        
        if [ "$sync_status" = "Synced" ]; then
            print_status "ArgoCD sync completed successfully"
            break
        elif [ "$sync_status" = "OutOfSync" ]; then
            print_status "Application is out of sync, triggering sync..."
            argocd app sync music-app
            sleep 5
        elif [ "$sync_status" = "Unknown" ]; then
            print_warning "Waiting for ArgoCD to recognize the application..."
            sleep 5
        else
            print_status "Sync status: $sync_status, waiting..."
            sleep 5
        fi
        
        attempts=$((attempts + 1))
    done
    
    if [ $attempts -eq $max_attempts ]; then
        print_warning "ArgoCD sync timeout, checking application status..."
    fi
}

# Wait for application to be ready
wait_for_application() {
    print_step "Waiting for application to be ready..."
    
    # Wait for namespace to be created
    kubectl wait --for=condition=active namespace music-app --timeout=60s
    
    # Wait for Redis to be ready
    print_status "Waiting for Redis to be ready..."
    kubectl wait --for=condition=ready pod -l app=redis -n music-app --timeout=300s
    
    # Wait for music app to be ready
    print_status "Waiting for music app to be ready..."
    kubectl wait --for=condition=ready pod -l app=music-app -n music-app --timeout=300s
    
    print_status "Application is ready"
}

# Setup host entry
setup_host_entry() {
    print_step "Setting up host entry..."
    
    local host_entry="127.0.0.1 music.$CLUSTER_DOMAIN"
    
    if ! grep -q "music.$CLUSTER_DOMAIN" /etc/hosts; then
        echo "$host_entry" | sudo tee -a /etc/hosts
        print_status "Host entry added: $host_entry"
    else
        print_status "Host entry already exists"
    fi
}

# Cleanup function
cleanup() {
    # Stop port-forward if running
    if [ -f /tmp/argocd_port_forward.pid ]; then
        local pid=$(cat /tmp/argocd_port_forward.pid)
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            print_status "Stopped ArgoCD port-forward"
        fi
        rm -f /tmp/argocd_port_forward.pid
    fi
}

# Show final status
show_final_status() {
    print_step "Deployment completed successfully!"
    echo ""
    echo "Music App GitOps Deployment Summary"
    echo "==================================="
    echo ""
    echo "Application Access:"
    echo "  HTTPS URL: https://music.$CLUSTER_DOMAIN:$HTTPS_PORT"
    echo "  HTTP URL: http://music.$CLUSTER_DOMAIN:$HTTP_PORT"
    echo ""
    echo "API Endpoint:"
    echo "  /api/v1/music-albums?key=<INT>"
    echo "  Example: https://music.$CLUSTER_DOMAIN:$HTTPS_PORT/api/v1/music-albums?key=100"
    echo ""
    echo "ArgoCD Access:"
    echo "  URL: http://argocd.$CLUSTER_DOMAIN:$HTTP_PORT"
    echo "  Username: admin"
    echo "  Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
    echo ""
    echo "Redis Password: musicapp123"
    echo ""
    echo "Management Commands:"
    echo "  Check ArgoCD status: argocd app get music-app"
    echo "  Sync application: argocd app sync music-app"
    echo "  View logs: kubectl logs -f deployment/music-app -n music-app"
    echo "  Check pods: kubectl get pods -n music-app"
    echo ""
    echo "GitOps Workflow:"
    echo "  1. Update manifests in Git repository"
    echo "  2. ArgoCD automatically detects changes"
    echo "  3. ArgoCD applies changes to cluster"
    echo "  4. No manual kubectl apply needed!"
}

# Main execution
main() {
    check_dependencies
    check_k3d_cluster
    check_kubectl_context
    check_argocd
    build_application
    prepare_manifests
    deploy_with_argocd
    wait_for_application
    setup_host_entry
    show_final_status
}

# Set up trap to cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
