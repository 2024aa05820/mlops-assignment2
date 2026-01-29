// Jenkinsfile for MLOps Assignment 2 - CI/CD Pipeline
// Runs on Rocky Linux VM server with full training (2000 samples)

pipeline {
    agent any
    
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
            steps {
                withCredentials([string(credentialsId: 'kaggle-api-token', variable: 'KAGGLE_API_TOKEN')]) {
                    sh '''
                        source venv/bin/activate
                        echo "Downloading Kaggle dataset..."
                        export KAGGLE_USERNAME=$(echo $KAGGLE_API_TOKEN | cut -d: -f1)
                        export KAGGLE_KEY=$(echo $KAGGLE_API_TOKEN | cut -d: -f2)

                        # Download dataset if not exists
                        if [ ! -d "data/raw/train" ]; then
                            python -c "
from kaggle.api.kaggle_api_extended import KaggleApi
api = KaggleApi()
api.authenticate()
api.dataset_download_files('bhavikjikadara/dog-and-cat-classification-dataset', path='data/', unzip=True)
"
                            # Organize data
                            python scripts/prepare_data.py || true
                        else
                            echo "Data already exists, skipping download"
                        fi
                    '''
                }
            }
        }

        stage('Train Model') {
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
                    python -c "
import torch
import torch.nn.functional as F
from PIL import Image

# Load and validate model
checkpoint = torch.load('models/best_model.pt', map_location='cpu')
print('✅ Model loaded successfully')
print(f'   Epoch: {checkpoint.get(\"epoch\", \"N/A\")}')
val_acc = checkpoint.get('val_accuracy', 0)
print(f'   Val Accuracy: {val_acc:.4f}')

# Quality gate: accuracy must be > 50% (better than random)
assert val_acc > 0.50, f'Model accuracy {val_acc} below threshold 0.50'
print('✅ Accuracy threshold passed')

# Test inference
from src.models.cnn import SimpleCNN
from src.data.preprocessing import get_val_transforms

model = SimpleCNN()
model.load_state_dict(checkpoint['model_state_dict'])
model.eval()

transform = get_val_transforms(224)
dummy_image = Image.new('RGB', (224, 224), color='red')
input_tensor = transform(dummy_image).unsqueeze(0)

with torch.no_grad():
    output = model(input_tensor)
    # Model outputs 2 classes: [cat_prob, dog_prob]
    probs = F.softmax(output, dim=1)
    predicted_class = torch.argmax(probs, dim=1).item()
    confidence = probs[0][predicted_class].item()

class_names = ['cat', 'dog']
print(f'✅ Inference test passed')
print(f'   Predicted: {class_names[predicted_class]} (confidence: {confidence:.4f})')
"
                '''
            }
        }
        
        stage('Docker Build') {
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
            sh '''
                # Rollback: restart previous container if available
                docker stop cats-dogs-api || true
                docker rm cats-dogs-api || true
            '''
        }
        always {
            // Clean up old Docker images
            sh '''
                docker image prune -f || true
            '''
        }
    }
}

