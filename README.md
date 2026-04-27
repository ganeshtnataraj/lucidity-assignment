# Lucidity Assignment — AKS Hello World

Deploy a FastAPI "Hello World" microservice on Azure AKS with full observability and CI/CD automation.

**Stack:** Terraform · Kubernetes · Helm · Prometheus · Grafana · GitHub Actions

---

## Architecture

```
GitHub Actions
  ├── Build & push Docker image → Docker Hub
  ├── Deploy Prometheus + Grafana (monitoring namespace)
  └── Deploy Hello World app via Helm (default namespace)
          │
          ▼
    Azure AKS Cluster (2 nodes, k8s 1.33)
    ├── hello-world (FastAPI, port 8080)
    │   ├── GET /           → {"message": "Hello World"}
    │   ├── GET /health     → {"status": "ok"}
    │   └── GET /metrics    → Prometheus metrics
    └── Monitoring
        ├── Prometheus  (scrapes /metrics every 15s)
        └── Grafana     (pre-built dashboard, LoadBalancer IP)
```

---

## Repo Structure

```
app/                    FastAPI microservice + Dockerfile
terraform/              AKS cluster provisioning (IaC)
  └── modules/          resource_group / network / aks
helm/hello-world/       Kubernetes manifests (Deployment, Service, HPA, ServiceMonitor)
monitoring/             Prometheus + Grafana setup + pre-built dashboard
.github/workflows/      CI/CD and Terraform pipelines
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | 1.5+ |
| Azure CLI | 2.50+ |
| kubectl | 1.29+ |
| Helm | 3.14+ |
| Docker | 20+ |

```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
```

---

## Deploy

> **Everything is automated via GitHub Actions. No manual steps needed after the one-time setup below.**

### One-time setup (do this once)

1. Add the required GitHub secrets (see [CI/CD section](#cicd-github-actions) below).
2. Run `terraform.yml` first — this provisions the AKS cluster.
3. Once the cluster is ready, run `ci-cd.yml` — this builds and deploys everything.

That's it. The pipelines handle Docker build, Helm deploy, and monitoring setup.

### Pipeline execution order

```
Step 1 — Run terraform.yml (action: apply)
         Provisions AKS cluster on Azure

Step 2 — Run ci-cd.yml
         Builds image → deploys Prometheus/Grafana → deploys Hello World app
```

### Tear down

Run `terraform.yml` with `action: destroy` to delete all Azure resources.

---

## CI/CD (GitHub Actions)

Both workflows are triggered manually via **Actions → Run workflow**.

### `terraform.yml` — Infrastructure

Choose `apply` or `destroy` when running.

```
apply  →  Stage 1: fmt + validate
       →  Stage 2: plan  (saves tfplan artifact)
       →  Stage 3: apply (provisions AKS cluster on Azure)

destroy → tears down all Azure resources in one step
```

> On first run it also bootstraps the remote Terraform state bucket in Azure Blob Storage.

### `ci-cd.yml` — Build & Deploy

Runs three jobs in sequence (each waits for the previous to succeed):

```
Job 1 — build-push:        Build Docker image → push to Docker Hub
Job 2 — deploy-monitoring: Deploy Prometheus + Grafana via Helm, apply Grafana dashboard
Job 3 — deploy:            Helm deploy the Hello World app, verify rollout
```

### Required GitHub Secrets

| Secret | Used by | How to get it |
|--------|---------|--------------|
| `DOCKERHUB_USERNAME` | ci-cd.yml | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | ci-cd.yml | Docker Hub → Account Settings → Security |
| `AZURE_CREDENTIALS` | both | JSON from `az ad sp create-for-rbac` (see below) |
| `AZURE_SUBSCRIPTION_ID` | terraform.yml | Your Azure subscription ID |

**Create an Azure Service Principal** — this gives GitHub Actions a dedicated identity to authenticate with Azure (create/destroy AKS, run deployments). Run this once from your local terminal:

```bash
az ad sp create-for-rbac \
  --name lucidity-github-actions \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/lucidity-demo-rg \
  --sdk-auth
```

Copy the entire JSON output → GitHub repo → **Settings → Secrets → New secret → `AZURE_CREDENTIALS`**

---

## Notes

- Grafana is pinned to `10.4.3` (sidecar `1.27.5`) — newer versions have a port conflict bug that causes crash-loops in this setup.
- Grafana password is hardcoded to `admin` — change before any real use.
- No TLS/Ingress — app and Grafana are exposed via Azure LoadBalancer public IPs.
- IPs are printed in the `ci-cd.yml` pipeline output — Grafana IP in **Job 2 (deploy-monitoring)** under the "Print Grafana LoadBalancer IP" step, and the app IP in **Job 3 (deploy)** under the "Verify rollout" step via `kubectl get svc hello-world`.
