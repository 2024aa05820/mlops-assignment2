"""
FastAPI application for Cats vs Dogs classification API.
M2: Model Packaging & Containerization
"""

import os
import time
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response

from src.models.predict import CatsDogsPredictor

# Initialize FastAPI app
app = FastAPI(
    title="Cats vs Dogs Classification API",
    description="MLOps Assignment 2 - Binary image classification API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Prometheus metrics
PREDICTIONS_TOTAL = Counter(
    'predictions_total', 
    'Total number of predictions',
    ['predicted_class']
)
PREDICTION_LATENCY = Histogram(
    'prediction_latency_seconds',
    'Prediction latency in seconds'
)
PREDICTION_ERRORS = Counter(
    'prediction_errors_total',
    'Total number of prediction errors'
)

# Global predictor (lazy loaded)
predictor: Optional[CatsDogsPredictor] = None

# Response models
class PredictionResponse(BaseModel):
    prediction: str
    probability: float
    confidence: float
    probabilities: dict
    inference_time_ms: float

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    timestamp: str
    version: str

class ReadinessResponse(BaseModel):
    ready: bool
    model_path: str
    device: str


@app.on_event("startup")
async def startup_event():
    """Load model on startup."""
    global predictor
    model_path = os.getenv("MODEL_PATH", "models/best_model.pt")
    try:
        predictor = CatsDogsPredictor(model_path=model_path)
        print(f"✅ Model loaded successfully from {model_path}")
    except Exception as e:
        print(f"⚠️ Failed to load model: {e}")
        predictor = None


@app.get("/", tags=["Root"])
async def root():
    """Root endpoint with API info."""
    return {
        "message": "Cats vs Dogs Classification API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
        "predict": "/predict"
    }


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """Health check endpoint for Kubernetes liveness probe."""
    return HealthResponse(
        status="healthy",
        model_loaded=predictor is not None and predictor.is_ready(),
        timestamp=datetime.utcnow().isoformat(),
        version="1.0.0"
    )


@app.get("/ready", response_model=ReadinessResponse, tags=["Health"])
async def readiness_check():
    """Readiness check endpoint for Kubernetes readiness probe."""
    if predictor is None or not predictor.is_ready():
        raise HTTPException(status_code=503, detail="Model not ready")
    
    return ReadinessResponse(
        ready=True,
        model_path=predictor.model_path,
        device=str(predictor.device)
    )


@app.get("/metrics", tags=["Monitoring"])
async def metrics():
    """Prometheus metrics endpoint."""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )


@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
async def predict(file: UploadFile = File(...)):
    """
    Predict whether an image contains a cat or dog.
    
    - **file**: Image file (JPEG, PNG, etc.)
    
    Returns prediction with confidence scores.
    """
    if predictor is None or not predictor.is_ready():
        PREDICTION_ERRORS.inc()
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    # Validate file type
    if not file.content_type.startswith("image/"):
        PREDICTION_ERRORS.inc()
        raise HTTPException(status_code=400, detail="File must be an image")
    
    try:
        # Read image bytes
        start_time = time.time()
        image_bytes = await file.read()
        
        # Make prediction
        with PREDICTION_LATENCY.time():
            result = predictor.predict_from_bytes(image_bytes)
        
        inference_time = (time.time() - start_time) * 1000  # Convert to ms
        
        # Update metrics
        PREDICTIONS_TOTAL.labels(predicted_class=result["prediction"]).inc()
        
        return PredictionResponse(
            prediction=result["prediction"],
            probability=result["probability"],
            confidence=result["confidence"],
            probabilities=result["probabilities"],
            inference_time_ms=round(inference_time, 2)
        )
    
    except Exception as e:
        PREDICTION_ERRORS.inc()
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

