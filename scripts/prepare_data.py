#!/usr/bin/env python3
"""
Prepare data for training - organize downloaded Kaggle dataset.
Used by Jenkins pipeline after Kaggle download.
"""

import os
import shutil
import random
from pathlib import Path


def prepare_dataset(data_dir: str = "data", max_samples: int = None):
    """
    Organize downloaded Kaggle dataset into train/val/test splits.
    
    Args:
        data_dir: Base data directory
        max_samples: Maximum samples per class (None for all)
    """
    data_path = Path(data_dir)
    raw_path = data_path / "raw"
    
    # Create raw directory if it doesn't exist
    raw_path.mkdir(parents=True, exist_ok=True)
    
    # Find all image files
    all_files = list(data_path.rglob("*.*"))
    image_extensions = {'.jpg', '.jpeg', '.png', '.JPG', '.JPEG', '.PNG'}
    
    cat_images = []
    dog_images = []
    
    for f in all_files:
        if f.suffix in image_extensions:
            # Skip if already in train/val/test structure
            if any(x in str(f) for x in ['/train/', '/val/', '/test/']):
                continue
                
            name_lower = f.name.lower()
            parent_lower = f.parent.name.lower()
            
            if 'cat' in name_lower or 'cat' in parent_lower:
                cat_images.append(f)
            elif 'dog' in name_lower or 'dog' in parent_lower:
                dog_images.append(f)
    
    print(f"Found {len(cat_images)} cat images and {len(dog_images)} dog images")
    
    if len(cat_images) == 0 or len(dog_images) == 0:
        print("No new images to process. Dataset may already be organized.")
        # Check if data already exists
        train_cats = list((raw_path / "train" / "cats").glob("*.jpg")) if (raw_path / "train" / "cats").exists() else []
        if len(train_cats) > 0:
            print(f"Existing dataset found: {len(train_cats)} training cat images")
            return
        print("Warning: No images found!")
        return
    
    # Shuffle with fixed seed
    random.seed(42)
    random.shuffle(cat_images)
    random.shuffle(dog_images)
    
    # Limit samples if specified
    if max_samples:
        cat_images = cat_images[:max_samples]
        dog_images = dog_images[:max_samples]
        print(f"Limited to {max_samples} samples per class")
    
    # Split ratios
    train_ratio = 0.8
    val_ratio = 0.1
    
    def split_and_copy(images, class_name):
        n = len(images)
        train_end = int(n * train_ratio)
        val_end = int(n * (train_ratio + val_ratio))
        
        splits = {
            'train': images[:train_end],
            'val': images[train_end:val_end],
            'test': images[val_end:]
        }
        
        for split_name, split_images in splits.items():
            # Use 'cats' and 'dogs' folder names (plural)
            folder_name = f"{class_name}s"
            dest_dir = raw_path / split_name / folder_name
            dest_dir.mkdir(parents=True, exist_ok=True)
            
            for i, img in enumerate(split_images):
                ext = img.suffix.lower()
                dest = dest_dir / f"{class_name}.{i}{ext}"
                if not dest.exists():
                    shutil.copy2(img, dest)
            
            print(f"  {class_name} {split_name}: {len(split_images)} images")
    
    print("\nOrganizing cat images...")
    split_and_copy(cat_images, 'cat')
    
    print("\nOrganizing dog images...")
    split_and_copy(dog_images, 'dog')
    
    print("\n✅ Dataset preparation complete!")
    print(f"Data location: {raw_path}")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Prepare dataset for training')
    parser.add_argument('--data-dir', default='data', help='Data directory')
    parser.add_argument('--max-samples', type=int, default=None, help='Max samples per class')
    
    args = parser.parse_args()
    prepare_dataset(args.data_dir, args.max_samples)

