# Lucidity Assignment — AKS Hello World

End-to-end Kubernetes deployment on Azure AKS with Terraform, Helm, Prometheus, Grafana, and GitHub Actions.

## Repository Structure

```
.
├── app/                          # Python FastAPI microservice
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── terraform/                    # IaC — modular AKS cluster
│   ├── main.tf                   # root — calls local wrapper modules
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── resource_group/       # Azure resource group
│       ├── network/              # wrapper → Azure/network/azurerm (public)
│       └── aks/                  # wrapper → Azure/aks/azurerm (public)

├── helm/
│   └── hello-world/              # Helm chart for the service
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── servicemonitor.yaml
│           └── hpa.yaml
├── monitoring/
│   ├── prometheus-values.yaml    # kube-prometheus-stack overrides
│   ├── hello-world-dashboard.yaml # Grafana dashboard ConfigMap for the app
│   └── install.sh                # One-shot monitoring installer
└── .github/workflows/
    └── ci-cd.yaml                # GitHub Actions pipeline
```

## Prerequisites

| Tool | Minimum version |
|------|----------------|
| Terraform | 1.5 |
| Azure CLI (`az`) | 2.50 |
| kubectl | 1.29 |
| Helm | 3.14 |
| Docker | 20+ |

Log in to Azure before running anything:

```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
```

---

## 1 — Provision infrastructure with Terraform

```bash
cd terraform

# Copy and fill in your values
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan -out tfplan
terraform apply tfplan
```

Terraform creates in order:
1. Resource group (`lucidity-demo-rg`)
2. VNet + subnet (`192.168.0.0/16`)
3. AKS cluster (`lucidity-demo-aks`, k8s 1.33, 1 node `Standard_D2alds_v7`)

Outputs printed after apply:
```
aks_cluster_name   = "lucidity-demo-aks"
kubeconfig_command = "az aks get-credentials ..."
```

Connect kubectl:
```bash
az aks get-credentials --resource-group lucidity-demo-rg --name lucidity-demo-aks
kubectl get nodes
```

### Key Terraform variables (`terraform.tfvars`)

| Variable | Default | Description |
|----------|---------|-------------|
| `subscription_id` | — | Your Azure subscription ID |
| `prefix` | `lucidity-demo` | Prefix for all resource names |
| `location` | `eastus2` | Azure region |
| `kubernetes_version` | `1.33` | AKS Kubernetes version |
| `node_count` | `2` | Number of nodes |
| `node_vm_size` | `Standard_D2alds_v7` | VM size per node |
| `vnet_address_space` | `192.168.0.0/16` | VNet CIDR |
| `aks_subnet_prefix` | `192.168.1.0/24` | Subnet CIDR |

---

## 2 — Build & run the microservice locally

```bash
cd app
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8080
# GET http://localhost:8080/         → {"message":"Hello World"}
# GET http://localhost:8080/health   → {"status":"ok"}
# GET http://localhost:8080/metrics  → Prometheus metrics
```

Or with Docker:
```bash
docker build -t hello-world ./app
docker run -p 8080:8080 hello-world
```

---

## 3 — Build and push Docker image to Docker Hub

The image is hosted publicly at `ganeshtn91/lucidity-demo-hello-app`.

```bash
docker login --username ganeshtn91

docker buildx build \
  --platform linux/amd64 \
  -t ganeshtn91/lucidity-demo-hello-app:latest \
  --push ./app
```

---

## 4 — Deploy with Helm

```bash
helm upgrade --install hello-world ./helm/hello-world \
  --namespace default \
  --set image.repository=ganeshtn91/lucidity-demo-hello-app \
  --set image.tag=latest \
  --set image.pullPolicy=Always \
  --set serviceMonitor.enabled=true \
  --set replicaCount=1

# Get external IP
kubectl get svc hello-world
curl http://<EXTERNAL_IP>/
```

---

## 5 — Install Prometheus & Grafana

```bash
cd monitoring
chmod +x install.sh
./install.sh
```

This deploys `kube-prometheus-stack` into the `monitoring` namespace and exposes Grafana via a LoadBalancer IP.

**Default Grafana credentials:** `admin / admin`

After Grafana is up, the **Hello World FastAPI** dashboard is provisioned automatically via `monitoring/hello-world-dashboard.yaml` — no manual import needed.

To apply the dashboard ConfigMap:
```bash
kubectl apply -f monitoring/hello-world-dashboard.yaml
```

It appears in Grafana under **Dashboards → Hello World FastAPI** within ~15 seconds.

For additional cluster-level dashboards, import these IDs manually via **Dashboards → New → Import**, selecting **Prometheus** as the datasource:

| ID | Dashboard |
|----|-----------|
| 6417 | Kubernetes Cluster |
| 1860 | Node Exporter Full |

The Hello World `ServiceMonitor` is included in the Helm chart and automatically tells Prometheus to scrape `/metrics` on every pod.

---

## 6 — GitHub Actions CI/CD (optional)

The pipeline (`.github/workflows/ci-cd.yaml`) triggers on every push to `main`:

1. **Build & push** — builds the Docker image for `linux/amd64` and pushes to ACR with the commit SHA tag
2. **Deploy** — authenticates to Azure, sets AKS context, runs `helm upgrade --install`

### Required GitHub secret

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username (`ganeshtn91`) |
| `DOCKERHUB_TOKEN` | Docker Hub access token (generate at hub.docker.com → Account Settings → Security) |
| `AZURE_CREDENTIALS` | Output of `az ad sp create-for-rbac --sdk-auth` |

```bash
az ad sp create-for-rbac \
  --name lucidity-github-actions \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/lucidity-demo-rg \
  --sdk-auth
```

Copy the JSON output → GitHub repo → **Settings → Secrets → New secret** → name it `AZURE_CREDENTIALS`.

---

## Tear down (stop all billing)

```bash
cd terraform
terraform destroy
```

Destroys everything: AKS, ACR, VNet, resource group. Cost drops to $0.

## Recreate from scratch

```bash
cd terraform && terraform apply
az aks get-credentials --resource-group lucidity-demo-rg --name lucidity-demo-aks
helm upgrade --install hello-world ./helm/hello-world \
  --set image.repository=ganeshtn91/lucidity-demo-hello-app \
  --set image.tag=latest --set image.pullPolicy=Always \
  --set serviceMonitor.enabled=true --set replicaCount=1
cd ../monitoring && ./install.sh
```

---

## Known Limitations

- **Terraform state** is local by default. For a team setup, configure a remote backend (Azure Blob Storage) in `terraform/main.tf`.
- **Grafana password** is hardcoded to `admin` — change it before any real use.
- **TLS / Ingress** is not configured. The app and Grafana are exposed via Azure LoadBalancer public IPs.
- Two node cluster (`node_count=2`) is used. Scale down to 1 node to minimise cost (`node_count=1` in `terraform.tfvars` then `terraform apply`).
- **Grafana** is pinned to `11.6.1` (instead of the latest `13.x`) due to two bugs in the `kube-prometheus-stack` defaults: `k8s-sidecar:2.6.0` has a health-server port conflict (`EADDRINUSE`) that causes the sidecar container to crash-loop, and Grafana 13 introduced k8s-backed unified dashboard storage that repeatedly times out against the API server in this single-tenant setup. Pinning to `11.6.1` with sidecar `1.28.0` resolves both issues.
