#!/usr/bin/env python3
"""
Model validation script for CI/CD pipeline.
Validates trained model meets quality gates before deployment.
"""

import sys
import os

# Add project root to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import torch
import torch.nn.functional as F
from PIL import Image

def validate_model(model_path: str = "models/best_model.pt"):
    """Validate the trained model."""
    
    print("=" * 50)
    print("MODEL VALIDATION")
    print("=" * 50)
    
    # Load and validate model
    try:
        checkpoint = torch.load(model_path, map_location='cpu')
        print('✅ Model loaded successfully')
    except Exception as e:
        print(f'❌ Failed to load model: {e}')
        sys.exit(1)
    
    # Check metadata
    epoch = checkpoint.get('epoch', 'N/A')
    val_acc = checkpoint.get('val_accuracy', 0)
    print(f'   Epoch: {epoch}')
    print(f'   Val Accuracy: {val_acc:.4f}')
    
    # Quality gate: accuracy must be > 50% (better than random)
    if val_acc <= 0.50:
        print(f'❌ Model accuracy {val_acc:.4f} below threshold 0.50')
        sys.exit(1)
    print('✅ Accuracy threshold passed')
    
    # Test inference
    try:
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
        print('✅ Inference test passed')
        print(f'   Predicted: {class_names[predicted_class]} (confidence: {confidence:.4f})')
        
    except Exception as e:
        print(f'❌ Inference test failed: {e}')
        sys.exit(1)
    
    print("=" * 50)
    print("✅ ALL VALIDATION CHECKS PASSED")
    print("=" * 50)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description='Validate trained model')
    parser.add_argument('--model-path', default='models/best_model.pt', help='Path to model checkpoint')
    args = parser.parse_args()
    
    validate_model(args.model_path)

