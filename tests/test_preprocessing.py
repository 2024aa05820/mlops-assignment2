"""
Unit tests for data preprocessing functions.
M3: CI Pipeline - Data Preprocessing Tests
"""

import pytest
import torch
import numpy as np
import os
import sys
from PIL import Image
from io import BytesIO

# Add src to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.data.preprocessing import (
    get_train_transforms,
    get_val_transforms,
    preprocess_image_bytes,
    denormalize_image
)


class TestTransforms:
    """Tests for image transform functions."""

    def test_get_train_transforms_returns_compose(self):
        """Test that get_train_transforms returns a Compose object."""
        transform = get_train_transforms()
        assert transform is not None
        assert hasattr(transform, 'transforms')

    def test_get_val_transforms_returns_compose(self):
        """Test that get_val_transforms returns a Compose object."""
        transform = get_val_transforms()
        assert transform is not None
        assert hasattr(transform, 'transforms')

    def test_train_transforms_output_shape(self):
        """Test that train transforms produce correct output shape."""
        transform = get_train_transforms(image_size=224)
        
        # Create a dummy PIL image
        image = Image.new('RGB', (100, 150), color='red')
        
        output = transform(image)
        
        # Should be (C, H, W) = (3, 224, 224)
        assert output.shape == (3, 224, 224)
        assert isinstance(output, torch.Tensor)

    def test_val_transforms_output_shape(self):
        """Test that val transforms produce correct output shape."""
        transform = get_val_transforms(image_size=224)
        
        # Create a dummy PIL image
        image = Image.new('RGB', (100, 150), color='blue')
        
        output = transform(image)
        
        # Should be (C, H, W) = (3, 224, 224)
        assert output.shape == (3, 224, 224)
        assert isinstance(output, torch.Tensor)

    def test_transforms_with_different_sizes(self):
        """Test transforms with different image sizes."""
        for size in [128, 224, 256]:
            transform = get_val_transforms(image_size=size)
            image = Image.new('RGB', (100, 100), color='green')
            output = transform(image)
            
            assert output.shape == (3, size, size)

    def test_transforms_normalize_values(self):
        """Test that transforms normalize values correctly."""
        transform = get_val_transforms(image_size=224)
        
        # Create a white image (all 255)
        image = Image.new('RGB', (224, 224), color='white')
        output = transform(image)
        
        # After normalization, values should not be in [0, 255] range
        # ImageNet normalization: (x - mean) / std
        assert output.min() < 0 or output.max() > 1


class TestPreprocessImageBytes:
    """Tests for preprocess_image_bytes function."""

    def create_test_image_bytes(self, width=100, height=100, color='red'):
        """Helper to create test image bytes."""
        image = Image.new('RGB', (width, height), color=color)
        buffer = BytesIO()
        image.save(buffer, format='JPEG')
        return buffer.getvalue()

    def test_preprocess_image_bytes_output_shape(self):
        """Test that preprocess_image_bytes produces correct output shape."""
        image_bytes = self.create_test_image_bytes()
        
        output = preprocess_image_bytes(image_bytes, image_size=224)
        
        assert output.shape == (3, 224, 224)
        assert isinstance(output, torch.Tensor)

    def test_preprocess_image_bytes_different_sizes(self):
        """Test preprocessing with different target sizes."""
        image_bytes = self.create_test_image_bytes()
        
        for size in [128, 224, 256]:
            output = preprocess_image_bytes(image_bytes, image_size=size)
            assert output.shape == (3, size, size)

    def test_preprocess_image_bytes_different_input_sizes(self):
        """Test preprocessing handles different input image sizes."""
        for width, height in [(50, 50), (100, 200), (300, 150)]:
            image_bytes = self.create_test_image_bytes(width=width, height=height)
            output = preprocess_image_bytes(image_bytes, image_size=224)
            
            # Output should always be 224x224 regardless of input
            assert output.shape == (3, 224, 224)

    def test_preprocess_image_bytes_png_format(self):
        """Test preprocessing works with PNG format."""
        image = Image.new('RGB', (100, 100), color='blue')
        buffer = BytesIO()
        image.save(buffer, format='PNG')
        image_bytes = buffer.getvalue()
        
        output = preprocess_image_bytes(image_bytes, image_size=224)
        assert output.shape == (3, 224, 224)


class TestDenormalizeImage:
    """Tests for denormalize_image function."""

    def test_denormalize_output_type(self):
        """Test that denormalize returns numpy array."""
        # Create a normalized tensor
        tensor = torch.randn(3, 224, 224)
        
        output = denormalize_image(tensor)
        
        assert isinstance(output, np.ndarray)

    def test_denormalize_output_range(self):
        """Test that denormalized values are in valid range."""
        # Create a tensor with values in typical normalized range
        tensor = torch.zeros(3, 224, 224)
        
        output = denormalize_image(tensor)
        
        # After denormalization and clipping, values should be in [0, 1]
        assert output.min() >= 0
        assert output.max() <= 255

    def test_denormalize_output_shape(self):
        """Test that denormalize produces correct output shape."""
        tensor = torch.randn(3, 224, 224)
        
        output = denormalize_image(tensor)
        
        # Output should be (H, W, C) for visualization
        assert output.shape == (224, 224, 3) or output.shape == (3, 224, 224)

