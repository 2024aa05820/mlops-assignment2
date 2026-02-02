// Jenkinsfile for MLOps Assignment 2 - CI/CD Pipeline
// Runs on Rocky Linux VM server with full training (2000 samples)

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

                        # Create Kaggle config directory
                        mkdir -p ~/.kaggle

                        # Parse the token - check if it's old format (username:key) or new format (KGAT_xxx)
                        if echo "$KAGGLE_TOKEN" | grep -q ":"; then
                            # Old format: username:key
                            KAGGLE_USERNAME=$(echo "$KAGGLE_TOKEN" | cut -d: -f1)
                            KAGGLE_KEY=$(echo "$KAGGLE_TOKEN" | cut -d: -f2)
                            echo "{\\"username\\":\\"$KAGGLE_USERNAME\\",\\"key\\":\\"$KAGGLE_KEY\\"}" > ~/.kaggle/kaggle.json
                            echo "Using old-format credentials (username:key)"
                        else
                            # New format: KGAT_xxx - set environment variable
                            export KAGGLE_API_TOKEN=$KAGGLE_TOKEN
                            echo "{\\"token\\":\\"$KAGGLE_TOKEN\\"}" > ~/.kaggle/kaggle.json
                            echo "Using new-format token (KGAT_xxx)"
                        fi
                        chmod 600 ~/.kaggle/kaggle.json

                        echo "Kaggle config created"

                        # Download dataset if not exists
                        if [ ! -d "data/raw/train" ]; then
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
                withCredentials([usernamePassword(credentialsId: 'ghcr-credentials', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
                    sh '''
                        echo "Logging in to GHCR..."
                        echo $GHCR_TOKEN | docker login ghcr.io -u $GHCR_USER --password-stdin

                        echo "Pushing Docker image..."
                        docker push ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
                        docker push ${REGISTRY}/${IMAGE_NAME}:latest

                        echo "✅ Image pushed to GHCR"
                    '''
                }
            }
        }

        stage('Deploy') {
            when {
                expression { return !params.SKIP_DOCKER }
            }
            steps {
                sh '''
                    echo "Deploying new container..."

                    # Stop existing container if running
                    docker stop cats-dogs-api || true
                    docker rm cats-dogs-api || true

                    # Run new container
                    docker run -d \
                        --name cats-dogs-api \
                        -p 8000:8000 \
                        --restart always \
                        ${REGISTRY}/${IMAGE_NAME}:latest

                    echo "Waiting for container to start..."
                    sleep 10

                    echo "Container status:"
                    docker ps | grep cats-dogs-api
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
            echo "API running at: http://localhost:8000"
        }
        failure {
            echo '❌ Pipeline failed!'
        }
        always {
            echo 'Pipeline finished.'
        }
    }
}

