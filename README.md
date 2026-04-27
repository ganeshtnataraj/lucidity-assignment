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

### 1. Provision Infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in subscription_id
terraform init
terraform plan -out tfplan
terraform apply tfplan

# Connect kubectl
az aks get-credentials --resource-group lucidity-demo-rg --name lucidity-demo-aks
kubectl get nodes
```

Key variables in `terraform.tfvars`:

| Variable | Default | Description |
|----------|---------|-------------|
| `subscription_id` | — | Azure subscription ID |
| `prefix` | `lucidity-demo` | Prefix for resource names |
| `location` | `eastus2` | Azure region |
| `node_count` | `2` | AKS node count |
| `node_vm_size` | `Standard_D2alds_v7` | VM size |

### 2. Build & Push Docker Image

```bash
docker login --username ganeshtn91
docker buildx build --platform linux/amd64 \
  -t ganeshtn91/lucidity-demo-hello-app:latest --push ./app
```

### 3. Deploy the App

```bash
helm upgrade --install hello-world ./helm/hello-world \
  --namespace default \
  --set image.tag=latest \
  --set serviceMonitor.enabled=true

kubectl get svc hello-world   # grab EXTERNAL_IP
curl http://<EXTERNAL_IP>/
```

### 4. Install Monitoring

```bash
cd monitoring && ./install.sh
kubectl apply -f monitoring/hello-world-dashboard.yaml
```

Grafana opens at the LoadBalancer IP — login `admin / admin`.
The **Hello World FastAPI** dashboard appears automatically under Dashboards.

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

| Secret | How to get it |
|--------|--------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub → Account Settings → Security |
| `AZURE_CREDENTIALS` | See below |

```bash
az ad sp create-for-rbac \
  --name lucidity-github-actions \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/lucidity-demo-rg \
  --sdk-auth
```

Copy the JSON → GitHub repo → **Settings → Secrets → New secret → `AZURE_CREDENTIALS`**

---

## Tear Down

```bash
cd terraform && terraform destroy
```

Deletes all Azure resources (AKS, VNet, resource group). Cost drops to $0.

---

## Notes

- Grafana is pinned to `10.4.3` (sidecar `1.27.5`) — newer versions have a port conflict bug that causes crash-loops in this setup.
- Grafana password is hardcoded to `admin` — change before any real use.
- No TLS/Ingress — app and Grafana are exposed via Azure LoadBalancer public IPs.
