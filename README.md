# MLOps Assignment 2 - Cats vs Dogs Classification

[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.1-red.svg)](https://pytorch.org/)
[![MLflow](https://img.shields.io/badge/MLflow-2.10-blue.svg)](https://mlflow.org/)

**Course:** AIMLCZG523 - MLOps
**Institution:** BITS Pilani (WILP)
**Student ID:** 2024aa05820

## 📋 Project Overview

Binary image classification system for a pet adoption platform to automatically categorize uploaded pet images as either **cats** or **dogs**. This project demonstrates end-to-end MLOps practices including:

- **M1:** Model Development & Experiment Tracking
- **M2:** Model Packaging & Containerization
- **M3:** CI Pipeline for Build, Test & Image Creation
- **M4:** CD Pipeline & Deployment
- **M5:** Monitoring, Logs & Final Submission

## 🏗️ Project Structure

```
mlops-assignment2/
├── .github/workflows/       # GitHub Actions CI/CD pipelines
├── .dvc/                    # DVC configuration
├── data/
│   ├── raw/                 # Raw dataset (DVC tracked)
│   │   ├── train/           # Training data (80%)
│   │   ├── val/             # Validation data (10%)
│   │   └── test/            # Test data (10%)
│   └── processed/           # Preprocessed data
├── deploy/k8s/              # Kubernetes manifests
├── grafana/                 # Grafana dashboards
├── models/                  # Saved model artifacts
├── mlruns/                  # MLflow tracking data
├── notebooks/               # Jupyter notebooks
├── reports/                 # Generated reports (confusion matrix, etc.)
├── scripts/                 # Utility scripts
├── src/
│   ├── api/                 # FastAPI application
│   ├── config/              # Configuration files
│   ├── data/                # Data loading & preprocessing
│   └── models/              # Model architecture & training
├── tests/                   # Unit tests
├── .gitignore
├── .dvcignore
├── Dockerfile
├── Makefile
├── requirements.txt
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Python 3.11+
- Git
- Kaggle account (for dataset download)
- Docker (for containerization)
- kubectl & Minikube (for deployment)

### Step-by-Step Setup

#### Step 1: Clone the Repository

```bash
git clone https://github.com/2024aa05820/mlops-assignment2.git
cd mlops-assignment2
```

#### Step 2: Create Virtual Environment & Install Dependencies

```bash
# Create and activate virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Or use make command
make init
source .venv/bin/activate
```

#### Step 3: Configure Kaggle API

```bash
# Create Kaggle API credentials
mkdir -p ~/.kaggle
# Download kaggle.json from https://www.kaggle.com/account
# Move it to ~/.kaggle/kaggle.json
chmod 600 ~/.kaggle/kaggle.json
```

#### Step 4: Download Dataset & Initialize DVC

```bash
# Option A: Run all data setup in one command
make data-setup

# Option B: Run steps individually
make download      # Download and split Kaggle dataset
make dvc-init      # Initialize DVC
make dvc-add       # Add data to DVC tracking
```

#### Step 5: Train the Model

```bash
# Train with default configuration
make train

# Or run directly with custom parameters
python src/models/train.py --epochs 10 --batch-size 32 --lr 0.001
```

#### Step 6: View Experiment Results in MLflow

```bash
# Start MLflow UI
make mlflow-ui

# Open browser at http://localhost:5000
```

#### Step 7: Run the API Server (Local)

```bash
# Start FastAPI server
make serve

# API will be available at http://localhost:8000
# Swagger docs at http://localhost:8000/docs
```

#### Step 8: Build & Run Docker Container

```bash
# Build Docker image
make docker-build

# Run container
make docker-run

# Test the API
curl http://localhost:8000/health

# Stop container
make docker-stop
```

#### Step 9: Deploy to Kubernetes

```bash
# Start Minikube (if not running)
minikube start

# Deploy application
make deploy

# Check status
make k8s-status

# View logs
make k8s-logs
```

## 📊 Model Architecture

**SimpleCNN** - A lightweight CNN for binary classification:

| Layer | Output Shape | Parameters |
|-------|--------------|------------|
| Conv2D Block 1 | 32 × 112 × 112 | 896 |
| Conv2D Block 2 | 64 × 56 × 56 | 18,496 |
| Conv2D Block 3 | 128 × 28 × 28 | 73,856 |
| Conv2D Block 4 | 256 × 14 × 14 | 295,168 |
| Global Avg Pool | 256 × 1 × 1 | 0 |
| FC Layer 1 | 128 | 32,896 |
| FC Layer 2 | 2 | 258 |
| **Total** | | **~421K** |

## 🔧 Available Make Commands

```bash
make help          # Show all available commands

# Environment
make init          # Create venv and install dependencies
make install       # Install dependencies only

# Data
make download      # Download dataset from Kaggle
make dvc-init      # Initialize DVC
make dvc-add       # Add data to DVC tracking
make data-setup    # Full data setup (download + DVC)

# Training
make train         # Train the model

# API
make serve         # Start FastAPI server locally

# Testing
make test          # Run tests with coverage
make test-quick    # Run tests without coverage

# Code Quality
make lint          # Run linter (ruff)
make format        # Format code (black + ruff)

# Docker
make docker-build  # Build Docker image
make docker-run    # Run Docker container
make docker-stop   # Stop and remove container

# Kubernetes
make deploy        # Deploy to Kubernetes
make k8s-status    # Check deployment status
make k8s-logs      # View application logs

# MLflow
make mlflow-ui     # Start MLflow UI

# Cleanup
make clean         # Clean generated files
```

## 📈 MLflow Experiment Tracking

The training script automatically logs to MLflow:

- **Parameters:** learning_rate, batch_size, epochs, dropout, etc.
- **Metrics:** train/val loss, accuracy, precision, recall, F1 score
- **Artifacts:** confusion matrix, training curves, model checkpoint

## 🧪 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/predict` | POST | Predict cat/dog from image |
| `/metrics` | GET | Prometheus metrics |
| `/docs` | GET | Swagger UI documentation |

## 📦 Technology Stack

| Component | Technology |
|-----------|------------|
| Language | Python 3.11+ |
| ML Framework | PyTorch 2.1 |
| API Framework | FastAPI |
| Experiment Tracking | MLflow |
| Data Versioning | DVC |
| Containerization | Docker |
| Orchestration | Kubernetes (Minikube) |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana |
| Infrastructure | Rocky Linux / RHEL |

## 📝 License

This project is for educational purposes as part of BITS Pilani WILP MLOps course.

