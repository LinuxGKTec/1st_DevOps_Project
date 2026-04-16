provider "aws" {
  region = var.aws_region
}

# 1. The VPC
resource "aws_vpc" "myvpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "DevOps-VPC"
  }
}

# 2. Public Subnet1 (Where your Ec2 nodes will live)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true # Automatically gives nodes a public IP

  tags = {
    Name = "public-subnet1"
  }
}

# 3. Public Subnet2 (Where your Ec2 nodes will live)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true # Automatically gives nodes a public IP

  tags = {
    Name = "public-subnet1"
  }
}

# 4. Internet Gateway (The door to the internet)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "DevOps-igw"
  }
}

# 5. Routing table
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }


  tags = {
    Name = "DevOps RT"
  }
}

# 6 Routing table association
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.example.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.example.id
}

# 7. Security group
resource "aws_security_group" "allow_ports" {
  name        = "allow_ports"
  description = "Allow inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id


  # Standard Access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom App Port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes Specific (Control Plane)
  ingress {
    description = "K8s API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Allow internal VPC only
  }

  # Outbound Rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DevOps-sg"
  }
}

# 8. Create 3 instance  and Get latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS ID

  filter {
    name   = "name"
    # Using a wildcard that covers both gp2 (ssd) and gp3 (ssd-gp3) patterns
    values = ["ubuntu/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# K8s Minikube Node (c7i-flex.large)
resource "aws_instance" "kubeadm_node" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_master
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.allow_ports.id]
  key_name               = var.key_name

  user_data = <<EOF
#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

log() { echo -e "${var.BLUE}[INFO]${var.NC} $1"; }
success() { echo -e "${var.GREEN}[SUCCESS]${var.NC} $1"; }
warn() { echo -e "${var.YELLOW}[WARNING]${var.NC} $1"; }
error() { echo -e "${var.RED}[ERROR]${var.NC} $1"; exit 1; }

# 1. Check/Install Docker
if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    sudo apt update && sudo apt install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker ubuntu
    success "Docker installed. Note: You may need to log out and back in to run docker without sudo."
else
    success "Docker is already installed."
fi
# 2. Check/Install Minikube
if ! command -v minikube &> /dev/null; then
    log "Installing Minikube..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
    sudo dpkg -i minikube_latest_amd64.deb
    success "Minikube installed."
else
    success "Minikube is already installed."
fi

# 3. Check/Install Kubectl
if ! command -v kubectl &> /dev/null; then
    log "Installing Kubectl..."
    K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/$${K8S_VERSION}/bin/linux/amd64/kubectl"
    
    # Validate checksum
    curl -LO "https://dl.k8s.io/release/$${K8S_VERSION}/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --status || error "Checksum validation failed!"
    
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl kubectl.sha256
    success "Kubectl installed."
else
    success "Kubectl is already installed."
fi

# 4. Start Cluster
log "Starting Minikube cluster..."
if minikube status &> /dev/null; then
    warn "Minikube is already running."
else
    # We use --driver=docker to ensure it uses the docker engine we just installed
    sudo -u ubuntu bash <<'EOT'
export HOME=/home/ubuntu
minikube start --driver=docker --force
EOT
fi

log "Waiting for pods to initialize..."
  sudo -u ubuntu bash <<'EOT'
kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo "=========================================="
success "Environment is ready!"
kubectl get po -A
EOT
EOF 
  tags = {
    Name = "Minikube"
  }
}

# 9. Jenkins  node (t3.micro)
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_worker
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.allow_ports.id]
  key_name               = var.key_name # Change this to your existing AWS Key Pair name

  user_data = <<EOF
#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1
echo "Installing Jenkins"
if ! command -v jenkins &> /dev/null; then
    echo ""Installing Jenkins...""
    sudo apt update
    sudo apt install fontconfig openjdk-21-jre
    java -version
    sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
    echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt update
    sudo apt install jenkins
else
    echo "Jenkins is already installed."
fi
EOF

  tags = {
    Name = "jenkins"
  }
}

# 10. Ansible node (t3.micro)
resource "aws_instance" "ansible" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_worker
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.allow_ports.id]
  key_name               = var.key_name # Change this to your existing AWS Key Pair name
  user_data = <<EOF
#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1
echo "Installing Ansible"
echo "==================="

if ! command -v ansible &> /dev/null; then 
    echo "Ansible installtion starting"
    sudo apt update
    sudo apt install software-properties-common
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt install ansible
    ansible --version
else
    echo "Ansible already installed"
fi
EOF
  tags = {
    Name = "ansible-node"
  }
}