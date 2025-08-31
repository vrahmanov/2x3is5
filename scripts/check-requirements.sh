#!/bin/bash

# Requirements Check Script for Music App GitOps Deployment
# ========================================================

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check version
check_version() {
    local cmd=$1
    local version_flag=$2
    local min_version=$3
    
    if command_exists "$cmd"; then
        local version=$($cmd $version_flag 2>/dev/null | head -n1)
        print_success "$cmd: $version"
        return 0
    else
        print_error "$cmd: Not installed"
        return 1
    fi
}

# Function to check Docker
check_docker() {
    if command_exists docker; then
        if docker info >/dev/null 2>&1; then
            local version=$(docker --version)
            print_success "Docker: $version (running)"
            return 0
        else
            print_error "Docker: Installed but not running"
            return 1
        fi
    else
        print_error "Docker: Not installed"
        return 1
    fi
}

# Function to check Go
check_go() {
    if command_exists go; then
        local version=$(go version)
        print_success "Go: $version"
        return 0
    else
        print_error "Go: Not installed"
        return 1
    fi
}

# Function to check system
detect_system() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$NAME"
    else
        echo "Unknown"
    fi
}

# Function to provide installation instructions
show_install_instructions() {
    local system=$1
    echo ""
    echo -e "${YELLOW}Installation Instructions for $system:${NC}"
    echo "=============================================="
    
    case $system in
        "macOS")
            echo ""
            echo "Install using Homebrew:"
            echo "  brew install kubectl docker k3d argocd helm go jq curl make"
            echo ""
            echo "Or install individually:"
            echo "  brew install kubectl"
            echo "  brew install docker"
            echo "  brew install k3d"
            echo "  brew install argocd"
            echo "  brew install helm"
            echo "  brew install go"
            echo "  brew install jq"
            echo "  brew install curl"
            echo "  brew install make"
            ;;
        "Ubuntu"|"Debian GNU/Linux")
            echo ""
            echo "Update package list:"
            echo "  sudo apt update"
            echo ""
            echo "Install packages:"
            echo "  sudo apt install -y kubectl docker.io golang-go jq curl make"
            echo ""
            echo "Start and enable Docker:"
            echo "  sudo systemctl enable docker"
            echo "  sudo systemctl start docker"
            echo ""
            echo "Install k3d:"
            echo "  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
            echo ""
            echo "Install Helm:"
            echo "  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
            echo ""
            echo "Install ArgoCD CLI:"
            echo "  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
            echo "  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd"
            echo "  rm argocd-linux-amd64"
            ;;
        *)
            echo ""
            echo "Please install the following tools manually:"
            echo "  - kubectl"
            echo "  - docker"
            echo "  - k3d"
            echo "  - argocd"
            echo "  - helm"
            echo "  - go"
            echo "  - jq"
            echo "  - curl"
            echo "  - make"
            ;;
    esac
}

# Main check function
main() {
    echo -e "${BLUE}Music App GitOps - Requirements Check${NC}"
    echo "=============================================="
    echo ""
    
    local system=$(detect_system)
    print_status "Detected system: $system"
    echo ""
    
    local all_good=true
    local missing_tools=()
    
    # Check kubectl
    print_status "Checking kubectl..."
    if check_version kubectl version --client; then
        # Check if kubectl can connect to a cluster
        if kubectl cluster-info >/dev/null 2>&1; then
            print_success "kubectl: Connected to cluster"
        else
            print_warning "kubectl: No cluster connection (this is OK for initial setup)"
        fi
    else
        missing_tools+=("kubectl")
        all_good=false
    fi
    
    # Check Docker
    print_status "Checking Docker..."
    if ! check_docker; then
        missing_tools+=("docker")
        all_good=false
    fi
    
    # Check k3d
    print_status "Checking k3d..."
    if check_version k3d version; then
        # Check if k3d can list clusters
        if k3d cluster list >/dev/null 2>&1; then
            print_success "k3d: Working correctly"
        else
            print_warning "k3d: Could not list clusters (this is OK)"
        fi
    else
        missing_tools+=("k3d")
        all_good=false
    fi
    
    # Check ArgoCD CLI
    print_status "Checking ArgoCD CLI..."
    if check_version argocd version --client; then
        print_success "ArgoCD CLI: Installed"
    else
        missing_tools+=("argocd")
        all_good=false
    fi
    
    # Check Helm
    print_status "Checking Helm..."
    if check_version helm version; then
        print_success "Helm: Installed"
    else
        missing_tools+=("helm")
        all_good=false
    fi
    
    # Check Go
    print_status "Checking Go..."
    if check_go; then
        # Check Go modules
        if go mod help >/dev/null 2>&1; then
            print_success "Go modules: Available"
        else
            print_warning "Go modules: Not available (this is OK for older Go versions)"
        fi
    else
        missing_tools+=("go")
        all_good=false
    fi
    
    # Check jq
    print_status "Checking jq..."
    if check_version jq --version; then
        print_success "jq: Installed"
    else
        missing_tools+=("jq")
        all_good=false
    fi
    
    # Check curl
    print_status "Checking curl..."
    if check_version curl --version; then
        print_success "curl: Installed"
    else
        missing_tools+=("curl")
        all_good=false
    fi
    
    # Check make
    print_status "Checking make..."
    if check_version make --version; then
        print_success "make: Installed"
    else
        missing_tools+=("make")
        all_good=false
    fi
    
    # Check system-specific requirements
    echo ""
    print_status "Checking system-specific requirements..."
    
    case $system in
        "macOS")
            # Check if Homebrew is available
            if command_exists brew; then
                print_success "Homebrew: Available"
            else
                print_warning "Homebrew: Not installed (recommended for easy package management)"
            fi
            ;;
        "Ubuntu"|"Debian GNU/Linux")
            # Check if user is in docker group
            if groups $USER | grep -q docker; then
                print_success "User in docker group: Yes"
            else
                print_warning "User not in docker group (you may need to run docker with sudo)"
            fi
            ;;
    esac
    
    # Summary
    echo ""
    echo -e "${BLUE}Requirements Check Summary:${NC}"
    echo "================================"
    
    if $all_good; then
        echo -e "${GREEN}✅ All requirements are met!${NC}"
        echo ""
        echo "You can now run:"
        echo "  make all"
        exit 0
    else
        echo -e "${RED}❌ Missing requirements:${NC}"
        printf '  %s\n' "${missing_tools[@]}"
        echo ""
        show_install_instructions "$system"
        exit 1
    fi
}

# Run main function
main "$@"
