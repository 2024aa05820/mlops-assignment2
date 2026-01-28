#!/usr/bin/env python3
"""
Script to find and optionally remove corrupted images from the dataset.
"""

import os
import sys
from pathlib import Path
from PIL import Image
from tqdm import tqdm

def check_image(image_path: str) -> bool:
    """Check if an image is valid and can be opened."""
    try:
        with Image.open(image_path) as img:
            img.verify()  # Verify it's a valid image
        # Re-open and try to load the data
        with Image.open(image_path) as img:
            img.load()  # Actually load the image data
        return True
    except Exception as e:
        return False

def find_corrupted_images(data_dir: str) -> list:
    """Find all corrupted images in the data directory."""
    corrupted = []
    
    # Find all image files
    image_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp'}
    image_files = []
    
    for root, dirs, files in os.walk(data_dir):
        for file in files:
            if Path(file).suffix.lower() in image_extensions:
                image_files.append(os.path.join(root, file))
    
    print(f"Checking {len(image_files)} images...")
    
    for image_path in tqdm(image_files, desc="Checking images"):
        if not check_image(image_path):
            corrupted.append(image_path)
    
    return corrupted

def main():
    data_dir = "data/raw"
    
    if not os.path.exists(data_dir):
        print(f"Error: {data_dir} not found")
        sys.exit(1)
    
    print(f"Scanning {data_dir} for corrupted images...")
    corrupted = find_corrupted_images(data_dir)
    
    if not corrupted:
        print("\n✅ No corrupted images found!")
        return
    
    print(f"\n⚠️  Found {len(corrupted)} corrupted images:")
    for img in corrupted:
        print(f"  - {img}")
    
    # Ask to remove
    response = input("\nRemove these corrupted images? (y/n): ").strip().lower()
    if response == 'y':
        for img in corrupted:
            os.remove(img)
            print(f"Removed: {img}")
        print(f"\n✅ Removed {len(corrupted)} corrupted images")
    else:
        print("No files removed.")

if __name__ == "__main__":
    main()

