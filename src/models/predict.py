"""
Prediction/inference module for Cats vs Dogs classification.
"""

import os
from pathlib import Path
from typing import Dict, Any, Optional, Tuple

import torch
import torch.nn.functional as F
from PIL import Image

from .cnn import SimpleCNN
from ..data.preprocessing import preprocess_image_bytes, get_val_transforms


class CatsDogsPredictor:
    """
    Predictor class for Cats vs Dogs classification.
    
    Handles model loading and inference for both file and byte inputs.
    """
    
    CLASSES = ['cat', 'dog']
    
    def __init__(
        self,
        model_path: str = "models/best_model.pt",
        device: Optional[str] = None
    ):
        """
        Initialize the predictor.
        
        Args:
            model_path: Path to the saved model checkpoint
            device: Device to use for inference ('cpu', 'cuda', or None for auto)
        """
        self.model_path = model_path
        self.device = torch.device(
            device if device else ('cuda' if torch.cuda.is_available() else 'cpu')
        )
        self.model = None
        self.config = None
        self._load_model()
    
    def _load_model(self):
        """Load the model from checkpoint."""
        if not os.path.exists(self.model_path):
            raise FileNotFoundError(f"Model not found at {self.model_path}")
        
        checkpoint = torch.load(self.model_path, map_location=self.device)
        self.config = checkpoint.get('config', {})
        
        # Get model config
        model_config = self.config.get('model', {})
        num_classes = model_config.get('num_classes', 2)
        dropout = model_config.get('dropout', 0.5)
        
        # Create and load model
        self.model = SimpleCNN(num_classes=num_classes, dropout=dropout)
        self.model.load_state_dict(checkpoint['model_state_dict'])
        self.model.to(self.device)
        self.model.eval()
        
        print(f"Model loaded from {self.model_path} on {self.device}")
    
    def predict_from_bytes(self, image_bytes: bytes) -> Dict[str, Any]:
        """
        Make prediction from image bytes.
        
        Args:
            image_bytes: Raw image bytes
            
        Returns:
            Dictionary with prediction, probability, and confidence
        """
        # Get image size from config
        image_size = self.config.get('data', {}).get('image_size', 224)
        
        # Preprocess image
        image_tensor = preprocess_image_bytes(image_bytes, image_size)
        image_tensor = image_tensor.unsqueeze(0).to(self.device)
        
        return self._predict(image_tensor)
    
    def predict_from_file(self, image_path: str) -> Dict[str, Any]:
        """
        Make prediction from image file path.
        
        Args:
            image_path: Path to the image file
            
        Returns:
            Dictionary with prediction, probability, and confidence
        """
        image_size = self.config.get('data', {}).get('image_size', 224)
        
        # Load and preprocess image
        image = Image.open(image_path).convert('RGB')
        transform = get_val_transforms(image_size)
        image_tensor = transform(image).unsqueeze(0).to(self.device)
        
        return self._predict(image_tensor)
    
    def _predict(self, image_tensor: torch.Tensor) -> Dict[str, Any]:
        """
        Make prediction from preprocessed tensor.
        
        Args:
            image_tensor: Preprocessed image tensor
            
        Returns:
            Dictionary with prediction results
        """
        with torch.no_grad():
            logits = self.model(image_tensor)
            probabilities = F.softmax(logits, dim=1)
            
            # Get prediction
            predicted_idx = torch.argmax(probabilities, dim=1).item()
            predicted_class = self.CLASSES[predicted_idx]
            
            # Get probabilities for each class
            probs = probabilities[0].cpu().numpy()
            
            return {
                "prediction": predicted_class,
                "probability": float(probs[predicted_idx]),
                "confidence": float(probs[predicted_idx]),
                "probabilities": {
                    "cat": float(probs[0]),
                    "dog": float(probs[1])
                }
            }
    
    def is_ready(self) -> bool:
        """Check if the model is loaded and ready for predictions."""
        return self.model is not None


# Global predictor instance (lazy loaded)
_predictor: Optional[CatsDogsPredictor] = None


def get_predictor(model_path: str = "models/best_model.pt") -> CatsDogsPredictor:
    """Get or create a global predictor instance."""
    global _predictor
    if _predictor is None:
        _predictor = CatsDogsPredictor(model_path=model_path)
    return _predictor

