# Deployment – spring-petclinic

This directory contains Kubernetes manifests and deployment instructions for the **spring-petclinic** application running on Azure Kubernetes Service (AKS).

---

## Directory Structure

```
deploy/
└── kubernetes/
    ├── deployment.yaml   # Deployment (1 replica, resource limits, probes, affinity)
    └── service.yaml      # ClusterIP Service (port 80 → container 8080)
.github/
└── workflows/
    └── deploy-to-aks.yml # GitHub Actions workflow (workflow_dispatch only)
```

---

## AKS Configuration

| Setting | Value |
|---|---|
| Cluster | `clu-10849` |
| Resource Group | `dansol19959` |
| Namespace | `my-dev-backend` |
| Container Registry | `bbashreg19959.azurecr.io` |
| Service Type | `ClusterIP` |
| App Port | `8080` (container) → `80` (service) |

---

## Deploying

Deployments are triggered **manually** via GitHub Actions:

1. Go to **Actions → Deploy spring-petclinic to AKS**
2. Click **Run workflow**
3. Optionally override `cluster-name`, `resource-group`, or `namespace`
4. Click **Run workflow**

The workflow will:
1. Log in to Azure using OIDC (no long-lived secrets)
2. Build and push the image to ACR using `az acr build`
3. Configure `kubectl` with `kubelogin` for AAD-enabled cluster access
4. Apply all manifests under `deploy/kubernetes/`
5. Annotate the Deployment with the run URL and workflow name
6. Wait for the rollout to complete

---

## Required GitHub Secrets

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | Service principal / managed identity client ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `AZURE_ACR_NAME` | ACR registry name (e.g. `bbashreg19959`) |

---

## Dry-Run Validation

```bash
# Validate manifests without applying
kubectl apply --dry-run=client -f deploy/kubernetes/
```

---

## Local Image Build

```bash
# Build the image locally (tag 1.0)
docker build -t spring-petclinic:1.0 .

# Run locally
docker run -p 8080:8080 spring-petclinic:1.0
```

Open http://localhost:8080 in your browser.
