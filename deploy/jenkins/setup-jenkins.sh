#!/bin/bash
# Jenkins Setup Script for Rocky Linux
# M4: CD Pipeline & Deployment

set -e

echo "========================================="
echo "  Jenkins Setup for Rocky Linux"
echo "  MLOps Assignment 2"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root or with sudo"
    exit 1
fi

# Step 1: Install Java
echo ""
echo "Step 1: Installing Java 17..."
dnf install java-17-openjdk java-17-openjdk-devel -y
print_status "Java installed"
java -version

# Step 2: Install Jenkins
echo ""
echo "Step 2: Installing Jenkins..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install jenkins -y
print_status "Jenkins installed"

# Step 3: Install Python 3.11
echo ""
echo "Step 3: Installing Python 3.11..."
dnf install python3.11 python3.11-pip python3.11-devel -y
alternatives --set python3 /usr/bin/python3.11 || true
print_status "Python 3.11 installed"
python3 --version

# Step 4: Install Docker (if not installed)
echo ""
echo "Step 4: Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf install docker-ce docker-ce-cli containerd.io -y
    systemctl enable docker
    systemctl start docker
    print_status "Docker installed"
else
    print_status "Docker already installed"
fi
docker --version

# Step 5: Add jenkins user to docker group
echo ""
echo "Step 5: Configuring permissions..."
usermod -aG docker jenkins
print_status "Jenkins user added to docker group"

# Step 6: Configure firewall
echo ""
echo "Step 6: Configuring firewall..."
firewall-cmd --permanent --add-port=8080/tcp || true
firewall-cmd --permanent --add-port=8000/tcp || true
firewall-cmd --reload || true
print_status "Firewall configured"

# Step 7: Start Jenkins
echo ""
echo "Step 7: Starting Jenkins..."
systemctl enable jenkins
systemctl start jenkins
print_status "Jenkins started"

# Step 8: Install pip packages globally for jenkins user
echo ""
echo "Step 8: Installing Python packages..."
pip3 install --upgrade pip
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cpu
pip3 install mlflow fastapi uvicorn pillow numpy pandas scikit-learn pyyaml
pip3 install pytest pytest-cov httpx flake8 black isort kaggle
print_status "Python packages installed"

# Get initial password
echo ""
echo "========================================="
echo "  Jenkins Setup Complete!"
echo "========================================="
echo ""
print_status "Jenkins is running on port 8080"
echo ""
echo "Initial Admin Password:"
echo "----------------------------------------"
cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "----------------------------------------"
echo ""
echo "Next steps:"
echo "1. Open http://<your-server-ip>:8080 in browser"
echo "2. Enter the initial admin password above"
echo "3. Install suggested plugins"
echo "4. Create admin user"
echo "5. Configure credentials (see README.md)"
echo "6. Create pipeline job pointing to Jenkinsfile"
echo ""

