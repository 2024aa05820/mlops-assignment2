# Local Kubernetes Deployment (Kind)

Deploy the Cats vs Dogs Classification API to a local Kubernetes cluster using Kind.

## Prerequisites

- Docker Desktop running
- Homebrew (for Mac)

## Quick Start

```bash
# Install Kind and kubectl (one-time)
make kind-install

# Create cluster and deploy app
make kind-up
```

The API will be available at: **http://localhost:8000**

## Commands Reference

| Command | Description |
|---------|-------------|
| `make kind-install` | Install Kind and kubectl via Homebrew |
| `make kind-up` | Create cluster + build + deploy (full setup) |
| `make kind-down` | Delete the Kind cluster |
| `make kind-status` | Show pods, services, deployments |
| `make kind-logs` | Stream logs from pods |
| `make kind-test` | Test API endpoints |
| `make kind-restart` | Restart the deployment |
| `make kind-shell` | Shell into a running pod |
| `make kind-scale` | Scale the deployment |

## API Endpoints

Once deployed, these endpoints are available:

- **Health:** http://localhost:8000/health
- **Ready:** http://localhost:8000/ready
- **API Docs:** http://localhost:8000/docs
- **Predict:** http://localhost:8000/predict (POST)

## Test the API

```bash
# Quick test
make kind-test

# Test prediction
curl -X POST http://localhost:8000/predict \
  -F "file=@path/to/cat_or_dog.jpg"
```

## Architecture

```
┌─────────────────────────────────────────────┐
│              Kind Cluster                    │
│  ┌────────────────────────────────────────┐ │
│  │           mlops namespace              │ │
│  │  ┌──────────────┐ ┌──────────────┐    │ │
│  │  │   Pod 1      │ │   Pod 2      │    │ │
│  │  │ cats-dogs-api│ │ cats-dogs-api│    │ │
│  │  └──────────────┘ └──────────────┘    │ │
│  │           │              │             │ │
│  │           └──────┬───────┘             │ │
│  │                  │                     │ │
│  │         ┌────────▼────────┐           │ │
│  │         │    Service      │           │ │
│  │         │  NodePort:30080 │           │ │
│  │         └────────┬────────┘           │ │
│  └──────────────────│─────────────────────┘ │
│                     │                        │
└─────────────────────│────────────────────────┘
                      │
              localhost:8000
```

## Kubernetes Files

| File | Purpose |
|------|---------|
| `kind-config.yaml` | Kind cluster configuration with port mappings |
| `namespace.yaml` | Creates `mlops` namespace |
| `configmap.yaml` | Application configuration |
| `deployment.yaml` | Pod deployment with 2 replicas |
| `service.yaml` | NodePort service exposing port 8000 |
| `hpa.yaml` | Horizontal Pod Autoscaler (optional) |

## Troubleshooting

### Pods not starting
```bash
# Check pod status
kubectl get pods -n mlops

# Describe pod for details
kubectl describe pod -l app=cats-dogs-api -n mlops
```

### Image not found
```bash
# Rebuild and reload image
make kind-build
make kind-restart
```

### Port already in use
```bash
# Check what's using port 8000
lsof -i :8000

# Stop the process or change the port in kind-config.yaml
```

### Cluster issues
```bash
# Delete and recreate cluster
make kind-down
make kind-up
```

