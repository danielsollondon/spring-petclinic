# Deploying Spring PetClinic to Kubernetes

This directory contains Kubernetes manifests to deploy the Spring PetClinic application with a PostgreSQL database.

## Which Kubernetes Distribution Should I Use?

### Recommended: Kind (for local development / CI)

[Kind](https://kind.sigs.k8s.io/) (Kubernetes IN Docker) is the easiest way to get started locally and is already used in this project's CI workflow:

```bash
# Install kind
brew install kind          # macOS
# or download from https://kind.sigs.k8s.io/docs/user/quick-start/#installation

# Create a cluster
kind create cluster

# Verify
kubectl cluster-info --context kind-kind
```

### Other Options

| Distribution | Best For |
|---|---|
| [Kind](https://kind.sigs.k8s.io/) | Local development, CI pipelines |
| [minikube](https://minikube.sigs.k8s.io/) | Local development with more features (Ingress, metrics-server) |
| [k3s](https://k3s.io/) | Lightweight production, edge/IoT, Raspberry Pi |
| [Amazon EKS](https://aws.amazon.com/eks/) | Production on AWS |
| [Google GKE](https://cloud.google.com/kubernetes-engine) | Production on Google Cloud |
| [Azure AKS](https://azure.microsoft.com/en-us/products/kubernetes-service) | Production on Azure |

## Prerequisites

- A running Kubernetes cluster (see above)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/) configured to point to your cluster
- A container image of PetClinic (see [Building the Image](#building-the-image))

## Building the Image

There is no `Dockerfile` in this project. Use the Spring Boot Maven plugin to build an OCI image:

```bash
# Build with a custom image name
./mvnw spring-boot:build-image -Dspring-boot.build-image.imageName=<your-registry>/petclinic:latest

# Push to your registry
docker push <your-registry>/petclinic:latest
```

Then update the `image:` field in `k8s/petclinic.yml` to match your registry and tag.

## Deploying

Apply all manifests in one command:

```bash
kubectl apply -f k8s/
```

This will create:
- A `Secret` (`demo-db`) with PostgreSQL credentials
- A `PersistentVolumeClaim` (`demo-db-pvc`) for database storage
- A `Service` and `Deployment` for PostgreSQL (`demo-db`)
- A `Service` and `Deployment` for PetClinic (`petclinic`)

### Wait for Pods to be Ready

```bash
kubectl wait --for=condition=ready pod -l app=demo-db --timeout=180s
kubectl wait --for=condition=ready pod -l app=petclinic --timeout=180s
```

## Accessing the Application

### Using Kind or minikube

```bash
# Get the NodePort assigned to the petclinic service
kubectl get svc petclinic

# For Kind, forward the port to your local machine
kubectl port-forward svc/petclinic 8080:80

# Then open http://localhost:8080 in your browser
```

### Using minikube directly

```bash
minikube service petclinic
```

### On a cloud provider (EKS/GKE/AKS)

Change the Service type in `k8s/petclinic.yml` from `NodePort` to `LoadBalancer` to get a public IP:

```yaml
spec:
  type: LoadBalancer
```

Then get the external IP:

```bash
kubectl get svc petclinic
```

## What's in the Manifests

### `db.yml`

- **Secret** (`demo-db`): PostgreSQL credentials (username, password, database name). Change these values before deploying to production.
- **PersistentVolumeClaim** (`demo-db-pvc`): 1Gi volume for PostgreSQL data so your data survives pod restarts.
- **Service** (`demo-db`): Internal ClusterIP service exposing PostgreSQL on port 5432.
- **Deployment** (`demo-db`): Single-replica PostgreSQL 18.3 deployment with health probes and resource limits.

### `petclinic.yml`

- **Service** (`petclinic`): NodePort service exposing the application on port 80 (mapped to container port 8080).
- **Deployment** (`petclinic`): Single-replica PetClinic deployment configured with the `postgres` profile, pointing at the `demo-db` service. Includes liveness, readiness, and startup probes using the Spring Boot Actuator `/livez` and `/readyz` endpoints.

## Customising Credentials

The default credentials in `db.yml` are for development only. For production, replace the `Secret` with a securely managed secret (for example using [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets), [External Secrets Operator](https://external-secrets.io/), or your cloud provider's secret manager):

```bash
# Example: override credentials before applying
kubectl create secret generic demo-db \
  --from-literal=database=petclinic \
  --from-literal=username=<your-username> \
  --from-literal=password=<your-password>

kubectl apply -f k8s/petclinic.yml k8s/db.yml
```

## Tearing Down

```bash
kubectl delete -f k8s/
```

> **Note:** Deleting the manifests will also delete the `PersistentVolumeClaim`. To preserve your database data, delete individual resources and skip the PVC deletion.
