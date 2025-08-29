#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Dependency Check Script${NC}"
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

# Check required dependencies
echo ""
echo "=== Required Dependencies ==="

missing_deps=()

# Check kubectl
if command -v kubectl &> /dev/null; then
    print_status "kubectl: $(kubectl version --client --short)"
else
    print_error "kubectl: Not installed"
    missing_deps+=("kubectl")
fi

# Check docker
if command -v docker &> /dev/null; then
    print_status "docker: $(docker --version)"
else
    print_error "docker: Not installed"
    missing_deps+=("docker")
fi

# Check k3d
if command -v k3d &> /dev/null; then
    print_status "k3d: $(k3d version)"
else
    print_error "k3d: Not installed"
    missing_deps+=("k3d")
fi

# Check argocd CLI
if command -v argocd &> /dev/null; then
    print_status "argocd: $(argocd version --client --short)"
else
    print_error "argocd: Not installed"
    missing_deps+=("argocd")
fi

# Check optional dependencies
echo ""
echo "=== Optional Dependencies ==="

# Check go
if command -v go &> /dev/null; then
    print_status "go: $(go version)"
else
    print_warning "go: Not installed (required for building the application)"
fi

# Check jq
if command -v jq &> /dev/null; then
    print_status "jq: $(jq --version)"
else
    print_warning "jq: Not installed (useful for JSON parsing)"
fi

# Check curl
if command -v curl &> /dev/null; then
    print_status "curl: $(curl --version | head -1)"
else
    print_warning "curl: Not installed (required for testing)"
fi

# Check make
if command -v make &> /dev/null; then
    print_status "make: $(make --version | head -1)"
else
    print_error "make: Not installed"
    missing_deps+=("make")
fi

# Check Docker daemon
echo ""
echo "=== Docker Daemon Status ==="
if docker info &> /dev/null; then
    print_status "Docker daemon is running"
else
    print_error "Docker daemon is not running"
    echo ""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Please start Docker Desktop on macOS"
    else
        echo "Please start Docker daemon: sudo systemctl start docker"
    fi
fi

# Summary
echo ""
echo "=== Summary ==="
if [ ${#missing_deps[@]} -eq 0 ]; then
    print_status "All required dependencies are installed!"
else
    print_error "Missing required dependencies: ${missing_deps[*]}"
    echo ""
    echo "Installation instructions:"
    echo ""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS (using Homebrew):"
        echo "  brew install kubectl docker k3d argocd go jq curl make"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Ubuntu/Debian:"
        echo "  sudo apt update"
        echo "  sudo apt install -y kubectl docker.io golang-go jq curl make"
        echo ""
        echo "Install k3d:"
        echo "  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
        echo ""
        echo "Install ArgoCD CLI:"
        echo "  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
        echo "  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd"
        echo "  rm argocd-linux-amd64"
    fi
fi
