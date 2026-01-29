# Jenkins Setup on Rocky Linux

## M4: CD Pipeline & Deployment - Jenkins on Rocky Linux VM

This guide covers setting up Jenkins on Rocky Linux to run the complete CI/CD pipeline for the Cats vs Dogs classification model.

---

## Prerequisites

- Rocky Linux 9.x server
- Root or sudo access
- At least 4GB RAM, 20GB disk space
- Docker installed
- Python 3.11+ installed

---

## Step 1: Install Java (Required for Jenkins)

```bash
# Install Java 17
sudo dnf install java-17-openjdk java-17-openjdk-devel -y

# Verify installation
java -version
```

---

## Step 2: Install Jenkins

```bash
# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
sudo dnf install jenkins -y

# Start and enable Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Check status
sudo systemctl status jenkins
```

---

## Step 3: Configure Firewall

```bash
# Open port 8080 for Jenkins
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=8000/tcp  # For API
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

---

## Step 4: Initial Jenkins Setup

1. Get the initial admin password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

2. Open browser: `http://<your-server-ip>:8080`

3. Enter the initial admin password

4. Install suggested plugins

5. Create admin user

---

## Step 5: Install Required Jenkins Plugins

Go to: **Manage Jenkins → Plugins → Available plugins**

Install these plugins:
- Pipeline
- Git
- GitHub Integration
- Docker Pipeline
- Credentials Binding
- Blue Ocean (optional, for better UI)

---

## Step 6: Configure Jenkins User Permissions

```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins
sudo systemctl restart jenkins
```

---

## Step 7: Configure Credentials

Go to: **Manage Jenkins → Credentials → System → Global credentials**

### Add Kaggle API Token:
- Kind: Secret text
- ID: `kaggle-api-token`
- Secret: `your_kaggle_username:your_kaggle_api_key`

### Add GitHub Container Registry (GHCR):
- Kind: Username with password
- ID: `ghcr-credentials`
- Username: Your GitHub username
- Password: Your GitHub Personal Access Token (with `write:packages` scope)

---

## Step 8: Create Pipeline Job

1. **New Item** → Enter name: `mlops-cats-dogs-pipeline`
2. Select **Pipeline** → OK
3. Configure:
   - **Build Triggers**: ✅ Poll SCM
   - **Schedule**: `H/5 * * * *` (every 5 minutes)
   - **Pipeline Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/2024aa05820/mlops-assignment2.git`
   - **Branch**: `*/main`
   - **Script Path**: `Jenkinsfile`
4. **Save**

---

## Step 9: Run the Pipeline

1. Click **Build Now**
2. Watch the pipeline progress in **Blue Ocean** or **Console Output**

---

## Pipeline Stages

| Stage | Description | Duration |
|-------|-------------|----------|
| Checkout | Clone repository | ~10s |
| Setup Python | Install dependencies | ~60s |
| Lint & Code Quality | flake8, black, isort | ~10s |
| Unit Tests | pytest | ~30s |
| Download Data | Kaggle dataset (2000 samples) | ~120s |
| Train Model | 3 epochs, batch_size=128 | ~300s |
| Model Validation | Accuracy check, inference test | ~10s |
| Docker Build | Build container image | ~120s |
| Docker Push | Push to GHCR | ~60s |
| Deploy | Run container locally | ~10s |
| Smoke Tests | Health checks | ~10s |

**Total: ~12 minutes**

---

## Troubleshooting

### Jenkins can't access Docker
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Python not found
```bash
sudo dnf install python3.11 python3.11-pip -y
sudo alternatives --set python3 /usr/bin/python3.11
```

### Permission denied on workspace
```bash
sudo chown -R jenkins:jenkins /var/lib/jenkins/workspace
```

### Kaggle authentication fails
- Verify credential format: `username:api_key`
- Check credential ID matches: `kaggle-api-token`

---

## Accessing the Deployed API

After successful deployment:

```bash
# Health check
curl http://localhost:8000/health

# Prediction
curl -X POST http://localhost:8000/predict -F "file=@test_image.jpg"

# API docs
open http://localhost:8000/docs
```

