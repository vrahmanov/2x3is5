# 🚀 Music App GitOps Deployment

A complete **GitOps-based deployment solution** for a Music App using Kubernetes, ArgoCD, and modern DevOps practices. This project provides a production-ready deployment that works seamlessly on both **Ubuntu** and **macOS**.

> **⚠️ Important Note**: The GitOps flow is **not currently active** in this demo setup to avoid irrelevant complications. This is a simplified demonstration environment. For production deployments, the entire flow needs to be properly split into separate repositories and processes as outlined in the Production Flow section below.

## 🎯 **What This Project Provides**

- **Complete GitOps workflow** with ArgoCD as the deployment orchestrator
- **Cross-platform compatibility** (Ubuntu and macOS)
- **Production-ready features** (TLS, health checks, resource limits, high availability)
- **Simple Makefile-based workflow** for easy deployment and management
- **Comprehensive testing and monitoring** capabilities

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    GitOps Workflow                          │
├─────────────────────────────────────────────────────────────┤
│  Git Repository (Manifests) ◄──► ArgoCD ◄──► K3D Cluster   │
│           ↓                        ↓              ↓         │
│    Source of Truth         Deployment Controller   Target   │
└─────────────────────────────────────────────────────────────┘
```

## 📁 **Project Structure**

```
2x3is5/
├── Makefile                    # Main Makefile with all targets
├── README.md                   # This file
├── infra/                      # Infrastructure components
│   ├── setup.sh               # K3D cluster + ArgoCD setup
│   ├── status.sh              # Infrastructure status check
│   ├── cleanup.sh             # Infrastructure cleanup
│   ├── hostfilemanager.sh     # Host file management
│   ├── helm-values/           # Helm values templates
│   ├── argo_insecure.yml      # ArgoCD configuration
│   └── argo_insecure.template.yml
├── apps/                       # Application components
│   └── music-app/             # Music application
│       ├── src/               # Go source code
│       ├── k8s/               # Kubernetes manifests
│       ├── build.sh           # Application build script
│       ├── deploy.sh          # Manual deployment script
│       ├── deploy-gitops.sh   # GitOps deployment script
│       ├── test.sh            # Application testing script
│       └── cleanup.sh         # Application cleanup script
├── configs/                    # Configuration files
│   ├── data.rdb               # Redis data file
│   └── redis-data-configmap.yaml
└── scripts/                    # Utility scripts
    └── check-deps.sh          # Dependency checker
```

## 🚀 **Quick Start**

### **Prerequisites**

Install the required dependencies:

#### **macOS**
```bash
brew install kubectl docker k3d argocd go jq curl make
```

#### **Ubuntu/Debian**
```bash
sudo apt update
sudo apt install -y kubectl docker.io golang-go jq curl make
sudo systemctl enable docker
sudo systemctl start docker

# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### **Complete Deployment**

Run the entire workflow with a single command:

```bash
make all
```

This will:
1. **Setup infrastructure** (K3D cluster + ArgoCD)
2. **Build the application** (Go app + Docker image)
3. **Deploy using GitOps** (ArgoCD manages deployment)
4. **Test the deployment** (Comprehensive testing)

### **Demo Video**

Watch the complete deployment process in action:

![Demo Video](demo-lfs-git-ignore.mp4)

*Note: The video demonstrates the entire workflow from setup to testing, showing how easy it is to deploy the music app using GitOps principles.*

### **Individual Steps**

You can also run individual steps:

```bash
# Setup infrastructure only
make infra_setup

# Build application only
make app_build

# Deploy application only
make app_deploy

# Test application only
make app_test
```

## 🛠️ **Available Make Targets**

### **Main Workflow**
- `make all` - Complete deployment workflow
- `make infra_setup` - Setup K3D cluster with ArgoCD
- `make app_build` - Build the music application
- `make app_deploy` - Deploy using GitOps
- `make app_test` - Test the deployment

### **Management**
- `make infra_status` - Check infrastructure status
- `make infra_cleanup` - Cleanup infrastructure
- `make app_cleanup` - Cleanup application
- `make app_logs` - Show application logs
- `make app_scale` - Scale application replicas

### **Development**
- `make dev_setup` - Setup development environment
- `make dev_test` - Run development tests
- `make check-deps` - Check if all dependencies are installed

### **Quick Operations**
- `make quick-deploy` - Quick deploy (skip infra setup)
- `make quick-test` - Quick test only
- `make restart` - Restart application

### **Environment-Specific**
- `make dev` - Deploy to development environment
- `make staging` - Deploy to staging environment
- `make prod` - Deploy to production environment

### **Utility**
- `make help` - Show this help message
- `make status` - Show overall status
- `make clean` - Clean application only
- `make clean-all` - Clean everything

## 🔧 **Configuration**

### **Environment Variables**

You can customize the deployment by setting these environment variables:

```bash
export CLUSTER_NAME="localdev"
export CLUSTER_DOMAIN="local.io"
export HTTP_PORT="44134"
export HTTPS_PORT="6600"
export GIT_REPO_URL="https://github.com/your-username/your-repo.git"
```

### **Configuration Files**

- **Infrastructure**: `infra/` directory contains all infrastructure configurations
- **Application**: `apps/music-app/` directory contains application-specific files
- **Configs**: `configs/` directory contains shared configuration files

## 🌐 **Access Information**

After successful deployment, you can access:

- **Music App**: http://music.local.io:44134
- **ArgoCD UI**: http://argocd.local.io:44134
- **API Endpoint**: `/api/v1/music-albums?key=<INT>`
- **Health Check**: `/health`

### **Credentials**
- **ArgoCD**: Username `admin`, password from `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
- **Redis**: Password `musicapp123`

## 🔄 **GitOps Workflow (Demo Setup)**

> **Note**: This is a simplified demo setup. In production, follow the proper repository structure outlined in the Production Flow section.

### **Initial Deployment**
1. `make infra_setup` - Creates K3D cluster with ArgoCD
2. `make app_build` - Builds Go app and Docker image
3. `make app_deploy` - Creates ArgoCD Application
4. ArgoCD automatically deploys everything

### **Making Changes (Demo)**
1. **Update manifests** in Git repository
2. **Push changes** to Git
3. **ArgoCD automatically detects** changes
4. **ArgoCD applies** changes to cluster
5. **No manual intervention** required!

### **Example: Scaling the Application (Demo)**
```bash
# Edit the deployment manifest
vim apps/music-app/k8s/03-music-app-deployment.yaml
# Change replicas: 3 to replicas: 5

# Push to Git
git add .
git commit -m "Scale music app to 5 replicas"
git push

# ArgoCD automatically scales the application!
```

### **Production GitOps Workflow**
In production, the workflow would be:
1. **Developer pushes code** to source repository
2. **CI/CD builds and tests** the application
3. **CI/CD creates release** with semantic version
4. **CI/CD updates chart** in chart repository
5. **CI/CD updates configs** in config repository
6. **ArgoCD detects changes** and deploys to target environment

## 🧪 **Testing**

### **Automated Testing**
```bash
make app_test
```

This runs comprehensive tests including:
- Pod status verification
- Service connectivity
- Ingress functionality
- API endpoint testing
- Redis connectivity
- Data validation

### **Manual Testing**
```bash
# Test health endpoint
curl http://music.local.io:44134/health

# Test API endpoint
curl http://music.local.io:44134/api/v1/music-albums?key=100

# Check pod status
kubectl get pods -n music-app

# View logs
kubectl logs -f deployment/music-app -n music-app
```

## 🧹 **Cleanup**

### **Clean Application Only**
```bash
make clean
```

### **Clean Everything**
```bash
make clean-all
```

This removes:
- ArgoCD Application
- Kubernetes namespace and all resources
- Docker image
- Host entries
- Temporary files

## 🔍 **Troubleshooting**

### **Common Issues**

#### **1. Dependencies Missing**
```bash
make check-deps
```

#### **2. Infrastructure Issues**
```bash
make infra_status
```

#### **3. Application Issues**
```bash
make app_logs
```

#### **4. GitOps Issues**
```bash
argocd app get music-app
argocd app sync music-app
```

### **Debugging Commands**
```bash
# Check cluster status
kubectl cluster-info

# Check ArgoCD status
kubectl get pods -n argocd

# Check application status
kubectl get pods -n music-app

# Check ingress status
kubectl get ingress -n music-app

# Test connectivity
curl -k https://music.local.io:6600/health
```

## 🚀 **Production Flow Structure**

For production deployments, the entire flow should be properly split into separate repositories and processes:

### **1. Source Code Repository**
```
music-app-source/
├── src/                    # Application source code
├── Dockerfile             # Container definition
├── .github/               # CI/CD workflows
│   └── workflows/
│       ├── build.yml      # Build and test
│       ├── release.yml    # Create releases
│       └── deploy.yml     # Deploy to environments
├── tests/                 # Unit and integration tests
├── docs/                  # Documentation
└── package.json           # Dependencies and scripts
```

**Key Features:**
- **Proper CI/CD pipelines** with semantic versioning
- **Automated testing** (unit, integration, security)
- **Docker image building** and publishing to registry
- **Release management** with proper tagging
- **Code quality gates** and security scanning

### **2. Common Helm Chart Repository**
```
music-app-chart/
├── Chart.yaml             # Chart metadata and versioning
├── values.yaml            # Default values
├── templates/             # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   └── secret.yaml
├── charts/                # Dependencies
├── tests/                 # Chart tests
└── README.md              # Chart documentation
```

**Key Features:**
- **Proper chart versioning** (semantic versioning)
- **Reusable templates** for different environments
- **Chart testing** and validation
- **Dependency management** (Redis, etc.)
- **Documentation** and examples

### **3. Configuration Repository**
```
music-app-configs/
├── environments/
│   ├── dev/
│   │   ├── values.yaml    # Dev-specific overrides
│   │   └── secrets.yaml   # Dev secrets (encrypted)
│   ├── staging/
│   │   ├── values.yaml    # Staging-specific overrides
│   │   └── secrets.yaml   # Staging secrets (encrypted)
│   └── prod/
│       ├── values.yaml    # Prod-specific overrides
│       └── secrets.yaml   # Prod secrets (encrypted)
├── argocd/
│   ├── applications/
│   │   ├── music-app-dev.yaml
│   │   ├── music-app-staging.yaml
│   │   └── music-app-prod.yaml
│   └── projects/
│       └── music-app-project.yaml
└── README.md              # Configuration documentation
```

**Key Features:**
- **Environment-specific configurations** overriding default chart values
- **Secret management** with proper encryption (SOPS, Sealed Secrets)
- **ArgoCD Application definitions** for each environment
- **GitOps workflow** with proper RBAC and policies
- **Configuration validation** and testing

### **Production Workflow**
```
1. Developer pushes code → Source Repository
2. CI/CD builds and tests → Creates release with semantic version
3. CI/CD builds Docker image → Pushes to registry with version tag
4. CI/CD updates chart version → Pushes to Chart Repository
5. CI/CD updates configs → Pushes to Config Repository
6. ArgoCD detects changes → Deploys to target environment
7. Monitoring and alerting → Validates deployment success
```

## 🚀 **Production Considerations**

For production deployment:

1. **Use separate repositories** as outlined above
2. **Implement proper CI/CD** with semantic versioning
3. **Configure proper TLS certificates** (Let's Encrypt)
4. **Set up monitoring** (Prometheus, Grafana)
5. **Implement backup strategies** for Redis data
6. **Configure RBAC** and security policies
7. **Use external image registry** instead of local images
8. **Implement proper secret management** (SOPS, Sealed Secrets)
9. **Set up proper GitOps workflows** with ArgoCD
10. **Configure multi-environment deployments** (dev/staging/prod)

## 📊 **Monitoring and Observability**

### **Built-in Monitoring**
- **Health checks** for all components
- **Resource limits** and requests
- **Liveness and readiness probes**
- **Comprehensive logging**

### **External Monitoring**
- **ArgoCD dashboard** for GitOps status
- **Kubernetes dashboard** for cluster management
- **Prometheus/Grafana** for metrics (optional)

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## 📄 **License**

This project is licensed under the MIT License - see the LICENSE file for details.

## 🎉 **Success Metrics**

When this deployment is working correctly, you should see:

- ✅ **ArgoCD Application**: Status "Synced"
- ✅ **Music App Pods**: 3/3 Ready
- ✅ **Redis Pod**: 1/1 Ready
- ✅ **API Response**: `{"album":"Iron Maiden"}` for key 100
- ✅ **Health Check**: Returns "OK"
- ✅ **HTTP Access**: Working on port 44134

---

**Happy Deploying! 🚀**
