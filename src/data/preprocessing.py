"""
Image preprocessing utilities for Cats vs Dogs classification.
"""

import os
from pathlib import Path
from typing import Tuple, Optional

import torch
from torchvision import transforms
from PIL import Image
import numpy as np


def get_train_transforms(image_size: int = 224) -> transforms.Compose:
    """
    Get training data transforms with augmentation.
    
    Args:
        image_size: Target image size (default: 224x224)
        
    Returns:
        Composed transforms for training data
    """
    return transforms.Compose([
        transforms.Resize((image_size, image_size)),
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.RandomRotation(degrees=15),
        transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        )
    ])


def get_val_transforms(image_size: int = 224) -> transforms.Compose:
    """
    Get validation/test data transforms (no augmentation).
    
    Args:
        image_size: Target image size (default: 224x224)
        
    Returns:
        Composed transforms for validation/test data
    """
    return transforms.Compose([
        transforms.Resize((image_size, image_size)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        )
    ])


def preprocess_image(
    image_path: str,
    image_size: int = 224,
    for_training: bool = False
) -> torch.Tensor:
    """
    Preprocess a single image for model inference or training.
    
    Args:
        image_path: Path to the image file
        image_size: Target image size
        for_training: Whether to apply training augmentations
        
    Returns:
        Preprocessed image tensor
    """
    image = Image.open(image_path).convert('RGB')
    
    if for_training:
        transform = get_train_transforms(image_size)
    else:
        transform = get_val_transforms(image_size)
    
    return transform(image)


def preprocess_image_bytes(
    image_bytes: bytes,
    image_size: int = 224
) -> torch.Tensor:
    """
    Preprocess image from bytes (for API inference).
    
    Args:
        image_bytes: Raw image bytes
        image_size: Target image size
        
    Returns:
        Preprocessed image tensor
    """
    from io import BytesIO
    
    image = Image.open(BytesIO(image_bytes)).convert('RGB')
    transform = get_val_transforms(image_size)
    
    return transform(image)


def denormalize_image(tensor: torch.Tensor) -> np.ndarray:
    """
    Denormalize a tensor image for visualization.
    
    Args:
        tensor: Normalized image tensor
        
    Returns:
        Denormalized numpy array (H, W, C) in range [0, 255]
    """
    mean = torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)
    std = torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)
    
    tensor = tensor * std + mean
    tensor = torch.clamp(tensor, 0, 1)
    
    # Convert to numpy and transpose to (H, W, C)
    image = tensor.numpy().transpose(1, 2, 0)
    return (image * 255).astype(np.uint8)


def validate_image(image_path: str) -> Tuple[bool, Optional[str]]:
    """
    Validate that an image file is valid and can be processed.
    
    Args:
        image_path: Path to the image file
        
    Returns:
        Tuple of (is_valid, error_message)
    """
    try:
        if not os.path.exists(image_path):
            return False, f"File not found: {image_path}"
        
        image = Image.open(image_path)
        image.verify()  # Verify it's a valid image
        
        # Re-open to check if it can be converted to RGB
        image = Image.open(image_path)
        image.convert('RGB')
        
        return True, None
        
    except Exception as e:
        return False, str(e)

