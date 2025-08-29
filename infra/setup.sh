#!/bin/bash
source "$(dirname "$0")/hostfilemanager.sh"
# Installation variables
CLUSTER_DOMAIN=local.io
API_PORT=6550
HTTP_PORT=44134
HTTPS_PORT=6600
CLUSTER_NAME=localdev
SERVERS=1
AGENTS=2
REGISTRY_PORT=7979

# Bold text 
bold=$(tput bold)
normal=$(tput sgr0)
yes_no="(${bold}Y${normal}es/${bold}N${normal}o)"

# Function definitions

generateHelmValues() {
    header "Generating Helm Values Files"
    
    # Create helm-values directory if it doesn't exist
    mkdir -p helm-values || { echo "ERROR: Failed to create helm-values directory"; exit 1; }
    
    # Generate kubernetes-dashboard.yaml from template
    if [ -f "helm-values/kubernetes-dashboard.template.yaml" ]; then
        sed "s/{{CLUSTER_DOMAIN}}/${CLUSTER_DOMAIN}/g" helm-values/kubernetes-dashboard.template.yaml > helm-values/kubernetes-dashboard.yaml
        echo "OK - Generated kubernetes-dashboard.yaml"
    else
        echo "WARNING: kubernetes-dashboard.template.yaml not found"
    fi
    
    # Generate prometheus-stack.yaml from template
    if [ -f "helm-values/prometheus-stack.template.yaml" ]; then
        sed "s/{{CLUSTER_DOMAIN}}/${CLUSTER_DOMAIN}/g" helm-values/prometheus-stack.template.yaml > helm-values/prometheus-stack.yaml
        echo "OK - Generated prometheus-stack.yaml"
    else
        echo "WARNING: prometheus-stack.template.yaml not found"
    fi
    
    # Generate argo_insecure.yml from template
    if [ -f "argo_insecure.template.yml" ]; then
        sed "s/{{CLUSTER_DOMAIN}}/${CLUSTER_DOMAIN}/g" argo_insecure.template.yml > argo_insecure.yml
        echo "OK - Generated argo_insecure.yml"
    else
        echo "WARNING: argo_insecure.template.yml not found"
    fi
    
    footer
}

ensureCorrectContext() {
    # Check if we're using the correct kubectl context
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
    EXPECTED_CONTEXT="k3d-${CLUSTER_NAME}"
    
    if [ "$CURRENT_CONTEXT" != "$EXPECTED_CONTEXT" ]; then
        echo "WARNING: Using incorrect kubectl context: $CURRENT_CONTEXT"
        echo "Switching to correct context: $EXPECTED_CONTEXT"
        kubectl config use-context "$EXPECTED_CONTEXT" || { 
            echo "ERROR: Failed to switch to context $EXPECTED_CONTEXT"
            echo "Available contexts:"
            kubectl config get-contexts
            exit 1
        }
        echo "OK - Switched to context: $EXPECTED_CONTEXT"
    else
        echo "OK - Using correct context: $CURRENT_CONTEXT"
    fi
}

read_value() {
    read -p "${1} [${bold}${2}${normal}]: " READ_VALUE
    READ_VALUE=${READ_VALUE:-$2}
}

header() {
    echo -e "\n\n${bold}${1}${normal}\n-------------------------------------"
}

footer() {
    echo "-------------------------------------"
}

isSelected() {
    case "$1" in
        [Yy]*)
            echo 1
            ;;
        *)
            echo 0
            ;;
    esac
}

configValues() {
    header "Cluster Configuration"
    
    read_value "Use default configuration? (Y/n)" "Y"
    if [ "$(isSelected ${READ_VALUE})" = "1" ]; then
        echo "OK - Using default configuration:"
        echo "  • Cluster Name: ${CLUSTER_NAME}"
        echo "  • Cluster Domain: ${CLUSTER_DOMAIN}"
        echo "  • API Port: ${API_PORT}"
        echo "  • Servers: ${SERVERS}"
        echo "  • Agents: ${AGENTS}"
        echo "  • HTTP Port: ${HTTP_PORT}"
        echo "  • HTTPS Port: ${HTTPS_PORT}"
        echo "  • Registry Port: ${REGISTRY_PORT}"
        echo ""
        return
    fi
    
    echo "Customizing configuration..."
    read_value "Cluster Name" "${CLUSTER_NAME}"
    CLUSTER_NAME=${READ_VALUE}
    read_value "Cluster Domain" "${CLUSTER_DOMAIN}"
    CLUSTER_DOMAIN=${READ_VALUE}
    read_value "API Port" "${API_PORT}"
    API_PORT=${READ_VALUE}
    read_value "Servers (Masters)" "${SERVERS}"
    SERVERS=${READ_VALUE}
    read_value "Agents (Workers)" "${AGENTS}"
    AGENTS=${READ_VALUE}
    read_value "LoadBalancer HTTP Port" "${HTTP_PORT}"
    HTTP_PORT=${READ_VALUE}
    read_value "LoadBalancer HTTPS Port" "${HTTPS_PORT}"
    HTTPS_PORT=${READ_VALUE}
    read_value "Registry Port" "${REGISTRY_PORT}"
    REGISTRY_PORT=${READ_VALUE}
    
    echo "OK - Configuration complete"
    footer
}

checkDependencies() {
    local tools="docker k3d kubectl helm"
    for tool in $tools; do
        if ! command -v $tool > /dev/null 2>&1; then
            echo "ERROR: $tool could not be found. Please install it and try again."
            exit 1
        fi
    done

    # Check if Docker daemon is running
    echo "Checking Docker daemon status..."
    if ! docker info > /dev/null 2>&1; then
        echo "ERROR: Docker daemon is not running."
        echo "Please start Docker Desktop or the Docker daemon and try again."
        echo ""
        echo "To start Docker on macOS:"
        echo "  - Open Docker Desktop application"
        echo "  - Or run: open -a Docker"
        echo ""
        echo "To start Docker on Linux:"
        echo "  - Run: sudo systemctl start docker"
        echo "  - Or run: sudo service docker start"
        echo ""
        echo "To start Docker on Windows:"
        echo "  - Open Docker Desktop application"
        echo "  - Or run: start-process 'C:\\Program Files\\Docker\\Docker\\Docker Desktop.exe'"
        exit 1
    fi
    echo "OK - Docker daemon is running"

    # Add default repos
    echo "Adding Helm repositories..."
    helm repo add stable https://charts.helm.sh/stable || echo "WARNING: Failed to add stable repo"
    helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/ || echo "WARNING: Failed to add kubernetes-dashboard repo"
    helm repo add bitnami https://charts.bitnami.com/bitnami || echo "WARNING: Failed to add bitnami repo"
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || echo "WARNING: Failed to add prometheus-community repo"
    helm repo add grafana https://grafana.github.io/helm-charts || echo "WARNING: Failed to add grafana repo"
    helm repo add argo https://argoproj.github.io/argo-helm || echo "WARNING: Failed to add argo repo"
    helm repo update || echo "WARNING: Failed to update helm repos"
}


installCluster() {
    header "Creating PV local folder K3d"    
    mkdir -p k3dvol || { echo "ERROR: Failed to create k3dvol directory"; exit 1; }
    
    header "Creating K3D registry"
    k3d registry delete registry.${CLUSTER_DOMAIN} 2>/dev/null || true
    k3d registry create registry.${CLUSTER_DOMAIN} --port ${REGISTRY_PORT} || { echo "ERROR: Failed to create registry"; exit 1; }
    
    header "Creating K3D cluster"
    k3d cluster delete ${CLUSTER_NAME} 2>/dev/null || true
    k3d cluster create ${CLUSTER_NAME} \
        --servers ${SERVERS} \
        --agents ${AGENTS} \
        --api-port ${API_PORT} \
        --port "${HTTP_PORT}:80@loadbalancer" \
        --port "${HTTPS_PORT}:443@loadbalancer" \
        --k3s-arg "--disable=traefik@server:*" \
        --k3s-arg "--tls-san=127.0.0.1@server:0" \
        --registry-use registry.${CLUSTER_DOMAIN}:${REGISTRY_PORT} \
        --volume "$(pwd)/k3dvol:/k3dvol@all" \
        --wait || { echo "ERROR: Failed to create cluster"; exit 1; }

    # Set and verify kubectl context
    header "Setting kubectl context"
    kubectl config use-context k3d-${CLUSTER_NAME} || { echo "ERROR: Failed to set kubectl context"; exit 1; }
    
    # Verify context is set correctly
    CURRENT_CONTEXT=$(kubectl config current-context)
    if [ "$CURRENT_CONTEXT" != "k3d-${CLUSTER_NAME}" ]; then
        echo "ERROR: Context verification failed. Expected: k3d-${CLUSTER_NAME}, Got: $CURRENT_CONTEXT"
        exit 1
    fi
    echo "OK - Using kubectl context: $CURRENT_CONTEXT"
    
    # Verify cluster connectivity
    kubectl cluster-info || { echo "ERROR: Failed to get cluster info"; exit 1; }
    echo "OK - Cluster connectivity verified"
    header "Creating PersistentVolume"
    cat <<EOF | kubectl apply -f - || { echo "ERROR: Failed to create PersistentVolume"; exit 1; }
apiVersion: v1
kind: PersistentVolume
metadata:
  name: k3d-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/k3dvol"  
EOF

    kubectl get pv || { echo "ERROR: Failed to get PersistentVolumes"; exit 1; }
    footer
}

installIngress() {
    header "Installing Ingress"
    
    ensureCorrectContext
    
    helm upgrade --install ingress-nginx bitnami/nginx-ingress-controller \
        --namespace ingress-nginx --create-namespace \
        --values helm-values/ingress-nginx.yaml || { echo "ERROR: Failed to install Ingress"; exit 1; }
        
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s || { echo "ERROR: Ingress controller not ready"; exit 1; }
    footer
}

installDashboard() {
    header "Installing Dashboard"
    
    ensureCorrectContext
    
    helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
        --namespace kubernetes-dashboard --create-namespace \
        --values helm-values/kubernetes-dashboard.yaml || { echo "ERROR: Failed to install Dashboard"; exit 1; }
    
    # Create admin service account
    kubectl create serviceaccount dashboard-admin-sa --namespace kubernetes-dashboard 2>/dev/null || true
    kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin-sa 2>/dev/null || true
    
    header "Dashboard Access Token:"
    kubectl -n kubernetes-dashboard create token dashboard-admin-sa
    echo "Dashboard URL: http://dashboard.${CLUSTER_DOMAIN}:${HTTP_PORT}"
    footer
}

installArgoCD() {
    header "Installing ArgoCD"
    
    ensureCorrectContext
    
    # Check if argo_insecure.yml exists
    if [ ! -f "./argo_insecure.yml" ]; then
        echo "ERROR: argo_insecure.yml file not found. Please create it first."
        exit 1; 
    fi
    
    echo "Installing ArgoCD with insecure configuration..."
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd --create-namespace \
        --values argo_insecure.yml \
        --timeout 10m || { echo "ERROR: Failed to install ArgoCD"; exit 1; }
    
    # Wait for ArgoCD server to be ready
    echo "Waiting for ArgoCD server to be ready..."
    kubectl -n argocd wait --for=condition=available deployment -l app.kubernetes.io/name=argocd-server --timeout=300s || { echo "ERROR: ArgoCD server not ready"; exit 1; }
    
    # Wait for ingress to be ready
    echo "Waiting for ArgoCD ingress to be ready..."
    kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=120s || echo "WARNING: ArgoCD pods not ready within timeout"
    
    # Verify ingress is created and show details
    echo "Verifying ArgoCD ingress..."
    kubectl get ingress -n argocd || echo "WARNING: ArgoCD ingress not found"
    
    # Show ingress details for debugging
    echo "ArgoCD ingress details:"
    kubectl describe ingress -n argocd 2>/dev/null | head -20 || echo "No ingress details available"
    
    # Fix ArgoCD service to use HTTP port
    echo "Fixing ArgoCD service configuration..."
    kubectl patch service argocd-server -n argocd -p '{"spec":{"ports":[{"name":"http","port":80,"targetPort":8080},{"name":"https","port":443,"targetPort":8080}]}}' 2>/dev/null || echo "WARNING: Could not patch ArgoCD service"
    
    # Verify service configuration
    echo "ArgoCD service configuration:"
    kubectl get service argocd-server -n argocd -o yaml | grep -A 5 "ports:" || echo "Service configuration not available"
    
    # Get ArgoCD password
    echo "ArgoCD Initial Password:"
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Password not available yet"
    echo
    
    echo "OK - ArgoCD installed successfully"
    echo "OK - Access ArgoCD at: http://argocd.${CLUSTER_DOMAIN}:${HTTP_PORT}"
    echo "OK - Username: admin"
    footer
}
installPrometheus() {
    header "Installing Prometheus & Grafana"
    
    ensureCorrectContext
    
    # Install Prometheus stack with better error handling
    echo "Installing Prometheus stack..."
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring --create-namespace \
        --values helm-values/prometheus-stack.yaml \
        --timeout 10m || { 
            echo "ERROR: Failed to install Prometheus Stack"
            echo "Checking for any partial installations..."
            kubectl get pods -n monitoring 2>/dev/null || echo "No monitoring namespace found"
            exit 1
        }
    
    # Wait for pods to be ready
    echo "Waiting for Prometheus stack pods to be ready..."
    kubectl wait --namespace monitoring \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=grafana \
        --timeout=300s || echo "WARNING: Grafana pod not ready within timeout"
    
    kubectl wait --namespace monitoring \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=prometheus \
        --timeout=300s || echo "WARNING: Prometheus pod not ready within timeout"
    
    echo "Grafana URL: http://grafana.${CLUSTER_DOMAIN}:${HTTP_PORT}"
    echo "Grafana admin password:"
    kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode 2>/dev/null || echo "Password not available yet"
    echo
    footer
}

installAddons() {
    header "Installing All Components"
    
    echo "Installing Ingress Controller..."
    installIngress
    
    echo "Installing Kubernetes Dashboard..."
    addhost dashboard.${CLUSTER_DOMAIN}
    installDashboard
    
    echo "Installing ArgoCD..."
    addhost argocd.${CLUSTER_DOMAIN}
    installArgoCD
    
    echo "Installing Prometheus & Grafana..."
    addhost prometheus.${CLUSTER_DOMAIN}
    addhost grafana.${CLUSTER_DOMAIN}
    addhost alertmanager.${CLUSTER_DOMAIN}
    installPrometheus
    
    echo "OK - All components installed successfully"
    footer
}

verifyHostsFile() {
    header "Verifying Hosts File Entries"
    
    local hosts_to_check=("dashboard.${CLUSTER_DOMAIN}" "argocd.${CLUSTER_DOMAIN}" "grafana.${CLUSTER_DOMAIN}")
    local missing_hosts=()
    
    for host in "${hosts_to_check[@]}"; do
        if ! grep -q "$host" /etc/hosts 2>/dev/null; then
            missing_hosts+=("$host")
        else
            echo "OK - $host found in /etc/hosts"
        fi
    done
    
    if [ ${#missing_hosts[@]} -gt 0 ]; then
        echo "WARNING: The following hosts are missing from /etc/hosts:"
        for host in "${missing_hosts[@]}"; do
            echo "  - $host"
        done
        echo ""
        echo "Please add them manually or run the script again."
    else
        echo "OK - All required hosts are present in /etc/hosts"
    fi
    
    footer
}

verifyArgoCDAccess() {
    header "Verifying ArgoCD Access"
    
    echo "Checking ArgoCD service status..."
    kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server || echo "WARNING: ArgoCD server pods not found"
    
    echo "Checking ArgoCD service ports..."
    kubectl get service argocd-server -n argocd || echo "WARNING: ArgoCD service not found"
    
    echo "Checking ArgoCD ingress..."
    kubectl get ingress -n argocd || echo "WARNING: ArgoCD ingress not found"
    
    echo "Testing ArgoCD connectivity..."
    if curl -s -o /dev/null -w "%{http_code}" "http://argocd.${CLUSTER_DOMAIN}:${HTTP_PORT}" | grep -q "200\|302"; then
        echo "OK - ArgoCD is accessible via HTTP"
    else
        echo "WARNING: ArgoCD not accessible via HTTP"
        echo "Troubleshooting steps:"
        echo "1. Check if ArgoCD pods are running: kubectl get pods -n argocd"
        echo "2. Check ArgoCD service: kubectl get service argocd-server -n argocd"
        echo "3. Check ArgoCD ingress: kubectl describe ingress -n argocd"
        echo "4. Try port-forward: kubectl port-forward service/argocd-server -n argocd 8080:80"
    fi
    
    footer
}

showUrls() {
    header "Local K3d cluster endpoints:"
    echo "Kubernetes Dashboard: http://dashboard.${CLUSTER_DOMAIN}:${HTTP_PORT}"
    echo "ArgoCD: http://argocd.${CLUSTER_DOMAIN}:${HTTP_PORT}"
    echo "Grafana: http://grafana.${CLUSTER_DOMAIN}:${HTTP_PORT}"
    echo "Note: Prometheus and Alertmanager are accessible via Grafana UI"
    footer
}

showComprehensiveSummary() {
    header "COMPREHENSIVE SETUP SUMMARY"
    
    echo "${bold}Cluster Information:${normal}"
    echo "  • Cluster Name: ${CLUSTER_NAME}"
    echo "  • Domain: ${CLUSTER_DOMAIN}"
    echo "  • API Port: ${API_PORT}"
    echo "  • HTTP Port: ${HTTP_PORT}"
    echo "  • HTTPS Port: ${HTTPS_PORT}"
    echo "  • Registry Port: ${REGISTRY_PORT}"
    echo ""
    
    echo "${bold}Access URLs:${normal}"
    echo "  • Kubernetes Dashboard: http://dashboard.${CLUSTER_DOMAIN}:${HTTP_PORT}"
    echo "  • ArgoCD: http://argocd.${CLUSTER_DOMAIN}:${HTTP_PORT}"
    echo "  • Grafana: http://grafana.${CLUSTER_DOMAIN}:${HTTP_PORT}"
    echo "  • Registry: registry.${CLUSTER_DOMAIN}:${REGISTRY_PORT}"
    echo ""
    
    echo "${bold}Credentials:${normal}"
    
    # Kubernetes Dashboard credentials
    echo "  • Kubernetes Dashboard:"
    echo "    - Username: (Token-based access)"
    echo "    - Password: Use the token shown above"
    echo "    - Or run: kubectl -n kubernetes-dashboard create token dashboard-admin-sa"
    echo ""
    
    # ArgoCD credentials
    echo "  • ArgoCD:"
    echo "    - Username: admin"
    echo "    - Password: "
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null)
    if [ -n "$ARGOCD_PASSWORD" ]; then
        echo "      $ARGOCD_PASSWORD"
    else
        echo "      (Run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
    fi
    echo ""
    
    # Grafana credentials
    echo "  • Grafana:"
    echo "    - Username: admin"
    echo "    - Password: "
    GRAFANA_PASSWORD=$(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode 2>/dev/null)
    if [ -n "$GRAFANA_PASSWORD" ]; then
        echo "      $GRAFANA_PASSWORD"
    else
        echo "      (Run: kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 --decode)"
    fi
    echo ""
    
    echo "${bold}Kubectl Context:${normal}"
    echo "  • Current Context: $(kubectl config current-context)"
    echo "  • Cluster Info: kubectl cluster-info"
    echo ""
    
    echo "${bold}Useful Commands:${normal}"
    echo "  • Switch context: kubectl config use-context k3d-${CLUSTER_NAME}"
    echo "  • View pods: kubectl get pods --all-namespaces"
    echo "  • View services: kubectl get svc --all-namespaces"
    echo "  • View ingress: kubectl get ingress --all-namespaces"
    echo "  • Delete cluster: k3d cluster delete ${CLUSTER_NAME}"
    echo ""
    
    echo "${bold}Hosts File Entries:${normal}"
    echo "  The following entries should be in your /etc/hosts file:"
    echo "  127.0.0.1  dashboard.${CLUSTER_DOMAIN}"
    echo "  127.0.0.1  argocd.${CLUSTER_DOMAIN}"
    echo "  127.0.0.1  grafana.${CLUSTER_DOMAIN}"
    echo ""
    
    echo "${bold}Registry Usage:${normal}"
    echo "  • Push image: docker tag myimage:latest registry.${CLUSTER_DOMAIN}:${REGISTRY_PORT}/myimage:latest"
    echo "  • Pull image: docker pull registry.${CLUSTER_DOMAIN}:${REGISTRY_PORT}/myimage:latest"
    echo ""
    
    footer
}

# Main execution
checkDependencies

# Quick mode option
read_value "Quick setup (use all defaults, install all components)? (Y/n)" "Y"
QUICK_MODE=$([ "$(isSelected ${READ_VALUE})" = "1" ] && echo "true" || echo "false")

if [ "$QUICK_MODE" = "true" ]; then
    echo "Quick setup mode enabled - using all defaults and installing all components"
    echo ""
    echo "Default Configuration:"
    echo "  • Cluster Name: ${CLUSTER_NAME}"
    echo "  • Cluster Domain: ${CLUSTER_DOMAIN}"
    echo "  • API Port: ${API_PORT}"
    echo "  • Servers (Masters): ${SERVERS}"
    echo "  • Agents (Workers): ${AGENTS}"
    echo "  • LoadBalancer HTTP Port: ${HTTP_PORT}"
    echo "  • LoadBalancer HTTPS Port: ${HTTPS_PORT}"
    echo "  • Registry Port: ${REGISTRY_PORT}"
    echo ""
    echo "Components to be installed:"
    echo "  • Nginx Ingress Controller"
    echo "  • Kubernetes Dashboard"
    echo "  • ArgoCD"
    echo "  • Prometheus & Grafana Stack"
    echo ""
else
    configValues
fi

generateHelmValues
installCluster
installAddons

# Final context verification
header "Final Verification"
ensureCorrectContext
echo "OK - All components installed successfully"
echo "OK - Using correct kubectl context: $(kubectl config current-context)"
echo "OK - Cluster is ready for use"

# Verify hosts file entries
verifyHostsFile

# Verify ArgoCD access
verifyArgoCDAccess

# Show comprehensive summary
showComprehensiveSummary

echo "Setup complete!"      