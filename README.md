# AmiranetGitOps 🚀

> GitOps repository for the Amiranet AI exam simulation application.  
> For the application source code, see 👉 [AmiranetCode](https://github.com/NoyLevi24/AmiranetCode)

---

## Architecture Overview

This repository is the **single source of truth** for all Kubernetes manifests and configurations. All changes to the cluster are made exclusively through Git — no manual `kubectl apply` commands. Argo CD continuously reconciles the cluster state with what is defined here.
 
---

```mermaid
flowchart TB
    classDef devStyle    fill:#e0e7ff,stroke:#4f46e5,stroke-width:2px,color:#1e1b4b,font-weight:bold
    classDef ciStyle     fill:#ffedd5,stroke:#ea580c,stroke-width:2px,color:#7c2d12,font-weight:bold
    classDef tfStyle     fill:#dcfce7,stroke:#16a34a,stroke-width:2px,color:#14532d,font-weight:bold
    classDef argoStyle   fill:#f3e8ff,stroke:#9333ea,stroke-width:2px,color:#581c87,font-weight:bold
    classDef appStyle    fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#1e3a8a,font-weight:bold
    classDef obsStyle    fill:#fef9c3,stroke:#ca8a04,stroke-width:2px,color:#713f12,font-weight:bold
    classDef envStyle    fill:#fce7f3,stroke:#db2777,stroke-width:2px,color:#831843,font-weight:bold
    classDef secretStyle fill:#fee2e2,stroke:#dc2626,stroke-width:2px,color:#7f1d1d,font-weight:bold

    subgraph DEV["  🧑‍💻  Developer"]
        CODE["📦 AmiranetCode\nFlask · Gemini API"]
        GITOPS_REPO["📁 AmiranetGitOps\nHelm · Manifests"]
    end
    style DEV fill:#eef2ff,stroke:#6366f1,stroke-width:2px,color:#312e81

    subgraph CI["  ⚙️  GitHub Actions"]
        BUILD["🐳 Build & push image\ndocker.io/noylevi/amiranet"]
        UPDATE["✏️ Update qa-values.yaml\nnew imageVersion tag"]
    end
    style CI fill:#fff7ed,stroke:#f97316,stroke-width:2px,color:#7c2d12

    subgraph AWS["  ☁️  AWS — "us-east-1""]
        subgraph TF["Terraform"]
            VPC["🌐 VPC\npublic + private subnets\nNAT Gateway"]
            EKS["⎈ EKS Cluster\nManaged node group\nt3a.medium × 2"]
        end
        style TF fill:#dcfce7,stroke:#22c55e,stroke-width:1.5px,color:#14532d
    end
    style AWS fill:#f0fdf4,stroke:#16a34a,stroke-width:2px,color:#14532d

    subgraph K8S["  ⎈  Kubernetes"]
        subgraph WAVES["Sync Waves"]
            W1["🔐 Sealed Secrets\nwave 1"]
            W2["🔄 Argo Rollouts\nwave 2"]
            W3["🚀 Argo CD root app\nwave 3"]
            W4["📋 ApplicationSet\nwave 4"]
        end
        style WAVES fill:#f3e8ff,stroke:#a855f7,stroke-width:1.5px,color:#581c87

        subgraph ENVS["Environments"]
            QA["🟡 qa\neu · 1 replica"]
            STAGING["🟠 staging\nus · 2 replicas"]
            PROD_EU["🔴 prod-eu\neu · 3 replicas"]
            PROD_US["🔴 prod-us\nus · 3 replicas"]
        end
        style ENVS fill:#fce7f3,stroke:#ec4899,stroke-width:1.5px,color:#831843

        subgraph APP["Application Stack (per namespace)"]
            ROLLOUT["🔀 Argo Rollout\ncanary 30% → 60% → 100%"]
            SVCS["⚖️ stable + canary\nServices"]
            TRAEFIK["🔀 TraefikService\nweighted routing"]
            INGRESS["🌍 IngressRoute"]
            SECRET["🔑 SealedSecret\nGEMINI_API_KEY"]
        end
        style APP fill:#dbeafe,stroke:#3b82f6,stroke-width:1.5px,color:#1e3a8a

        subgraph OBS["Observability"]
            PROM["📊 Prometheus\nServiceMonitor"]
            GRAFANA["📈 Grafana\nAmiranet dashboard"]
        end
        style OBS fill:#fef9c3,stroke:#eab308,stroke-width:1.5px,color:#713f12
    end
    style K8S fill:#faf5ff,stroke:#9333ea,stroke-width:2px,color:#581c87

    %% Developer flow
    CODE -->|"workflow_dispatch"| BUILD
    BUILD --> UPDATE
    UPDATE -->|"git push"| GITOPS_REPO

    %% Terraform
    GITOPS_REPO -->|"terraform apply"| VPC
    VPC --> EKS

    %% GitOps bootstrap
    GITOPS_REPO -->|"kubectl apply"| W3
    W3 --> W4
    W1 -.->|"wave order"| W2 -.->|"wave order"| W3

    %% ApplicationSet → envs
    W4 --> QA & STAGING & PROD_EU & PROD_US

    %% App stack
    QA --> ROLLOUT
    ROLLOUT --> SVCS --> TRAEFIK --> INGRESS
    SECRET -.->|"env var"| ROLLOUT

    %% Observability
    ROLLOUT --> PROM --> GRAFANA

    %% Apply styles
    class CODE,GITOPS_REPO devStyle
    class BUILD,UPDATE ciStyle
    class VPC,EKS tfStyle
    class W1,W2,W3,W4 argoStyle
    class QA,STAGING,PROD_EU,PROD_US envStyle
    class ROLLOUT,SVCS,TRAEFIK,INGRESS appStyle
    class SECRET secretStyle
    class PROM,GRAFANA obsStyle
```

---

## Repository Structure
### 3-Level App of Apps Pattern

```
.
├── root-app/                        # Level 1 — Root Application
│   └── my-application.yaml          # App of Apps entry point
│
├── my-app-list/                     # Level 2 — child applications
│   ├── sealed-controller.yaml       # Sealed Secrets controller WAVE1
│   ├── rollouts-controller.yaml     # Argo Rollouts controller WAVE2
│   ├── prometheus-stack.yaml        # Prometheus & Grafana WAVE3
|   └── amiranet-appset/             # ApplicationSet — multi-environment WAVE4
│
├── manifests/                       # Level 3 — workload manifests
│   ├── amiranet-appset/
│   │   ├── env-config/              # per-env config.json (region, type, chart)
│   │   │   ├── qa/
│   │   │   ├── staging/
│   │   │   └── prod/{eu,us}/
│   │   ├── my-chart/                # Helm chart
│   │   │   └── templates/
│   │   │       ├── rollout.yaml
│   │   │       ├── service.yaml
│   │   │       ├── traefik-service.yaml
│   │   │       ├── ingress-route.yaml
│   │   │       ├── servicemonitor.yaml
│   │   │       ├── grafana-dashboard.yaml
│   │   │       └── gemini-api-key-encrypted.yaml
│   │   └── my-values/               # Helm value overrides
│   │       ├── common-values.yaml
│   │       ├── app-version/         # qa / staging / prod
│   │       ├── replicas/            # 1 / 2 / 3
│   │       ├── settings/            # resource requests & limits
│   │       ├── env-type/            # non-prod / prod
│   │       ├── regions/             # eu / us
│   │       └── envs/                # per-env labels
│   ├── rollouts-controller/
│   └── sealed-controller/
│
├── terraform/                       # AWS infrastructure
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf                      # VPC + EKS modules
│   ├── outputs.tf
│   └── terraform.tfvars
│
└── .github/workflows/
    └── promote.yaml                 # QA → Staging → Prod promotion
```

---

## GitOps Principles

| Principle | Implementation |
|---|---|
| Declarative configuration | All resources defined as YAML / Helm |
| Git as single source of truth | No manual `kubectl apply` — Git only |
| Continuous reconciliation | Argo CD auto-syncs on every commit |
| Secret management | Sealed Secrets — encrypted at rest in Git |

---

## Applications Dependencies with Sync Waves
 
```
Root Application  (root-app/)
        │
        ├── sealed-controller      wave 1
        ├── rollouts-controller    wave 2
        └── amiranet               wave 3
                │
                └── Rollout + Services + Ingress + Secrets
```
 
Sync waves ensure dependencies are deployed in the correct order — the Sealed Secrets controller is ready before secrets are applied, and Argo Rollouts is ready before the Rollout resource is created.
 
---

## Environments

| Environment | Region | Type | Replicas | Prometheus |
|---|---|---|---|---|
| `qa` | eu | non-prod | 1 | ✗ |
| `staging` | us | non-prod | 2 | ✗ |
| `prod-eu` | eu | prod | 3 | ✓ |
| `prod-us` | us | prod | 3 | ✓ |

---

## Deployment Strategy

Traffic is split between **stable** and **canary** services via a Traefik weighted service. Argo Rollouts manages the promotion steps:

```
New version deployed → 30% canary traffic → pause (manual approval)
                     → 60% canary traffic → pause (manual approval)
                     → 100% stable        → pause (final confirmation)
```

---

## Multi-Environment Promotion

Promotion between environments is triggered via **GitHub Actions** (`workflow_dispatch`).

```
QA ──► Staging ──► Production
```

Promotion of a new image version to the qa environment is triggered by the CI pipeline in [AmiranetCode](https://github.com/NoyLevi24/AmiranetCode) — which automatically commits the new image version to the relevant `qa-values.yaml` file, causing Argo CD to detect the change and sync.

**Workflow:** `.github/workflows/promote.yaml`

Supports independent promotion of:
- Container image version (`promote_container`)
- Application settings — resource requests/limits (`promote_settings`)
- Replica count (`promote_replicas`)

---

## Infrastructure (Terraform)

Managed by Terraform using the official AWS community modules.

| Resource | Module | Notes |
|---|---|---|
| VPC | `terraform-aws-modules/vpc/aws` | 2 public + 2 private subnets, 1 NAT GW |
| EKS | `terraform-aws-modules/eks/aws` | Managed node group, cluster-admin for caller |
| Node group | — | `t3a.medium`, auto-scaling 1–4 nodes |
| Add-ons | — | CoreDNS, kube-proxy, VPC CNI, EBS CSI |

### First-time setup

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

After apply, configure `kubectl`:

```bash
aws eks update-kubeconfig --region "us-east-1" --name amiranet-cluster
```

Then bootstrap Argo CD and hand control to GitOps:

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl apply -f root-app/my-application.yaml
```

---

## Secret Management

Secrets are encrypted using the **Sealed Secrets** controller.  
The encrypted `SealedSecret` YAML is safe to commit to Git — only the in-cluster controller can decrypt it.

```bash
kubectl create secret generic gemini-api-key \
  --from-literal=GEMINI_API_KEY=YOUR_KEY \
  --dry-run=client -o yaml | kubeseal -o yaml > encrypted-secret.yaml
```

---

## Observability

The production environments expose a custom **Grafana dashboard** with:

| Metric | Type |
|---|---|
| Exams generated / failed | Counter |
| Gemini API call rate & error rate | Counter |
| Exam generation duration (avg, p95, p99) | Histogram |
| Active exams | Gauge |
| Flask process CPU & memory | Gauge |

Metrics are scraped by Prometheus via a `ServiceMonitor` (enabled only when `prometheusEnabled: true`).

---

## Sync Waves

```
Root Application
    │
    ├── 🔐 sealed-controller      wave 1   (secrets infrastructure first)
    ├── 🔄 rollouts-controller    wave 2   (deployment strategy second)
    └── 📋 amiranet-appset        wave 4   (application — all environments)
```
