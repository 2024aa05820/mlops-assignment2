# MLOps Assignment 2 - Cats vs Dogs Classification

[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.1-red.svg)](https://pytorch.org/)
[![MLflow](https://img.shields.io/badge/MLflow-2.10-blue.svg)](https://mlflow.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Kind-blue.svg)](https://kind.sigs.k8s.io/)

**Course:** AIMLCZG523 - MLOps
**Institution:** BITS Pilani (WILP)
**Student ID:** 2024aa05820

---

## 📋 Table of Contents

1. [Project Overview](#-project-overview)
2. [Milestone Summary](#-milestone-summary)
3. [Project Structure](#-project-structure)
4. [Prerequisites](#-prerequisites)
5. [Installation & Setup](#-installation--setup)
6. [M1: Model Development & Experiment Tracking](#m1-model-development--experiment-tracking)
7. [M2: Model Packaging & Containerization](#m2-model-packaging--containerization)
8. [M3: CI Pipeline (Jenkins)](#m3-ci-pipeline-jenkins)
9. [M4: CD Pipeline & Kubernetes Deployment](#m4-cd-pipeline--kubernetes-deployment)
10. [M5: Monitoring & Logging](#m5-monitoring--logging)
11. [API Documentation](#-api-documentation)
12. [Make Commands Reference](#-make-commands-reference)
13. [Troubleshooting](#-troubleshooting)

---

## 📋 Project Overview

Binary image classification system for a pet adoption platform to automatically categorize uploaded pet images as either **cats** or **dogs**. This project demonstrates end-to-end MLOps practices from model development to production deployment with monitoring.

### Key Features

- 🧠 **Deep Learning Model**: SimpleCNN (~422K parameters) for binary classification
- 📊 **Experiment Tracking**: MLflow for tracking experiments, metrics, and artifacts
- 🐳 **Containerization**: Docker with CPU-optimized PyTorch
- ☸️ **Kubernetes Deployment**: Local Kind cluster with auto-scaling
- 🔄 **CI/CD Pipeline**: Jenkins for automated build, test, and deploy
- 📈 **Monitoring**: Prometheus + Grafana with custom dashboards
- 📝 **Structured Logging**: Request/response logging with latency tracking

---

## ✅ Milestone Summary

| Milestone | Description | Status |
|-----------|-------------|--------|
| **M1** | Model Development & Experiment Tracking | ✅ Complete |
| **M2** | Model Packaging & Containerization | ✅ Complete |
| **M3** | CI Pipeline (Jenkins) | ✅ Complete |
| **M4** | CD Pipeline & Kubernetes Deployment | ✅ Complete |
| **M5** | Monitoring, Logs & Final Submission | ✅ Complete |

---

## 🏗️ Project Structure

```
mlops-assignment2/
├── src/
│   ├── api/                 # FastAPI application
│   │   └── app.py           # Main API with Prometheus metrics
│   ├── config/              # Configuration files
│   │   └── config.yaml      # Training & API configuration
│   ├── data/                # Data loading & preprocessing
│   │   ├── dataset.py       # PyTorch Dataset class
│   │   └── preprocessing.py # Image transforms
│   └── models/              # Model architecture & training
│       ├── cnn.py           # SimpleCNN architecture
│       ├── train.py         # Training script with MLflow
│       └── predict.py       # Inference module
├── deploy/
│   ├── k8s/                 # Kubernetes manifests
│   │   ├── kind-config.yaml # Kind cluster configuration
│   │   ├── namespace.yaml   # Namespace definition
│   │   ├── deployment.yaml  # API deployment
│   │   ├── service.yaml     # NodePort service
│   │   ├── configmap.yaml   # Environment configuration
│   │   ├── hpa.yaml         # Horizontal Pod Autoscaler
│   │   ├── prometheus.yaml  # Prometheus deployment
│   │   ├── grafana.yaml     # Grafana deployment
│   │   ├── grafana-dashboard.yaml  # Pre-configured dashboards
│   │   └── node-exporter.yaml      # OS metrics exporter
│   ├── jenkins/             # Jenkins configuration
│   └── smoke-test.sh        # Deployment smoke tests
├── tests/                   # Unit tests
│   ├── test_api.py          # API endpoint tests
│   ├── test_model.py        # Model architecture tests
│   └── test_preprocessing.py # Data preprocessing tests
├── scripts/                 # Utility scripts
│   ├── validate_model.py    # Model validation for CI/CD
│   └── download_sample_data.py
├── data/                    # Dataset (DVC tracked)
├── models/                  # Saved model artifacts
├── mlruns/                  # MLflow tracking data
├── reports/                 # Generated reports
├── Dockerfile               # Container definition
├── Jenkinsfile              # CI/CD pipeline
├── Makefile                 # Automation commands
└── requirements.txt         # Python dependencies
```

---

## 📦 Prerequisites

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| Python | 3.9+ | Runtime |
| Git | Latest | Version control |
| Docker | Latest | Containerization |
| Kind | Latest | Local Kubernetes |
| kubectl | Latest | Kubernetes CLI |
| Jenkins | LTS | CI/CD (optional) |

### Installation (Mac)

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install python@3.11 git docker kind kubectl

# Start Docker Desktop
open -a Docker

# Verify installations
python3 --version
docker --version
kind --version
kubectl version --client
```

### Installation (Linux)

```bash
# Python & Git
sudo apt update
sudo apt install -y python3.11 python3.11-venv git

# Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

---

## 🚀 Installation & Setup

### Step 1: Clone Repository

```bash
git clone https://github.com/2024aa05820/mlops-assignment2.git
cd mlops-assignment2
```

### Step 2: Create Virtual Environment

```bash
# Create virtual environment
python3 -m venv .venv

# Activate (Mac/Linux)
source .venv/bin/activate

# Activate (Windows)
.venv\Scripts\activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

Or use Make:

```bash
make init
source .venv/bin/activate
```

### Step 3: Configure Kaggle API

The dataset is from: [Dog and Cat Classification Dataset](https://www.kaggle.com/datasets/bhavikjikadara/dog-and-cat-classification-dataset)

**Option A: Environment Variables**

```bash
export KAGGLE_USERNAME=your_username
export KAGGLE_KEY=your_api_key
```

**Option B: kaggle.json file**

```bash
mkdir -p ~/.kaggle
# Download kaggle.json from https://www.kaggle.com/settings
mv ~/Downloads/kaggle.json ~/.kaggle/
chmod 600 ~/.kaggle/kaggle.json
```

### Step 4: Download Dataset

```bash
make download
# or
make data-setup  # Includes DVC initialization
```

---

## M1: Model Development & Experiment Tracking

### Train the Model

```bash
# Train with default configuration
make train

# Or with custom parameters
python src/models/train.py --epochs 5 --batch-size 64 --lr 0.001
```

### View Experiments in MLflow

```bash
# Start MLflow UI
make mlflow-ui

# Open browser
open http://localhost:5000
```

### Model Architecture

**SimpleCNN** - Lightweight CNN optimized for binary classification:

```
Input (224×224×3)
    ↓
Conv Block 1: Conv2D(3→32) + BatchNorm + ReLU + MaxPool → 112×112×32
    ↓
Conv Block 2: Conv2D(32→64) + BatchNorm + ReLU + MaxPool → 56×56×64
    ↓
Conv Block 3: Conv2D(64→128) + BatchNorm + ReLU + MaxPool → 28×28×128
    ↓
Conv Block 4: Conv2D(128→256) + BatchNorm + ReLU + MaxPool → 14×14×256
    ↓
Global Average Pooling → 256
    ↓
FC(256→128) + ReLU + Dropout(0.5)
    ↓
FC(128→2) → Output (cat/dog probabilities)

Total Parameters: ~422,000
```

### MLflow Tracked Metrics

| Metric | Description |
|--------|-------------|
| `train_loss` | Training loss per epoch |
| `val_loss` | Validation loss per epoch |
| `train_accuracy` | Training accuracy |
| `val_accuracy` | Validation accuracy |
| `val_precision` | Validation precision |
| `val_recall` | Validation recall |
| `val_f1` | Validation F1 score |

---

## M2: Model Packaging & Containerization

### Run API Locally

```bash
# Start FastAPI server
make serve

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/docs  # Swagger UI
```

### Build Docker Image

```bash
# Build image
make docker-build

# Run container
make docker-run

# Test
curl http://localhost:8000/health

# Stop
make docker-stop
```

### Dockerfile Highlights

- Base: `python:3.11-slim`
- CPU-only PyTorch (smaller image)
- Health check configured
- Non-root user for security

---

## M3: CI Pipeline (Jenkins)

### Jenkins Setup

1. **Install Jenkins** (Mac):
   ```bash
   brew install jenkins-lts
   brew services start jenkins-lts
   open http://localhost:8080
   ```

2. **Configure Credentials** in Jenkins:

   | Credential ID | Type | Description |
   |---------------|------|-------------|
   | `ghcr-token` | Secret text | GitHub PAT with `write:packages` |
   | `kaggle-username` | Secret text | Kaggle username |
   | `kaggle-key` | Secret text | Kaggle API key |

3. **Create Pipeline Job**:
   - New Item → Pipeline
   - Pipeline from SCM → Git
   - Repository URL: `https://github.com/2024aa05820/mlops-assignment2.git`
   - Script Path: `Jenkinsfile`

### Pipeline Stages

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Checkout   │ →  │   Setup     │ →  │    Lint     │
│             │    │   Python    │    │   & Test    │
└─────────────┘    └─────────────┘    └─────────────┘
       ↓
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Download   │ →  │   Train     │ →  │  Validate   │
│    Data     │    │   Model     │    │   Model     │
└─────────────┘    └─────────────┘    └─────────────┘
       ↓
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Docker    │ →  │   Docker    │ →  │  Deploy to  │
│   Build     │    │    Push     │    │ Kubernetes  │
└─────────────┘    └─────────────┘    └─────────────┘
       ↓
┌─────────────┐
│   Smoke     │
│   Tests     │
└─────────────┘
```

---

## M4: CD Pipeline & Kubernetes Deployment

### Quick Start with Kind

```bash
# Create cluster and deploy everything
make kind-full

# This will:
# 1. Create Kind cluster with port mappings
# 2. Build and load Docker image
# 3. Deploy API to Kubernetes
# 4. Deploy Prometheus & Grafana
```

### Access Points

| Service | URL |
|---------|-----|
| **API** | http://localhost:8000 |
| **API Docs** | http://localhost:8000/docs |
| **Prometheus** | http://localhost:9090 |
| **Grafana** | http://localhost:3000 |

### Individual Commands

```bash
# Create Kind cluster
make kind-create

# Build and load image
make kind-build

# Deploy API only
make kind-deploy

# Check status
make kind-status

# View logs
make kind-logs

# Delete cluster
make kind-down
```

### Kubernetes Resources

| Resource | Description |
|----------|-------------|
| `Namespace` | `mlops` - isolated namespace |
| `Deployment` | 2 replicas with rolling updates |
| `Service` | NodePort exposing port 8000 |
| `ConfigMap` | Environment configuration |
| `HPA` | Auto-scaling (1-5 replicas) |

---

## M5: Monitoring & Logging

### Deploy Monitoring Stack

```bash
# Deploy Prometheus + Grafana + Node Exporter
make monitoring-deploy
```

### Access Grafana

1. Open http://localhost:3000
2. Login: `admin` / `admin123`
3. Dashboard is pre-configured!

### Dashboard Panels

#### Application Metrics
| Panel | Description |
|-------|-------------|
| Total Predictions | Count of all predictions |
| Total Errors | Count of prediction errors |
| Avg Latency | Average prediction latency |
| Requests/sec | Request rate |
| Predictions by Class | Cat vs Dog over time |
| Latency Percentiles | p50, p95, p99 |

#### System Metrics (OS-Level)
| Panel | Description |
|-------|-------------|
| CPU Usage | Current CPU utilization % |
| Memory Usage | Current memory utilization % |
| Disk Usage | Disk space utilization % |
| CPU by Core | Per-core CPU usage |
| Memory Over Time | Used, Cached, Buffers |
| Network I/O | Bytes received/transmitted |
| Disk I/O | Bytes read/written |

### Prometheus Metrics

```bash
# View raw metrics
curl http://localhost:8000/metrics

# Available metrics:
# - predictions_total{predicted_class="cat|dog"}
# - prediction_latency_seconds (histogram)
# - prediction_errors_total
```

### Structured Logging

The API logs all requests with:
- Request ID (for tracing)
- HTTP method and path
- Response status code
- Latency in milliseconds
- Prediction details (class, confidence)

```bash
# View API logs
make kind-logs

# Example output:
# 2026-02-03 10:15:23 | INFO | [a1b2c3d4] Request: POST /predict
# 2026-02-03 10:15:23 | INFO | Prediction: cat | Confidence: 87.50% | Latency: 45.23ms
# 2026-02-03 10:15:23 | INFO | [a1b2c3d4] Response: 200 | Latency: 48.12ms
```

---

## 🧪 API Documentation

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | API info |
| `/health` | GET | Health check (liveness) |
| `/ready` | GET | Readiness check |
| `/predict` | POST | Predict cat/dog |
| `/metrics` | GET | Prometheus metrics |
| `/docs` | GET | Swagger UI |

### Predict Endpoint

**Request:**
```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: multipart/form-data" \
  -F "file=@path/to/image.jpg"
```

**Response:**
```json
{
  "prediction": "cat",
  "probability": 0.875,
  "confidence": 0.875,
  "probabilities": {
    "cat": 0.875,
    "dog": 0.125
  },
  "inference_time_ms": 45.23
}
```

---

## 🔧 Make Commands Reference

### Environment
```bash
make init          # Create venv and install dependencies
make install       # Install dependencies only
```

### Data
```bash
make download      # Download dataset from Kaggle
make data-setup    # Full data setup (download + DVC)
```

### Training
```bash
make train         # Train the model
make mlflow-ui     # Start MLflow UI
```

### Testing
```bash
make test          # Run tests with coverage
make test-quick    # Run tests without coverage
make lint          # Run linter (ruff)
make format        # Format code (black + ruff)
```

### Docker
```bash
make docker-build  # Build Docker image
make docker-run    # Run Docker container
make docker-stop   # Stop and remove container
```

### Kubernetes (Kind)
```bash
make kind-full     # Full stack: cluster + API + monitoring
make kind-up       # Create cluster and deploy API
make kind-down     # Delete cluster
make kind-status   # Check deployment status
make kind-logs     # View API logs
make kind-test     # Test API endpoints
make kind-restart  # Restart deployment
```

### Monitoring
```bash
make monitoring-deploy   # Deploy Prometheus + Grafana
make monitoring-status   # Check monitoring pods
make monitoring-delete   # Remove monitoring stack
make prometheus-logs     # View Prometheus logs
make grafana-logs        # View Grafana logs
```

---

## 🔍 Troubleshooting

### Docker Issues

```bash
# Docker not running
open -a Docker  # Mac
sudo systemctl start docker  # Linux

# Permission denied
sudo usermod -aG docker $USER
newgrp docker
```

### Kind Issues

```bash
# Cluster not starting
kind delete cluster --name mlops-cluster
make kind-create

# Image not loading
docker images | grep cats-dogs-api
kind load docker-image cats-dogs-api:latest --name mlops-cluster
```

### API Issues

```bash
# Check pod status
kubectl get pods -n mlops

# Check pod logs
kubectl logs -l app=cats-dogs-api -n mlops

# Describe pod for errors
kubectl describe pod -l app=cats-dogs-api -n mlops
```

### Monitoring Issues

```bash
# Check if Prometheus is scraping
curl http://localhost:9090/api/v1/targets

# Grafana datasource not working
# Manually add: Configuration → Data Sources → Prometheus
# URL: http://prometheus:9090
```

---

## 📦 Technology Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Language | Python | 3.11+ |
| ML Framework | PyTorch | 2.1 (CPU) |
| API Framework | FastAPI | 0.109+ |
| Experiment Tracking | MLflow | 2.10+ |
| Data Versioning | DVC | 3.38+ |
| Containerization | Docker | Latest |
| Orchestration | Kubernetes (Kind) | Latest |
| CI/CD | Jenkins | LTS |
| Monitoring | Prometheus | 2.48 |
| Visualization | Grafana | 10.2 |
| OS Metrics | Node Exporter | 1.7 |

---

## 📝 License

This project is for educational purposes as part of BITS Pilani WILP MLOps course (AIMLCZG523).

