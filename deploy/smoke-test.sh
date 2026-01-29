#!/bin/bash
# Smoke Tests for Cats vs Dogs API
# M4: CD Pipeline & Deployment

set -e

API_URL="${API_URL:-http://localhost:8000}"
MAX_RETRIES=30
RETRY_INTERVAL=2

echo "========================================="
echo "  Smoke Tests - Cats vs Dogs API"
echo "  API URL: ${API_URL}"
echo "========================================="

# Wait for API to be ready
echo ""
echo "Waiting for API to be ready..."
for i in $(seq 1 $MAX_RETRIES); do
    if curl -s "${API_URL}/health" > /dev/null 2>&1; then
        echo "✅ API is ready!"
        break
    fi
    if [ $i -eq $MAX_RETRIES ]; then
        echo "❌ API failed to start after ${MAX_RETRIES} attempts"
        exit 1
    fi
    echo "  Attempt $i/$MAX_RETRIES - waiting..."
    sleep $RETRY_INTERVAL
done

# Test 1: Health Check
echo ""
echo "Test 1: Health Check (/health)"
HEALTH=$(curl -s "${API_URL}/health")
echo "Response: ${HEALTH}"
if echo "$HEALTH" | grep -q "healthy"; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# Test 2: Readiness Check
echo ""
echo "Test 2: Readiness Check (/ready)"
READY=$(curl -s "${API_URL}/ready")
echo "Response: ${READY}"
if echo "$READY" | grep -q "ready"; then
    echo "✅ Readiness check passed"
else
    echo "❌ Readiness check failed"
    exit 1
fi

# Test 3: API Info
echo ""
echo "Test 3: API Info (/)"
INFO=$(curl -s "${API_URL}/")
echo "Response: ${INFO}"
if echo "$INFO" | grep -q "Cats vs Dogs"; then
    echo "✅ API info check passed"
else
    echo "❌ API info check failed"
    exit 1
fi

# Test 4: Metrics Endpoint
echo ""
echo "Test 4: Metrics Endpoint (/metrics)"
METRICS=$(curl -s "${API_URL}/metrics")
if echo "$METRICS" | grep -q "predictions_total"; then
    echo "✅ Metrics endpoint passed"
else
    echo "⚠️  Metrics endpoint returned unexpected format (non-critical)"
fi

# Test 5: Prediction with test image (if available)
echo ""
echo "Test 5: Prediction Endpoint (/predict)"

# Create a simple test image
python3 -c "
from PIL import Image
import io

# Create a simple test image
img = Image.new('RGB', (224, 224), color='blue')
img.save('test_image.jpg', 'JPEG')
print('Test image created: test_image.jpg')
" 2>/dev/null || echo "Could not create test image with Python"

if [ -f "test_image.jpg" ]; then
    PREDICT=$(curl -s -X POST "${API_URL}/predict" -F "file=@test_image.jpg")
    echo "Response: ${PREDICT}"
    if echo "$PREDICT" | grep -q "prediction"; then
        echo "✅ Prediction endpoint passed"
    else
        echo "❌ Prediction endpoint failed"
        exit 1
    fi
    rm -f test_image.jpg
else
    echo "⚠️  Skipping prediction test (no test image)"
fi

echo ""
echo "========================================="
echo "  ✅ ALL SMOKE TESTS PASSED!"
echo "========================================="
echo ""
echo "API is healthy and ready to serve predictions."
echo "Access the API documentation at: ${API_URL}/docs"

