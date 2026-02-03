.PHONY: help init install clean-reinstall download dvc-init dvc-add dvc-push dvc-pull data-setup train serve test lint format docker-build docker-run deploy clean

# Default target
help:
	@echo "Cats vs Dogs MLOps Project"
	@echo ""
	@echo "=== Setup ==="
	@echo "  make init            - Create virtual environment and install dependencies"
	@echo "  make install         - Install dependencies only"
	@echo "  make clean-reinstall - Remove venv and reinstall from scratch"
	@echo ""
	@echo "=== Data ==="
	@echo "  make download        - Download dataset from Kaggle"
	@echo "  make dvc-init        - Initialize DVC"
	@echo "  make data-setup      - Full data setup (download + DVC)"
	@echo ""
	@echo "=== Development ==="
	@echo "  make train           - Train the model"
	@echo "  make serve           - Start the API server locally"
	@echo "  make test            - Run tests"
	@echo "  make lint            - Run linter"
	@echo "  make format          - Format code"
	@echo ""
	@echo "=== Docker ==="
	@echo "  make docker-build    - Build Docker image"
	@echo "  make docker-run      - Run Docker container"
	@echo "  make docker-stop     - Stop Docker container"
	@echo ""
	@echo "=== Local Kubernetes (Kind) ==="
	@echo "  make kind-install    - Install Kind and kubectl (brew)"
	@echo "  make kind-up         - Create cluster and deploy (full setup)"
	@echo "  make kind-down       - Delete the Kind cluster"
	@echo "  make kind-status     - Show pods, services, deployments"
	@echo "  make kind-logs       - View pod logs"
	@echo "  make kind-test       - Test API endpoints"
	@echo "  make kind-restart    - Restart deployment"
	@echo "  make kind-shell      - Shell into a pod"
	@echo ""
	@echo "=== Other ==="
	@echo "  make mlflow-ui       - Start MLflow UI"
	@echo "  make clean           - Clean up generated files"

# Environment setup
init:
	@echo "Creating virtual environment..."
	python -m venv .venv
	@echo "Upgrading pip..."
	. .venv/bin/activate && pip install --upgrade pip
	@echo "Installing dependencies (CPU-only PyTorch)..."
	. .venv/bin/activate && pip install -r requirements.txt
	@echo ""
	@echo "✅ Virtual environment created successfully!"
	@echo "Activate with: source .venv/bin/activate"

install:
	pip install -r requirements.txt

# Clean reinstall - removes old venv and reinstalls
clean-reinstall:
	@echo "Removing old virtual environment..."
	rm -rf .venv
	@echo "Clearing pip cache..."
	pip cache purge || true
	@echo "Creating fresh virtual environment..."
	$(MAKE) init

# Data
download:
	./scripts/download-dataset.sh

# DVC
dvc-init:
	@if [ ! -d ".dvc" ]; then \
		dvc init; \
		dvc remote add -d local /tmp/dvc-storage; \
		echo "DVC initialized with local remote storage"; \
	else \
		echo "DVC already initialized"; \
	fi

dvc-add:
	@if [ -d "data/raw/train" ]; then \
		dvc add data/raw; \
		git add data/raw.dvc data/.gitignore; \
		echo "Data added to DVC tracking"; \
	else \
		echo "Error: data/raw/train not found. Run 'make download' first."; \
	fi

dvc-push:
	dvc push

dvc-pull:
	dvc pull

# Full data setup: download dataset, init DVC, and add data
data-setup: download dvc-init dvc-add
	@echo "Data setup complete!"
	@echo "Train cats: $$(ls -1 data/raw/train/cat/*.jpg 2>/dev/null | wc -l)"
	@echo "Train dogs: $$(ls -1 data/raw/train/dog/*.jpg 2>/dev/null | wc -l)"
	@echo "Val cats: $$(ls -1 data/raw/val/cat/*.jpg 2>/dev/null | wc -l)"
	@echo "Val dogs: $$(ls -1 data/raw/val/dog/*.jpg 2>/dev/null | wc -l)"
	@echo "Test cats: $$(ls -1 data/raw/test/cat/*.jpg 2>/dev/null | wc -l)"
	@echo "Test dogs: $$(ls -1 data/raw/test/dog/*.jpg 2>/dev/null | wc -l)"

# Training
train:
	python src/models/train.py

# API
serve:
	uvicorn src.api.app:app --host 0.0.0.0 --port 8000 --reload

# Testing
test:
	pytest tests/ -v --cov=src --cov-report=html

test-quick:
	pytest tests/ -v

# Code quality
lint:
	ruff check src/ tests/

format:
	black src/ tests/ scripts/
	ruff check --fix src/ tests/

# Docker
docker-build:
	docker build -t cats-dogs-api:latest .

docker-run:
	docker run -d -p 8000:8000 --name cats-dogs-api cats-dogs-api:latest

docker-stop:
	docker stop cats-dogs-api && docker rm cats-dogs-api

# ============================================
# Local Kubernetes (Kind) - Mac Development
# ============================================

# Check if Kind is installed
kind-check:
	@which kind > /dev/null || (echo "❌ Kind not installed. Run: brew install kind" && exit 1)
	@which kubectl > /dev/null || (echo "❌ kubectl not installed. Run: brew install kubectl" && exit 1)
	@echo "✅ Kind and kubectl are installed"

# Install Kind and kubectl (Mac)
kind-install:
	@echo "Installing Kind and kubectl..."
	brew install kind kubectl
	@echo "✅ Installation complete"

# Create Kind cluster
kind-create: kind-check
	@echo "Creating Kind cluster..."
	@if kind get clusters | grep -q mlops-cluster; then \
		echo "Cluster already exists"; \
	else \
		kind create cluster --config deploy/k8s/kind-config.yaml; \
	fi
	@echo "✅ Kind cluster ready"
	kubectl cluster-info --context kind-mlops-cluster

# Delete Kind cluster
kind-delete:
	@echo "Deleting Kind cluster..."
	kind delete cluster --name mlops-cluster
	@echo "✅ Cluster deleted"

# Build and load image to Kind
kind-build: kind-check docker-build
	@echo "Loading image to Kind cluster..."
	kind load docker-image cats-dogs-api:latest --name mlops-cluster
	@echo "✅ Image loaded to Kind"

# Deploy to local Kind cluster
kind-deploy: kind-build
	@echo "Deploying to Kind cluster..."
	kubectl apply -f deploy/k8s/namespace.yaml
	kubectl apply -f deploy/k8s/configmap.yaml
	kubectl apply -f deploy/k8s/deployment.yaml
	kubectl apply -f deploy/k8s/service.yaml
	@echo "Waiting for pods to be ready..."
	kubectl wait --for=condition=ready pod -l app=cats-dogs-api -n mlops --timeout=120s || true
	@echo ""
	@echo "✅ Deployment complete!"
	@echo "🌐 API available at: http://localhost:8000"
	@echo ""
	kubectl get pods,svc -n mlops

# Full local K8s setup (create cluster + deploy)
kind-up: kind-create kind-deploy
	@echo ""
	@echo "========================================="
	@echo "✅ Local Kubernetes cluster is running!"
	@echo "========================================="
	@echo ""
	@echo "API Endpoints:"
	@echo "  Health:  http://localhost:8000/health"
	@echo "  Ready:   http://localhost:8000/ready"
	@echo "  Predict: http://localhost:8000/predict"
	@echo "  Docs:    http://localhost:8000/docs"
	@echo ""
	@echo "Useful commands:"
	@echo "  make kind-status  - Check pod status"
	@echo "  make kind-logs    - View pod logs"
	@echo "  make kind-shell   - Shell into pod"
	@echo "  make kind-down    - Stop and delete cluster"

# Stop local K8s (delete cluster)
kind-down: kind-delete

# Status of Kind deployment
kind-status:
	@echo "=== Cluster Info ==="
	kubectl cluster-info --context kind-mlops-cluster 2>/dev/null || echo "Cluster not running"
	@echo ""
	@echo "=== Pods ==="
	kubectl get pods -n mlops -o wide 2>/dev/null || echo "No pods found"
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -n mlops 2>/dev/null || echo "No services found"
	@echo ""
	@echo "=== Deployments ==="
	kubectl get deployments -n mlops 2>/dev/null || echo "No deployments found"

# View logs from Kind pods
kind-logs:
	kubectl logs -l app=cats-dogs-api -n mlops -f --tail=100

# Shell into a pod
kind-shell:
	kubectl exec -it $$(kubectl get pods -n mlops -l app=cats-dogs-api -o jsonpath='{.items[0].metadata.name}') -n mlops -- /bin/bash

# Restart deployment
kind-restart:
	kubectl rollout restart deployment/cats-dogs-api -n mlops
	kubectl rollout status deployment/cats-dogs-api -n mlops

# Scale deployment
kind-scale:
	@read -p "Enter number of replicas: " replicas; \
	kubectl scale deployment/cats-dogs-api -n mlops --replicas=$$replicas
	kubectl get pods -n mlops

# Test the API
kind-test:
	@echo "Testing API endpoints..."
	@echo ""
	@echo "=== Health Check ==="
	curl -s http://localhost:8000/health | python -m json.tool || echo "Failed"
	@echo ""
	@echo "=== Ready Check ==="
	curl -s http://localhost:8000/ready | python -m json.tool || echo "Failed"
	@echo ""
	@echo "=== API Info ==="
	curl -s http://localhost:8000/ | python -m json.tool || echo "Failed"
	@echo ""
	@echo "✅ API tests complete"

# ============================================
# Monitoring (Prometheus + Grafana) - M5
# ============================================

# Deploy Prometheus and Grafana
monitoring-deploy:
	@echo "Deploying Prometheus and Grafana..."
	kubectl apply -f deploy/k8s/prometheus.yaml
	kubectl apply -f deploy/k8s/grafana-dashboard.yaml
	kubectl apply -f deploy/k8s/grafana.yaml
	@echo "Waiting for monitoring pods..."
	kubectl wait --for=condition=ready pod -l app=prometheus -n mlops --timeout=120s || true
	kubectl wait --for=condition=ready pod -l app=grafana -n mlops --timeout=120s || true
	@echo ""
	@echo "✅ Monitoring deployed!"
	@echo "📊 Prometheus: http://localhost:9090"
	@echo "📈 Grafana:    http://localhost:3000 (admin/admin123)"
	@echo ""
	kubectl get pods -n mlops

# Check monitoring status
monitoring-status:
	@echo "=== Monitoring Pods ==="
	kubectl get pods -n mlops -l 'app in (prometheus,grafana)'
	@echo ""
	@echo "=== Monitoring Services ==="
	kubectl get svc -n mlops -l 'app in (prometheus,grafana)'

# View Prometheus logs
prometheus-logs:
	kubectl logs -l app=prometheus -n mlops -f --tail=50

# View Grafana logs
grafana-logs:
	kubectl logs -l app=grafana -n mlops -f --tail=50

# Delete monitoring stack
monitoring-delete:
	kubectl delete -f deploy/k8s/grafana.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/grafana-dashboard.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/prometheus.yaml --ignore-not-found
	@echo "✅ Monitoring deleted"

# Full stack: API + Monitoring
kind-full: kind-up monitoring-deploy
	@echo ""
	@echo "========================================="
	@echo "✅ Full MLOps Stack Running!"
	@echo "========================================="
	@echo ""
	@echo "🌐 API:        http://localhost:8000"
	@echo "📊 Prometheus: http://localhost:9090"
	@echo "📈 Grafana:    http://localhost:3000"
	@echo ""
	@echo "Grafana Login: admin / admin123"

# ============================================
# Legacy Kubernetes commands
# ============================================

# Kubernetes (generic - works with any cluster)
deploy:
	kubectl apply -f deploy/k8s/

k8s-status:
	kubectl get pods,svc,deployments

k8s-logs:
	kubectl logs -l app=cats-dogs-api -f

# MLflow
mlflow-ui:
	mlflow ui --backend-store-uri mlruns --host 0.0.0.0 --port 5000

# Cleanup
clean:
	rm -rf __pycache__ .pytest_cache htmlcov .coverage
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

