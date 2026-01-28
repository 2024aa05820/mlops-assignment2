#!/usr/bin/env python3
"""
Download sample data for CI/CD training.
Creates a small subset of cat/dog images for quick training in GitHub Actions.
"""

import os
import urllib.request
import zipfile
import shutil
from pathlib import Path


def download_sample_images():
    """Download sample cat and dog images for CI training."""
    
    # Create directories
    data_dir = Path("data/raw")
    train_cats = data_dir / "train" / "cats"
    train_dogs = data_dir / "train" / "dogs"
    val_cats = data_dir / "val" / "cats"
    val_dogs = data_dir / "val" / "dogs"
    
    for d in [train_cats, train_dogs, val_cats, val_dogs]:
        d.mkdir(parents=True, exist_ok=True)
    
    # Sample image URLs (using placeholder images for CI)
    # In real scenario, you'd download from your data source
    print("Creating sample images for CI training...")
    
    # Create simple colored images as placeholders
    try:
        from PIL import Image
        import random
        
        def create_sample_image(path, color_range):
            """Create a simple colored image."""
            img = Image.new('RGB', (224, 224))
            pixels = img.load()
            for i in range(224):
                for j in range(224):
                    # Add some variation
                    r = min(255, color_range[0] + random.randint(-30, 30))
                    g = min(255, color_range[1] + random.randint(-30, 30))
                    b = min(255, color_range[2] + random.randint(-30, 30))
                    pixels[i, j] = (max(0, r), max(0, g), max(0, b))
            img.save(path, 'JPEG')
        
        # Create cat images (more blue-ish tones)
        print("Creating cat samples...")
        for i in range(100):
            create_sample_image(train_cats / f"cat.{i}.jpg", (100, 100, 150))
        for i in range(20):
            create_sample_image(val_cats / f"cat.{i}.jpg", (100, 100, 150))
        
        # Create dog images (more brown-ish tones)
        print("Creating dog samples...")
        for i in range(100):
            create_sample_image(train_dogs / f"dog.{i}.jpg", (150, 120, 80))
        for i in range(20):
            create_sample_image(val_dogs / f"dog.{i}.jpg", (150, 120, 80))
        
        print(f"✅ Created sample dataset:")
        print(f"   Train cats: {len(list(train_cats.glob('*.jpg')))}")
        print(f"   Train dogs: {len(list(train_dogs.glob('*.jpg')))}")
        print(f"   Val cats: {len(list(val_cats.glob('*.jpg')))}")
        print(f"   Val dogs: {len(list(val_dogs.glob('*.jpg')))}")
        
    except ImportError:
        print("PIL not available, creating empty placeholder files")
        # Create empty files as placeholders
        for i in range(100):
            (train_cats / f"cat.{i}.jpg").touch()
            (train_dogs / f"dog.{i}.jpg").touch()
        for i in range(20):
            (val_cats / f"cat.{i}.jpg").touch()
            (val_dogs / f"dog.{i}.jpg").touch()


if __name__ == "__main__":
    download_sample_images()

