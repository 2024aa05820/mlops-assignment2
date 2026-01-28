#!/bin/bash
# Download and prepare the Cats vs Dogs dataset from Kaggle
# Dataset: https://www.kaggle.com/datasets/bhavikjikadara/dog-and-cat-classification-dataset
# Requires: kaggle CLI configured with API token

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="${PROJECT_ROOT}/data/raw"

echo "=== Cats vs Dogs Dataset Download Script ==="
echo "Data directory: ${DATA_DIR}"

# Check if kaggle CLI is installed
if ! command -v kaggle &> /dev/null; then
    echo "Error: kaggle CLI not found. Install with: pip install kaggle"
    exit 1
fi

# Check if kaggle credentials exist (either env var or json file)
if [ -z "$KAGGLE_API_TOKEN" ] && [ ! -f ~/.kaggle/kaggle.json ]; then
    echo "Error: Kaggle credentials not found!"
    echo ""
    echo "Option 1: Set KAGGLE_API_TOKEN environment variable"
    echo "  1. Go to https://www.kaggle.com/settings -> API -> Create New Token"
    echo "  2. Copy the API token shown"
    echo "  3. Run: export KAGGLE_API_TOKEN=your_token_here"
    echo "  4. Or add to ~/.bashrc or ~/.zshrc for persistence"
    echo ""
    echo "Option 2: Use kaggle.json file"
    echo "  1. Go to https://www.kaggle.com/settings -> API -> Create New Token"
    echo "  2. Download kaggle.json"
    echo "  3. mkdir -p ~/.kaggle && mv ~/Downloads/kaggle.json ~/.kaggle/"
    echo "  4. chmod 600 ~/.kaggle/kaggle.json"
    exit 1
fi

echo "Kaggle credentials found!"

# Create data directory
mkdir -p "${DATA_DIR}"
cd "${DATA_DIR}"

# Download dataset from Kaggle
echo "Downloading dataset from Kaggle..."
echo "Source: bhavikjikadara/dog-and-cat-classification-dataset"
kaggle datasets download -d bhavikjikadara/dog-and-cat-classification-dataset -p . --unzip

echo "Download complete. Checking dataset structure..."

# List what was downloaded
ls -la "${DATA_DIR}"

# The dataset structure may vary, let's detect it
echo "Detecting dataset structure..."

# Export for Python script
export DATA_DIR

# Split data into train/val/test (80/10/10)
echo "Organizing dataset into train/val/test splits..."

python3 << 'EOF'
import os
import shutil
import random
from pathlib import Path

data_dir = Path(os.environ.get('DATA_DIR', 'data/raw'))

# Find all cat and dog images (various naming patterns)
all_files = list(data_dir.rglob("*.*"))
image_extensions = {'.jpg', '.jpeg', '.png', '.JPG', '.JPEG', '.PNG'}

cat_images = []
dog_images = []

for f in all_files:
    if f.suffix in image_extensions:
        name_lower = f.name.lower()
        parent_lower = f.parent.name.lower()

        # Check if it's a cat image
        if 'cat' in name_lower or 'cat' in parent_lower:
            cat_images.append(f)
        # Check if it's a dog image
        elif 'dog' in name_lower or 'dog' in parent_lower:
            dog_images.append(f)

print(f"Found {len(cat_images)} cat images and {len(dog_images)} dog images")

if len(cat_images) == 0 or len(dog_images) == 0:
    print("Warning: Could not find images. Listing directory structure:")
    for f in sorted(all_files)[:20]:
        print(f"  {f}")
    exit(1)

# Shuffle with fixed seed for reproducibility
random.seed(42)
random.shuffle(cat_images)
random.shuffle(dog_images)

# Split ratios: 80% train, 10% val, 10% test
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
        dest_dir = data_dir / split_name / class_name
        dest_dir.mkdir(parents=True, exist_ok=True)
        for i, img in enumerate(split_images):
            # Standardize filename
            ext = img.suffix.lower()
            dest = dest_dir / f"{class_name}.{i}{ext}"
            if not dest.exists():
                shutil.copy2(img, dest)
        print(f"  {class_name} {split_name}: {len(split_images)} images")

print("\nSplitting cat images...")
split_and_copy(cat_images, 'cat')

print("\nSplitting dog images...")
split_and_copy(dog_images, 'dog')

print("\nDataset split complete!")
EOF

echo ""
echo "=== Dataset Summary ==="
echo "Train cats: $(find ${DATA_DIR}/train/cat -name "*.jpg" -o -name "*.png" 2>/dev/null | wc -l)"
echo "Train dogs: $(find ${DATA_DIR}/train/dog -name "*.jpg" -o -name "*.png" 2>/dev/null | wc -l)"
echo "Val cats: $(find ${DATA_DIR}/val/cat -name "*.jpg" -o -name "*.png" 2>/dev/null | wc -l)"
echo "Val dogs: $(find ${DATA_DIR}/val/dog -name "*.jpg" -o -name "*.png" 2>/dev/null | wc -l)"
echo "Test cats: $(find ${DATA_DIR}/test/cat -name "*.jpg" -o -name "*.png" 2>/dev/null | wc -l)"
echo "Test dogs: $(find ${DATA_DIR}/test/dog -name "*.jpg" -o -name "*.png" 2>/dev/null | wc -l)"

echo ""
echo "=== Done! ==="
echo "Dataset is ready at: ${DATA_DIR}"

