---
name: containerize-and-deploy
description: "Analyze repository, generate a best-practice Dockerfile, Kubernetes manifests, and a GitHub Actions deployment workflow for AKS."
---

## Role
You are a containerization-focused coding agent. Your job is to take this repository and:
1) Make it run correctly in a container (Dockerfile + buildable image).
2) Generate Kubernetes manifests for deployment to Azure Kubernetes Service (AKS).
3) Generate a GitHub Actions workflow for CI/CD deployment to AKS.

## Hard Requirements
- **Image tag must be `1.0`** (always).
- Maintain a checklist at `artifacts/tool-call-checklist.md` and update it immediately after each tool call.
- **Always call these in order** for Dockerfile work:
  1) `containerization-assist-mcp/generate-dockerfile`
  2) `containerization-assist-mcp/fix-dockerfile`
  3) `containerization-assist-mcp/build-image`

## Tools
Do not restrict tools. Use any available built-in tools and MCP tools.
Prefer using these MCP tools when available:
- containerization-assist-mcp/analyze-repo
- containerization-assist-mcp/generate-dockerfile
- containerization-assist-mcp/fix-dockerfile
- containerization-assist-mcp/build-image
- containerization-assist-mcp/scan-image
- containerization-assist-mcp/generate-k8s-manifests

If any specific tool is unavailable, fall back to shell commands and repo inspection.

## Tool Call Checklist Workflow (mandatory)
At the very start:
1) Create `artifacts/tool-call-checklist.md`.
2) Use the template below.
3) After **each** tool call, immediately update the file:
   - check the box
   - record brief result + key outputs
4) If a tool is not applicable, mark **Skipped** with a reason.

### Checklist template (create exactly this structure)
- [ ] containerization-assist-mcp/analyze-repo — Result:
- [ ] containerization-assist-mcp/generate-dockerfile — Result:
- [ ] containerization-assist-mcp/fix-dockerfile — Result:
- [ ] containerization-assist-mcp/build-image — Result:
- [ ] containerization-assist-mcp/scan-image — Result:
- [ ] containerization-assist-mcp/generate-k8s-manifests — Result:

## Principles
- Don't hardcode repo-specific ports or framework assumptions. Infer from analysis.
- Prefer best practices: multi-stage build when applicable, minimal runtime image, non-root, cache-friendly layering, reproducible builds.
- Keep changes minimal and explainable; don't restructure the repo unless necessary.
- Always iterate on failures: **fix → rebuild** until green.
- Do not call `containerization-assist-mcp/ops`.

## Required Execution Plan

### 0) Initialize the checklist
Create `artifacts/tool-call-checklist.md` using the template above before any tool calls.

### 1) Analyze the repository
Call `containerization-assist-mcp/analyze-repo` at the repo root.
Update checklist with detected stack, port, build/run commands, deps/env vars.

### 2) Generate Dockerfile (always)
Call `containerization-assist-mcp/generate-dockerfile` even if a Dockerfile exists.
Update checklist with where it wrote/updated the Dockerfile and any notes.

### 3) Fix Dockerfile (always, immediately after generate)
Call `containerization-assist-mcp/fix-dockerfile`.
Update checklist with fixes made.

### 4) Build the image (tag must be 1.0)
Call `containerization-assist-mcp/build-image` using:
- image name = sanitized repo name
- image tag = `1.0`

If build fails:
- Call `containerization-assist-mcp/fix-dockerfile` (again)
- Re-run `build-image`
- Repeat until successful

### 5) Scan the image (recommended)
Call `containerization-assist-mcp/scan-image` after a successful build.
If scan is unavailable/not applicable, mark Skipped with reason.

### 6) Generate Kubernetes manifests
Call `containerization-assist-mcp/generate-k8s-manifests`.

## Output Directory
All generated deployment files must be placed under `/deploy/`:
- `/deploy/kubernetes/` — Kubernetes manifests (Deployment, Service, Ingress, etc.)
- `/deploy/README.md` — (optional) description of the deployment setup
- `.github/workflows/deploy-to-aks.yml` — deployment workflow

## AKS Deployment Configuration
- Cluster: clu-10849
- Resource Group: dansol19959
- Namespace: my-dev-backend
- Service Type: ClusterIP
- Azure credentials are stored as GitHub repository secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
- Container Registry: `bbashreg19959.azurecr.io` (ACR name stored as secret `AZURE_ACR_NAME`)
- Target Port: 80
- Replicas: 1
- CPU Request: 100m
- CPU Limit: 500m
- Memory Request: 128Mi
- Memory Limit: 512Mi
- Liveness Probe: enabled (path: /)
- Readiness Probe: enabled (path: /)
- Startup Probe: enabled (path: /)
- Allow Privilege Escalation: false
- Pod Anti-Affinity: enabled
- Topology Spread Constraints: enabled

## Deployment Annotations (mandatory)
All generated Deployment manifests MUST include these annotations in `metadata.annotations`:
- `aks-project/deployed-by: pipeline`
- `aks-project/pipeline-repo: danielsollondon/spring-petclinic`

Example:
```yaml
metadata:
  name: spring-petclinic
  namespace: my-dev-backend
  annotations:
    aks-project/deployed-by: pipeline
    aks-project/pipeline-repo: danielsollondon/spring-petclinic
```

## GitHub Actions Workflow Requirements
Generate `.github/workflows/deploy-to-aks.yml` with the following:
- Trigger ONLY on `workflow_dispatch` with the following required string inputs (and their defaults):
  - `cluster-name` (default: `clu-10849`)
  - `resource-group` (default: `dansol19959`)
  - `namespace` (default: `my-dev-backend`)
- Do NOT add a `push` trigger — deployment is always triggered explicitly
- Use `azure/login@v2` with OIDC (`secrets.AZURE_CLIENT_ID`, `secrets.AZURE_TENANT_ID`, `secrets.AZURE_SUBSCRIPTION_ID`)
- Use `azure/aks-set-context@v4` with cluster `${{ inputs.cluster-name }}` and resource group `${{ inputs.resource-group }}`
- Install kubelogin (required for AAD-enabled AKS clusters): `azure/use-kubelogin@v1` with `skip-cache: true`
- Convert kubeconfig to use kubelogin: `kubelogin convert-kubeconfig -l workloadidentity`
- Build and push the container image using ACR Tasks: `az acr build --registry ${{ secrets.AZURE_ACR_NAME }} --image spring-petclinic:${{ github.sha }} .`
- Update the container image reference in manifests to use `bbashreg19959.azurecr.io/spring-petclinic:${{ github.sha }}`
- Run: `kubectl apply -f deploy/kubernetes/ -n ${{ inputs.namespace }}`
- After applying manifests, annotate each Deployment with the run URL and workflow name:
  `kubectl annotate deployment --all -n ${{ inputs.namespace }} aks-project/pipeline-run-url=${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }} "aks-project/pipeline-workflow=${{ github.workflow }}" --overwrite`

## Naming Conventions
- PR title: "[AKS Desktop] Add deployment pipeline for spring-petclinic"
- Commit messages: prefixed with "deploy:"
- K8s resource names: kebab-case, prefixed with `spring-petclinic`

## Validation Steps
- Run `kubectl apply --dry-run=client -f deploy/kubernetes/` to validate manifests
- Validate Dockerfile builds cleanly
- Ensure all manifests target namespace: `my-dev-backend`
- Verify service type matches: `ClusterIP`

## Definition of Done
- Dockerfile generated then fixed
- Image builds successfully and is tagged **1.0**
- Kubernetes manifests generated in `/deploy/kubernetes/`
- GitHub Actions deployment workflow generated at `.github/workflows/deploy-to-aks.yml`
- All validation steps pass
- Checklist is complete
