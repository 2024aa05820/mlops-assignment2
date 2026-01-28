"""
Training script for Cats vs Dogs classification with MLflow tracking.
"""

import os
import sys
import argparse
from pathlib import Path
from datetime import datetime

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
import mlflow
import mlflow.pytorch
import yaml
from tqdm import tqdm
import numpy as np
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.models.cnn import SimpleCNN, count_parameters
from src.models.visualization import plot_confusion_matrix, plot_training_curves, plot_roc_curve
from src.data.dataset import CatsDogsDataset, create_data_loaders
from src.data.preprocessing import get_train_transforms, get_val_transforms


def load_config(config_path: str = "src/config/config.yaml") -> dict:
    """Load configuration from YAML file."""
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)


def train_epoch(
    model: nn.Module,
    train_loader: DataLoader,
    criterion: nn.Module,
    optimizer: optim.Optimizer,
    device: torch.device
) -> tuple:
    """Train for one epoch."""
    model.train()
    running_loss = 0.0
    all_preds = []
    all_labels = []
    
    pbar = tqdm(train_loader, desc="Training")
    for images, labels in pbar:
        images, labels = images.to(device), labels.to(device)
        
        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        
        running_loss += loss.item()
        preds = torch.argmax(outputs, dim=1)
        all_preds.extend(preds.cpu().numpy())
        all_labels.extend(labels.cpu().numpy())
        
        pbar.set_postfix({'loss': f'{loss.item():.4f}'})
    
    avg_loss = running_loss / len(train_loader)
    accuracy = accuracy_score(all_labels, all_preds)
    
    return avg_loss, accuracy


def validate(
    model: nn.Module,
    val_loader: DataLoader,
    criterion: nn.Module,
    device: torch.device
) -> tuple:
    """Validate the model."""
    model.eval()
    running_loss = 0.0
    all_preds = []
    all_labels = []
    
    with torch.no_grad():
        for images, labels in tqdm(val_loader, desc="Validating"):
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            loss = criterion(outputs, labels)
            
            running_loss += loss.item()
            preds = torch.argmax(outputs, dim=1)
            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.cpu().numpy())
    
    avg_loss = running_loss / len(val_loader)
    accuracy = accuracy_score(all_labels, all_preds)
    precision = precision_score(all_labels, all_preds, average='binary')
    recall = recall_score(all_labels, all_preds, average='binary')
    f1 = f1_score(all_labels, all_preds, average='binary')
    
    return avg_loss, accuracy, precision, recall, f1, all_preds, all_labels


def save_model(model: nn.Module, path: str, config: dict):
    """Save model checkpoint."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    torch.save({
        'model_state_dict': model.state_dict(),
        'config': config
    }, path)
    print(f"Model saved to {path}")


def main():
    parser = argparse.ArgumentParser(description='Train Cats vs Dogs classifier')
    parser.add_argument('--config', default='src/config/config.yaml', help='Config file path')
    parser.add_argument('--data-dir', default='data/raw', help='Data directory')
    parser.add_argument('--epochs', type=int, default=None, help='Override epochs')
    parser.add_argument('--batch-size', type=int, default=None, help='Override batch size')
    parser.add_argument('--lr', type=float, default=None, help='Override learning rate')
    args = parser.parse_args()
    
    # Load config
    config = load_config(args.config)
    
    # Override config with command line args
    if args.epochs:
        config['training']['epochs'] = args.epochs
    if args.batch_size:
        config['data']['batch_size'] = args.batch_size
    if args.lr:
        config['training']['learning_rate'] = args.lr
    
    # Setup device
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {device}")
    
    # Setup MLflow
    mlflow.set_tracking_uri(config['mlflow']['tracking_uri'])
    mlflow.set_experiment(config['mlflow']['experiment_name'])
    
    # Create data loaders
    train_dir = os.path.join(args.data_dir, 'train')
    val_dir = os.path.join(args.data_dir, 'val')
    test_dir = os.path.join(args.data_dir, 'test')
    
    train_loader, val_loader, test_loader = create_data_loaders(
        train_dir, val_dir, test_dir if os.path.exists(test_dir) else None,
        batch_size=config['data']['batch_size'],
        num_workers=config['data']['num_workers'],
        image_size=config['data']['image_size'],
        max_train_samples=config['data'].get('max_train_samples'),
        max_val_samples=config['data'].get('max_val_samples')
    )

    print(f"Train samples: {len(train_loader.dataset)}")
    print(f"Val samples: {len(val_loader.dataset)}")
    if config['data'].get('max_train_samples'):
        print(f"(Using subset for quick demo)")

    # Create model
    model = SimpleCNN(
        num_classes=config['model']['num_classes'],
        dropout=config['model']['dropout']
    ).to(device)

    print(f"Model parameters: {count_parameters(model):,}")

    # Loss and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(
        model.parameters(),
        lr=config['training']['learning_rate'],
        weight_decay=config['training']['weight_decay']
    )

    # Learning rate scheduler
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode='min', factor=0.5, patience=2
    )

    # Start MLflow run
    with mlflow.start_run(run_name=f"train_{datetime.now().strftime('%Y%m%d_%H%M%S')}"):
        # Log parameters
        mlflow.log_params({
            "model_name": config['model']['name'],
            "num_classes": config['model']['num_classes'],
            "dropout": config['model']['dropout'],
            "epochs": config['training']['epochs'],
            "batch_size": config['data']['batch_size'],
            "learning_rate": config['training']['learning_rate'],
            "weight_decay": config['training']['weight_decay'],
            "image_size": config['data']['image_size'],
            "device": str(device)
        })

        best_val_acc = 0.0
        best_epoch = 0

        # Track history for visualization
        train_losses, val_losses = [], []
        train_accs, val_accs = [], []
        final_preds, final_labels = [], []

        for epoch in range(config['training']['epochs']):
            print(f"\nEpoch {epoch + 1}/{config['training']['epochs']}")
            print("-" * 40)

            # Train
            train_loss, train_acc = train_epoch(
                model, train_loader, criterion, optimizer, device
            )

            # Validate
            val_loss, val_acc, val_prec, val_rec, val_f1, preds, labels = validate(
                model, val_loader, criterion, device
            )

            # Track history
            train_losses.append(train_loss)
            val_losses.append(val_loss)
            train_accs.append(train_acc)
            val_accs.append(val_acc)
            final_preds, final_labels = preds, labels

            # Update scheduler
            scheduler.step(val_loss)

            # Log metrics
            mlflow.log_metrics({
                "train_loss": train_loss,
                "train_accuracy": train_acc,
                "val_loss": val_loss,
                "val_accuracy": val_acc,
                "val_precision": val_prec,
                "val_recall": val_rec,
                "val_f1": val_f1
            }, step=epoch)

            print(f"Train Loss: {train_loss:.4f} | Train Acc: {train_acc:.4f}")
            print(f"Val Loss: {val_loss:.4f} | Val Acc: {val_acc:.4f}")
            print(f"Val Precision: {val_prec:.4f} | Recall: {val_rec:.4f} | F1: {val_f1:.4f}")

            # Save best model
            if val_acc > best_val_acc:
                best_val_acc = val_acc
                best_epoch = epoch + 1
                save_model(model, config['api']['model_path'], config)
                print(f"New best model saved! (Val Acc: {val_acc:.4f})")

        # Generate and log visualizations
        os.makedirs("reports", exist_ok=True)

        # Confusion matrix
        cm_path = "reports/confusion_matrix.png"
        plot_confusion_matrix(final_labels, final_preds, save_path=cm_path)
        mlflow.log_artifact(cm_path)

        # Training curves
        curves_path = "reports/training_curves.png"
        plot_training_curves(train_losses, val_losses, train_accs, val_accs, save_path=curves_path)
        mlflow.log_artifact(curves_path)

        # Log final metrics
        mlflow.log_metrics({
            "best_val_accuracy": best_val_acc,
            "best_epoch": best_epoch
        })

        # Log model artifact
        mlflow.pytorch.log_model(model, "model")

        print(f"\nTraining complete! Best Val Acc: {best_val_acc:.4f} at epoch {best_epoch}")


if __name__ == "__main__":
    main()

