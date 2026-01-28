"""
Unit tests for the CNN model.
M3: CI Pipeline - Model Tests
"""

import pytest
import torch
import os
import sys

# Add src to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.models.cnn import SimpleCNN, count_parameters


class TestSimpleCNN:
    """Tests for SimpleCNN model architecture."""

    def test_model_creation(self):
        """Test model can be created with default parameters."""
        model = SimpleCNN()
        assert model is not None

    def test_model_forward_pass(self):
        """Test model forward pass with correct input shape."""
        model = SimpleCNN(num_classes=2)
        model.eval()
        
        # Create dummy input (batch_size=1, channels=3, height=224, width=224)
        x = torch.randn(1, 3, 224, 224)
        
        with torch.no_grad():
            output = model(x)
        
        # Output should be (batch_size, num_classes)
        assert output.shape == (1, 2)

    def test_model_batch_forward(self):
        """Test model with batch of images."""
        model = SimpleCNN(num_classes=2)
        model.eval()
        
        # Batch of 4 images
        x = torch.randn(4, 3, 224, 224)
        
        with torch.no_grad():
            output = model(x)
        
        assert output.shape == (4, 2)

    def test_model_output_probabilities(self):
        """Test that softmax output sums to 1."""
        model = SimpleCNN(num_classes=2)
        model.eval()
        
        x = torch.randn(1, 3, 224, 224)
        
        with torch.no_grad():
            output = model(x)
            probs = torch.softmax(output, dim=1)
        
        # Probabilities should sum to 1
        assert torch.allclose(probs.sum(dim=1), torch.tensor([1.0]), atol=1e-5)

    def test_count_parameters(self):
        """Test parameter counting function."""
        model = SimpleCNN(num_classes=2)
        params = count_parameters(model)
        
        # Model should have parameters
        assert params > 0
        # SimpleCNN should have around 400K-500K parameters
        assert 300000 < params < 600000

    def test_model_with_different_num_classes(self):
        """Test model with different number of output classes."""
        for num_classes in [2, 5, 10]:
            model = SimpleCNN(num_classes=num_classes)
            x = torch.randn(1, 3, 224, 224)
            
            with torch.no_grad():
                output = model(x)
            
            assert output.shape == (1, num_classes)

    def test_model_dropout(self):
        """Test model with different dropout values."""
        model = SimpleCNN(num_classes=2, dropout=0.3)
        assert model is not None
        
        model = SimpleCNN(num_classes=2, dropout=0.7)
        assert model is not None


class TestModelCheckpoint:
    """Tests for saved model checkpoint."""

    @pytest.fixture
    def model_path(self):
        return "models/best_model.pt"

    def test_model_file_exists(self, model_path):
        """Test that model file exists."""
        assert os.path.exists(model_path), f"Model file not found at {model_path}"

    def test_model_can_be_loaded(self, model_path):
        """Test that model checkpoint can be loaded."""
        if not os.path.exists(model_path):
            pytest.skip("Model file not found")
        
        checkpoint = torch.load(model_path, map_location='cpu')
        
        assert 'model_state_dict' in checkpoint
        assert 'config' in checkpoint

    def test_model_state_dict_valid(self, model_path):
        """Test that model state dict can be loaded into model."""
        if not os.path.exists(model_path):
            pytest.skip("Model file not found")
        
        checkpoint = torch.load(model_path, map_location='cpu')
        
        model = SimpleCNN(num_classes=2)
        model.load_state_dict(checkpoint['model_state_dict'])
        
        # Model should work after loading
        x = torch.randn(1, 3, 224, 224)
        with torch.no_grad():
            output = model(x)
        
        assert output.shape == (1, 2)

