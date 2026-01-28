.PHONY: help init install clean-reinstall download dvc-init dvc-add dvc-push dvc-pull data-setup train serve test lint format docker-build docker-run deploy clean

# Default target
help:
	@echo "Cats vs Dogs MLOps Project"
	@echo ""
	@echo "Available commands:"
	@echo "  make init          - Create virtual environment and install dependencies"
	@echo "  make install       - Install dependencies only"
	@echo "  make clean-reinstall - Remove venv and reinstall from scratch"
	@echo "  make download      - Download dataset from Kaggle"
	@echo "  make dvc-init      - Initialize DVC"
	@echo "  make dvc-add       - Add data to DVC tracking"
	@echo "  make data-setup    - Full data setup (download + DVC init + add)"
	@echo "  make train         - Train the model"
	@echo "  make serve         - Start the API server"
	@echo "  make test          - Run tests"
	@echo "  make lint          - Run linter"
	@echo "  make format        - Format code"
	@echo "  make docker-build  - Build Docker image"
	@echo "  make docker-run    - Run Docker container"
	@echo "  make deploy        - Deploy to Kubernetes"
	@echo "  make mlflow-ui     - Start MLflow UI"
	@echo "  make clean         - Clean up generated files"

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

# Kubernetes
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

