#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

## 1. Check/Install Docker
if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    sudo apt update && sudo apt install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF > /dev/null
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group (takes effect after logout or using 'newgrp')
    sudo usermod -aG docker $USER
    success "Docker installed. Note: You may need to log out and back in to run docker without sudo."
else
    success "Docker is already installed."
fi

## 2. Check/Install Minikube
if ! command -v minikube &> /dev/null; then
    log "Installing Minikube..."
    curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
    success "Minikube installed."
else
    success "Minikube is already installed."
fi

## 3. Check/Install Kubectl
if ! command -v kubectl &> /dev/null; then
    log "Installing Kubectl..."
    K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
    
    # Validate checksum
    curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --status || error "Checksum validation failed!"
    
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl kubectl.sha256
    success "Kubectl installed."
else
    success "Kubectl is already installed."
fi

## 4. Start Cluster
log "Starting Minikube cluster..."
if minikube status &> /dev/null; then
    warn "Minikube is already running."
else
    # We use --driver=docker to ensure it uses the docker engine we just installed
    minikube start --driver=docker --force
fi

log "Waiting for pods to initialize..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo "=========================================="
success "Environment is ready!"
kubectl get po -A


