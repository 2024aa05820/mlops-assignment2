#!/bin/bash
# Download and prepare the Cats vs Dogs dataset from Kaggle
# Requires: kaggle CLI configured with API key

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="${PROJECT_ROOT}/data/raw"

echo "=== Cats vs Dogs Dataset Download Script ==="
echo "Data directory: ${DATA_DIR}"

# Check if kaggle CLI is installed
if ! command -v kaggle &> /dev/null; then
    echo "Error: kaggle CLI not found. Install with: pip install kaggle"
    echo "Also ensure ~/.kaggle/kaggle.json contains your API credentials"
    exit 1
fi

# Create data directories
mkdir -p "${DATA_DIR}/train/cat"
mkdir -p "${DATA_DIR}/train/dog"
mkdir -p "${DATA_DIR}/val/cat"
mkdir -p "${DATA_DIR}/val/dog"
mkdir -p "${DATA_DIR}/test/cat"
mkdir -p "${DATA_DIR}/test/dog"

# Download dataset
echo "Downloading dataset from Kaggle..."
cd "${DATA_DIR}"

# Download the dogs-vs-cats dataset
kaggle competitions download -c dogs-vs-cats -f train.zip -p .

# Extract
echo "Extracting dataset..."
unzip -q -o train.zip
unzip -q -o train.zip -d temp_extract 2>/dev/null || true

# The dataset has a nested train.zip inside
if [ -f "train.zip" ] && [ -d "train" ]; then
    echo "Dataset already extracted"
elif [ -f "train/train.zip" ]; then
    cd train
    unzip -q -o train.zip
    cd ..
fi

# Find the actual images directory
IMAGES_DIR="${DATA_DIR}"
if [ -d "${DATA_DIR}/train/train" ]; then
    IMAGES_DIR="${DATA_DIR}/train/train"
elif [ -d "${DATA_DIR}/train" ]; then
    IMAGES_DIR="${DATA_DIR}/train"
fi

echo "Images directory: ${IMAGES_DIR}"

# Count images
CAT_COUNT=$(find "${IMAGES_DIR}" -name "cat.*.jpg" 2>/dev/null | wc -l)
DOG_COUNT=$(find "${IMAGES_DIR}" -name "dog.*.jpg" 2>/dev/null | wc -l)

echo "Found ${CAT_COUNT} cat images and ${DOG_COUNT} dog images"

# Split data into train/val/test (80/10/10)
echo "Splitting dataset into train/val/test..."

python3 << 'EOF'
import os
import shutil
import random
from pathlib import Path

data_dir = os.environ.get('DATA_DIR', 'data/raw')
images_dir = os.environ.get('IMAGES_DIR', data_dir)

# Find all images
cat_images = list(Path(images_dir).rglob("cat.*.jpg"))
dog_images = list(Path(images_dir).rglob("dog.*.jpg"))

print(f"Processing {len(cat_images)} cat images and {len(dog_images)} dog images")

# Shuffle
random.seed(42)
random.shuffle(cat_images)
random.shuffle(dog_images)

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
        dest_dir = Path(data_dir) / split_name / class_name
        dest_dir.mkdir(parents=True, exist_ok=True)
        for img in split_images:
            dest = dest_dir / img.name
            if not dest.exists():
                shutil.copy2(img, dest)
        print(f"  {split_name}: {len(split_images)} images")

print("Splitting cat images...")
split_and_copy(cat_images, 'cat')

print("Splitting dog images...")
split_and_copy(dog_images, 'dog')

print("Dataset split complete!")
EOF

echo ""
echo "=== Dataset Summary ==="
echo "Train cats: $(ls -1 ${DATA_DIR}/train/cat/*.jpg 2>/dev/null | wc -l)"
echo "Train dogs: $(ls -1 ${DATA_DIR}/train/dog/*.jpg 2>/dev/null | wc -l)"
echo "Val cats: $(ls -1 ${DATA_DIR}/val/cat/*.jpg 2>/dev/null | wc -l)"
echo "Val dogs: $(ls -1 ${DATA_DIR}/val/dog/*.jpg 2>/dev/null | wc -l)"
echo "Test cats: $(ls -1 ${DATA_DIR}/test/cat/*.jpg 2>/dev/null | wc -l)"
echo "Test dogs: $(ls -1 ${DATA_DIR}/test/dog/*.jpg 2>/dev/null | wc -l)"

# Cleanup
echo "Cleaning up temporary files..."
rm -f "${DATA_DIR}/train.zip"
rm -rf "${DATA_DIR}/temp_extract"

echo ""
echo "=== Done! ==="
echo "Dataset is ready at: ${DATA_DIR}"

