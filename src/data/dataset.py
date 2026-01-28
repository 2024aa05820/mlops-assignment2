"""
PyTorch Dataset for Cats vs Dogs classification.
"""

import os
from pathlib import Path
from typing import Tuple, List, Optional, Callable

import torch
from torch.utils.data import Dataset, DataLoader
from PIL import Image

from .preprocessing import get_train_transforms, get_val_transforms


class CatsDogsDataset(Dataset):
    """
    PyTorch Dataset for Cats vs Dogs binary classification.
    
    Expected directory structure:
        data_dir/
            cats/
                cat.0.jpg
                cat.1.jpg
                ...
            dogs/
                dog.0.jpg
                dog.1.jpg
                ...
    """
    
    # Class labels
    CLASSES = ['cat', 'dog']
    CLASS_TO_IDX = {'cat': 0, 'dog': 1}
    IDX_TO_CLASS = {0: 'cat', 1: 'dog'}
    
    def __init__(
        self,
        data_dir: str,
        transform: Optional[Callable] = None,
        image_size: int = 224
    ):
        """
        Initialize the dataset.
        
        Args:
            data_dir: Path to the data directory
            transform: Optional transform to apply to images
            image_size: Target image size (used if transform is None)
        """
        self.data_dir = Path(data_dir)
        self.image_size = image_size
        self.transform = transform or get_val_transforms(image_size)
        
        # Collect all image paths and labels
        self.samples: List[Tuple[str, int]] = []
        self._load_samples()
    
    def _load_samples(self):
        """Load all image paths and their labels."""
        for class_name in self.CLASSES:
            class_dir = self.data_dir / class_name
            if not class_dir.exists():
                # Try alternative naming (cats/dogs folders)
                class_dir = self.data_dir / f"{class_name}s"
            
            if class_dir.exists():
                label = self.CLASS_TO_IDX[class_name]
                for img_path in class_dir.glob("*"):
                    if img_path.suffix.lower() in ['.jpg', '.jpeg', '.png']:
                        self.samples.append((str(img_path), label))
    
    def __len__(self) -> int:
        return len(self.samples)
    
    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, int]:
        """
        Get a sample from the dataset.
        
        Args:
            idx: Sample index
            
        Returns:
            Tuple of (image_tensor, label)
        """
        img_path, label = self.samples[idx]
        
        # Load and convert image
        image = Image.open(img_path).convert('RGB')
        
        # Apply transforms
        if self.transform:
            image = self.transform(image)
        
        return image, label
    
    @classmethod
    def get_class_name(cls, idx: int) -> str:
        """Get class name from index."""
        return cls.IDX_TO_CLASS.get(idx, "unknown")


def create_data_loaders(
    train_dir: str,
    val_dir: str,
    test_dir: Optional[str] = None,
    batch_size: int = 32,
    num_workers: int = 4,
    image_size: int = 224,
    max_train_samples: Optional[int] = None,
    max_val_samples: Optional[int] = None
) -> Tuple[DataLoader, DataLoader, Optional[DataLoader]]:
    """
    Create DataLoaders for training, validation, and optionally test sets.

    Args:
        train_dir: Path to training data
        val_dir: Path to validation data
        test_dir: Optional path to test data
        batch_size: Batch size for DataLoaders
        num_workers: Number of worker processes
        image_size: Target image size
        max_train_samples: Limit training samples (for quick demos)
        max_val_samples: Limit validation samples (for quick demos)

    Returns:
        Tuple of (train_loader, val_loader, test_loader)
    """
    # Create datasets
    train_dataset = CatsDogsDataset(
        train_dir,
        transform=get_train_transforms(image_size),
        image_size=image_size
    )

    val_dataset = CatsDogsDataset(
        val_dir,
        transform=get_val_transforms(image_size),
        image_size=image_size
    )

    # Limit samples for quick demo/testing
    if max_train_samples and max_train_samples < len(train_dataset):
        indices = torch.randperm(len(train_dataset))[:max_train_samples].tolist()
        train_dataset = torch.utils.data.Subset(train_dataset, indices)

    if max_val_samples and max_val_samples < len(val_dataset):
        indices = torch.randperm(len(val_dataset))[:max_val_samples].tolist()
        val_dataset = torch.utils.data.Subset(val_dataset, indices)
    
    # Check if CUDA is available for pin_memory optimization
    use_pin_memory = torch.cuda.is_available()

    # Create DataLoaders
    train_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        shuffle=True,
        num_workers=num_workers,
        pin_memory=use_pin_memory
    )

    val_loader = DataLoader(
        val_dataset,
        batch_size=batch_size,
        shuffle=False,
        num_workers=num_workers,
        pin_memory=use_pin_memory
    )

    test_loader = None
    if test_dir:
        test_dataset = CatsDogsDataset(
            test_dir,
            transform=get_val_transforms(image_size),
            image_size=image_size
        )
        test_loader = DataLoader(
            test_dataset,
            batch_size=batch_size,
            shuffle=False,
            num_workers=num_workers,
            pin_memory=use_pin_memory
        )
    
    return train_loader, val_loader, test_loader

