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
	@echo "=== Stop Services ==="
	@echo "  make monitoring-stop - Stop monitoring (Prometheus, Grafana, AlertManager)"
	@echo "  make app-stop        - Stop application (API deployment)"
	@echo "  make all-stop        - Stop everything (keep cluster running)"
	@echo "  make kind-delete     - Delete entire Kind cluster"
	@echo ""
	@echo "=== Other ==="
	@echo "  make mlflow-ui       - Start MLflow UI"
	@echo "  make clean           - Clean up generated files"
	@echo ""
	@echo "=== Submission ==="
	@echo "  make submission-zip  - Create ZIP file for assignment submission"

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

# Deploy full monitoring stack (Prometheus + Grafana + Alerting)
monitoring-deploy:
	@echo "========================================="
	@echo "🚀 Deploying Full Monitoring Stack"
	@echo "========================================="
	@echo ""
	@echo "1️⃣  Deploying Prometheus Alert Rules..."
	kubectl apply -f deploy/k8s/prometheus-alerts.yaml
	@echo "2️⃣  Deploying Prometheus..."
	kubectl apply -f deploy/k8s/prometheus.yaml
	@echo "3️⃣  Deploying Kube State Metrics..."
	kubectl apply -f deploy/k8s/kube-state-metrics.yaml
	@echo "4️⃣  Deploying Node Exporter (OS metrics)..."
	kubectl apply -f deploy/k8s/node-exporter.yaml
	@echo "5️⃣  Deploying AlertManager..."
	kubectl apply -f deploy/k8s/alertmanager.yaml
	@echo "6️⃣  Deploying Grafana Dashboards..."
	kubectl apply -f deploy/k8s/grafana-dashboard.yaml
	@echo "7️⃣  Deploying Grafana..."
	kubectl apply -f deploy/k8s/grafana.yaml
	@echo ""
	@echo "⏳ Waiting for monitoring pods..."
	kubectl wait --for=condition=ready pod -l app=prometheus -n mlops --timeout=120s || true
	kubectl wait --for=condition=ready pod -l app=kube-state-metrics -n mlops --timeout=120s || true
	kubectl wait --for=condition=ready pod -l app=node-exporter -n mlops --timeout=120s || true
	kubectl wait --for=condition=ready pod -l app=alertmanager -n mlops --timeout=120s || true
	kubectl wait --for=condition=ready pod -l app=grafana -n mlops --timeout=120s || true
	@echo ""
	@echo "========================================="
	@echo "✅ Monitoring Stack Deployed!"
	@echo "========================================="
	@echo ""
	@echo "📊 Prometheus:    http://localhost:9090"
	@echo "🔔 AlertManager:  http://localhost:9093"
	@echo "📈 Grafana:       http://localhost:3000"
	@echo ""
	@echo "🔑 Grafana Login: admin / admin123"
	@echo ""
	@echo "⚠️  IMPORTANT: Configure Gmail in AlertManager!"
	@echo "   Edit deploy/k8s/alertmanager.yaml with your credentials"
	@echo ""
	kubectl get pods -n mlops

# Check monitoring status
monitoring-status:
	@echo "=== 📊 Monitoring Pods ==="
	kubectl get pods -n mlops -l 'app in (prometheus,grafana,alertmanager,kube-state-metrics,node-exporter)'
	@echo ""
	@echo "=== 🌐 Monitoring Services ==="
	kubectl get svc -n mlops | grep -E "prometheus|grafana|alertmanager|kube-state|node-exporter"
	@echo ""
	@echo "=== 🔔 Active Alerts ==="
	curl -s http://localhost:9090/api/v1/alerts 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Firing: {len([a for a in d.get(\"data\",{}).get(\"alerts\",[]) if a.get(\"state\")==\"firing\"])}') if d.get('status')=='success' else print('Prometheus not accessible')" || echo "Cannot connect to Prometheus"

# Stop monitoring stack (Prometheus, Grafana, AlertManager, etc.)
monitoring-stop:
	@echo "========================================="
	@echo "🛑 Stopping Monitoring Stack"
	@echo "========================================="
	@echo ""
	@echo "1️⃣  Stopping AlertManager..."
	kubectl delete -f deploy/k8s/alertmanager.yaml --ignore-not-found
	@echo "2️⃣  Stopping Grafana..."
	kubectl delete -f deploy/k8s/grafana.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/grafana-dashboard.yaml --ignore-not-found
	@echo "3️⃣  Stopping Prometheus..."
	kubectl delete -f deploy/k8s/prometheus.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/prometheus-alerts.yaml --ignore-not-found
	@echo "4️⃣  Stopping Node Exporter..."
	kubectl delete -f deploy/k8s/node-exporter.yaml --ignore-not-found
	@echo "5️⃣  Stopping Kube State Metrics..."
	kubectl delete -f deploy/k8s/kube-state-metrics.yaml --ignore-not-found
	@echo ""
	@echo "✅ Monitoring stack stopped!"

# Stop application (API deployment)
app-stop:
	@echo "========================================="
	@echo "🛑 Stopping Application"
	@echo "========================================="
	kubectl delete -f deploy/k8s/hpa.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/deployment.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/service.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/configmap.yaml --ignore-not-found
	@echo ""
	@echo "✅ Application stopped!"

# Stop everything (monitoring + app) but keep cluster
all-stop: monitoring-stop app-stop
	@echo ""
	@echo "========================================="
	@echo "✅ All Services Stopped!"
	@echo "========================================="
	@echo ""
	@echo "💡 Cluster is still running. To delete cluster:"
	@echo "   make kind-delete"

# View Prometheus logs
prometheus-logs:
	kubectl logs -l app=prometheus -n mlops -f --tail=50

# View Grafana logs
grafana-logs:
	kubectl logs -l app=grafana -n mlops -f --tail=50

# View AlertManager logs
alertmanager-logs:
	kubectl logs -l app=alertmanager -n mlops -f --tail=50

# View Node Exporter logs
node-exporter-logs:
	kubectl logs -l app=node-exporter -n mlops -f --tail=50

# View Kube State Metrics logs
kube-state-metrics-logs:
	kubectl logs -l app=kube-state-metrics -n mlops -f --tail=50

# Check alert rules
alerts-status:
	@echo "=== 🔔 Prometheus Alert Rules ==="
	curl -s http://localhost:9090/api/v1/rules 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'  - {r[\"name\"]}') for g in d.get('data',{}).get('groups',[]) for r in g.get('rules',[])]" || echo "Cannot connect to Prometheus"
	@echo ""
	@echo "=== 🚨 Firing Alerts ==="
	curl -s http://localhost:9093/api/v2/alerts 2>/dev/null | python3 -c "import sys,json; alerts=json.load(sys.stdin); [print(f'  🔴 {a[\"labels\"][\"alertname\"]} ({a[\"labels\"].get(\"severity\",\"unknown\")})') for a in alerts] if alerts else print('  ✅ No alerts firing')" || echo "Cannot connect to AlertManager"

# Test alerts - reload rules and check if TestAlert fires
alerts-test:
	@echo "========================================="
	@echo "🧪 Testing Alert Pipeline"
	@echo "========================================="
	@echo ""
	@echo "1️⃣  Reloading Prometheus alert rules..."
	kubectl delete configmap prometheus-alerts -n mlops --ignore-not-found
	kubectl apply -f deploy/k8s/prometheus-alerts.yaml
	@echo ""
	@echo "2️⃣  Restarting Prometheus..."
	kubectl rollout restart deployment prometheus -n mlops
	@echo ""
	@echo "3️⃣  Waiting for Prometheus to be ready..."
	kubectl wait --for=condition=ready pod -l app=prometheus -n mlops --timeout=120s
	@echo ""
	@echo "4️⃣  Waiting 30 seconds for TestAlert to fire..."
	sleep 30
	@echo ""
	@echo "5️⃣  Checking Prometheus alerts..."
	@curl -s http://localhost:9090/api/v1/alerts 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); alerts=d.get('data',{}).get('alerts',[]); [print(f'  {a[\"state\"].upper()}: {a[\"labels\"][\"alertname\"]} ({a[\"labels\"].get(\"severity\",\"unknown\")})') for a in alerts] if alerts else print('  No alerts found')" || echo "  Cannot connect to Prometheus"
	@echo ""
	@echo "6️⃣  Checking AlertManager..."
	@curl -s http://localhost:9093/api/v2/alerts 2>/dev/null | python3 -c "import sys,json; alerts=json.load(sys.stdin); [print(f'  🔔 {a[\"labels\"][\"alertname\"]}: {a[\"status\"][\"state\"]}') for a in alerts] if alerts else print('  ✅ No alerts in AlertManager')" || echo "  Cannot connect to AlertManager (port 9093 may not be mapped)"
	@echo ""
	@echo "========================================="
	@echo "✅ Alert test complete!"
	@echo "========================================="
	@echo ""
	@echo "📊 View in Prometheus: http://localhost:9090/alerts"
	@echo "🔔 View in AlertManager: http://localhost:9093"
	@echo ""

# Delete monitoring stack
monitoring-delete:
	kubectl delete -f deploy/k8s/grafana.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/grafana-dashboard.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/alertmanager.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/node-exporter.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/kube-state-metrics.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/prometheus-alerts.yaml --ignore-not-found
	kubectl delete -f deploy/k8s/prometheus.yaml --ignore-not-found
	@echo "✅ Monitoring stack deleted"

# Full stack: API + Monitoring
kind-full: kind-up monitoring-deploy
	@echo ""
	@echo "========================================="
	@echo "✅ Full MLOps Stack Running!"
	@echo "========================================="
	@echo ""
	@echo "🌐 API:          http://localhost:8000"
	@echo "📊 Prometheus:   http://localhost:9090"
	@echo "🔔 AlertManager: http://localhost:9093"
	@echo "📈 Grafana:      http://localhost:3000"
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
	mlflow ui --backend-store-uri sqlite:///mlflow.db --host 0.0.0.0 --port 5050

# Cleanup
clean:
	rm -rf __pycache__ .pytest_cache htmlcov .coverage
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

# =========================================
# Submission
# =========================================

# Create submission ZIP file
submission-zip:
	@echo "========================================="
	@echo "📦 Creating Submission ZIP File"
	@echo "========================================="
	@echo ""
	@echo "1️⃣  Cleaning up temporary files..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@rm -f mlops-assignment2-submission.zip 2>/dev/null || true
	@echo ""
	@echo "2️⃣  Creating ZIP file (excluding large/unnecessary files)..."
	@zip -r mlops-assignment2-submission.zip . \
		-x "*.git*" \
		-x "*venv/*" \
		-x "*__pycache__/*" \
		-x "*.pyc" \
		-x "*mlruns/*" \
		-x "*data/raw/*" \
		-x "*.DS_Store" \
		-x "*node_modules/*" \
		-x "*.zip" \
		-x "*/.venv/*"
	@echo ""
	@echo "========================================="
	@echo "✅ Submission ZIP created!"
	@echo "========================================="
	@echo ""
	@ls -lh mlops-assignment2-submission.zip
	@echo ""
	@echo "📁 Contents summary:"
	@unzip -l mlops-assignment2-submission.zip | tail -1
	@echo ""
	@echo "📧 Submit this file along with your screen recording."

