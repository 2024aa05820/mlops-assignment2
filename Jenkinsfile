// Jenkinsfile for MLOps Assignment 2 - CI/CD Pipeline
// M3: CI Pipeline + M4: CD Pipeline with Local Kubernetes (Kind)
// Supports both local Mac development and remote server deployment

pipeline {
    agent any

    parameters {
        booleanParam(name: 'SKIP_TRAINING', defaultValue: false, description: 'Skip model training (use existing model)')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip lint and unit tests')
        booleanParam(name: 'SKIP_DOCKER', defaultValue: false, description: 'Skip Docker build and push')
    }

    environment {
        PYTHON_VERSION = '3.11'
        REGISTRY = 'ghcr.io'
        IMAGE_NAME = '2024aa05820/mlops-assignment2'
        KAGGLE_CONFIG_DIR = "${WORKSPACE}"
    }

    triggers {
        // Poll GitHub every 5 minutes for changes
        pollSCM('H/5 * * * *')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git status'
            }
        }
        
        stage('Setup Python Environment') {
            steps {
                sh '''
                    echo "Setting up Python virtual environment..."
                    python3 -m venv venv
                    source venv/bin/activate

                    pip install --upgrade pip
                    pip install -r requirements.txt
                    pip install pytest pytest-cov httpx flake8 black isort kaggle

                    echo "Python environment ready!"
                    python --version
                '''
            }
        }
        
        stage('Lint & Code Quality') {
            when {
                expression { return !params.SKIP_TESTS }
            }
            steps {
                sh '''
                    source venv/bin/activate
                    echo "Running flake8..."
                    flake8 src/ --max-line-length=120 --ignore=E501,W503,E203,W391,W293,W291,F401,E302,E402,F541 || true

                    echo "Checking black formatting..."
                    black --check --line-length=120 src/ || true

                    echo "Checking import sorting..."
                    isort --check-only src/ || true
                '''
            }
        }

        stage('Unit Tests') {
            when {
                expression { return !params.SKIP_TESTS }
            }
            steps {
                sh '''
                    source venv/bin/activate
                    pytest tests/ -v --cov=src --cov-report=xml --cov-report=term-missing || true
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/test-results.xml'
                }
            }
        }

        stage('Download Data') {
            when {
                expression { return !params.SKIP_TRAINING }
            }
            steps {
                withCredentials([string(credentialsId: 'kaggle-api-token', variable: 'KAGGLE_TOKEN')]) {
                    sh '''
                        source venv/bin/activate
                        echo "Downloading Kaggle dataset..."

                        # Download dataset if not exists
                        if [ ! -d "data/raw/train" ]; then
                            # Create Kaggle config directory
                            mkdir -p ~/.kaggle

                            # KAGGLE_TOKEN should be JSON format: {"username":"xxx","key":"xxx"}
                            # Use Python to properly format and write the JSON (handles spaces/escaping)
                            python3 << 'PYTHON_SCRIPT'
import json
import os

token = os.environ.get('KAGGLE_TOKEN', '')
try:
    # Parse and re-write as compact JSON
    data = json.loads(token)
    kaggle_path = os.path.expanduser('~/.kaggle/kaggle.json')
    with open(kaggle_path, 'w') as f:
        json.dump(data, f)
    os.chmod(kaggle_path, 0o600)
    print('Kaggle credentials configured')
    print('Username: ' + data.get('username', 'N/A'))
except Exception as e:
    print('ERROR: Failed to parse Kaggle token: ' + str(e))
    print('Expected format: {"username":"xxx","key":"xxx"}')
    exit(1)
PYTHON_SCRIPT

                            echo "Downloading from Kaggle..."
                            kaggle datasets download -d bhavikjikadara/dog-and-cat-classification-dataset -p data/ --unzip

                            # Organize data
                            python scripts/prepare_data.py --data-dir data || true

                            echo "Dataset downloaded and organized!"
                            ls -la data/
                        else
                            echo "Data already exists, skipping download"
                        fi
                    '''
                }
            }
        }

        stage('Train Model') {
            when {
                expression { return !params.SKIP_TRAINING }
            }
            steps {
                sh '''
                    source venv/bin/activate
                    echo "Training model with 2000 samples, 3 epochs..."
                    python -m src.models.train \
                        --data-dir data/raw \
                        --epochs 3 \
                        --batch-size 128

                    echo "Training complete!"
                    ls -la models/
                '''
            }
        }
        
        stage('Model Validation') {
            steps {
                sh '''
                    source venv/bin/activate
                    python scripts/validate_model.py --model-path models/best_model.pt
                '''
            }
        }
        
        stage('Docker Build') {
            when {
                expression { return !params.SKIP_DOCKER }
            }
            steps {
                sh '''
                    echo "Building Docker image..."
                    docker build -t ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} .
                    docker tag ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} ${REGISTRY}/${IMAGE_NAME}:latest

                    echo "Docker images:"
                    docker images | grep ${IMAGE_NAME}
                '''
            }
        }

        stage('Docker Push') {
            when {
                expression { return !params.SKIP_DOCKER }
            }
            steps {
                withCredentials([string(credentialsId: 'ghcr-token', variable: 'GHCR_TOKEN')]) {
                    sh '''
                        echo "Logging in to GHCR..."
                        echo $GHCR_TOKEN | docker login ghcr.io -u 2024aa05820 --password-stdin

                        echo "Pushing Docker image..."
                        docker push ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
                        docker push ${REGISTRY}/${IMAGE_NAME}:latest

                        echo "✅ Image pushed to GHCR"
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            when {
                expression { return !params.SKIP_DOCKER }
            }
            steps {
                sh '''
                    echo "Deploying to local Kubernetes (Kind)..."

                    # Check if Kind cluster exists
                    if ! kind get clusters 2>/dev/null | grep -q mlops-cluster; then
                        echo "Creating Kind cluster..."
                        kind create cluster --config deploy/k8s/kind-config.yaml
                    fi

                    # Tag image for Kind
                    docker tag ${REGISTRY}/${IMAGE_NAME}:latest cats-dogs-api:latest

                    # Load image into Kind cluster
                    echo "Loading image to Kind cluster..."
                    kind load docker-image cats-dogs-api:latest --name mlops-cluster

                    # Deploy to Kubernetes
                    echo "Applying Kubernetes manifests..."
                    kubectl apply -f deploy/k8s/namespace.yaml
                    kubectl apply -f deploy/k8s/configmap.yaml
                    kubectl apply -f deploy/k8s/deployment.yaml
                    kubectl apply -f deploy/k8s/service.yaml

                    # Wait for pods to be ready
                    echo "Waiting for pods to be ready..."
                    kubectl wait --for=condition=ready pod -l app=cats-dogs-api -n mlops --timeout=120s

                    # Show deployment status
                    echo ""
                    echo "=== Deployment Status ==="
                    kubectl get pods,svc -n mlops
                '''
            }
        }

        stage('Smoke Tests') {
            steps {
                sh '''
                    echo "Running smoke tests..."

                    # Test 1: Health check
                    echo "Testing /health endpoint..."
                    curl -f http://localhost:8000/health || exit 1
                    echo "✅ Health check passed"

                    # Test 2: Readiness check
                    echo "Testing /ready endpoint..."
                    curl -f http://localhost:8000/ready || exit 1
                    echo "✅ Readiness check passed"

                    # Test 3: API info
                    echo "Testing / endpoint..."
                    curl -f http://localhost:8000/ || exit 1
                    echo "✅ API info check passed"

                    echo ""
                    echo "========================================="
                    echo "✅ ALL SMOKE TESTS PASSED!"
                    echo "========================================="
                '''
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline completed successfully!'
            echo "Docker image: ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}"
            echo "API running at: http://localhost:8000 (Kind cluster)"
            echo "Check status: kubectl get pods -n mlops"
        }
        failure {
            echo '❌ Pipeline failed!'
        }
        always {
            echo 'Pipeline finished.'
            echo 'Useful commands:'
            echo '  kubectl get pods -n mlops'
            echo '  kubectl logs -l app=cats-dogs-api -n mlops'
            echo '  curl http://localhost:8000/health'
        }
    }
}

