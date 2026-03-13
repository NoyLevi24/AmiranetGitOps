# AmiranetGitOps 🚀
 
> GitOps repository for the Amiranet AI exam simulation application.  
> For the application source code, see 👉 [AmiranetCode](https://github.com/NoyLevi24/AmiranetCode)
 
---
 
## Overview
 
This repository is the **single source of truth** for all Kubernetes manifests and configurations. All changes to the cluster are made exclusively through Git — no manual `kubectl apply` commands. Argo CD continuously reconciles the cluster state with what is defined here.
 
---
 
## GitOps Principles
 
| Principle | Implementation |
|---|---|
| Declarative configuration | All resources defined as YAML manifests |
| Git as single source of truth | No manual cluster changes — Git only |
| Continuous reconciliation | Argo CD auto-syncs on every commit |
| Secret management in Git | Sealed Secrets controller encrypts secrets before committing |
 
---
 
## Repository Structure
### 3-Level App of Apps Pattern
 
```
.
├── root-app/                        # Level 1 — Root Application
│   └── my-application.yaml          # App of Apps entry point
│
├── my-app-list/                     # Level 2 — Child Applications
│   ├── amiranet.yaml                # Amiranet app
│   ├── rollouts-controller.yaml     # Argo Rollouts controller
│   ├── sealed-controller.yaml       # Sealed Secrets controller
|   └── amiranet-appset/             # ApplicationSet — multi-environment
│       └── my-values/
│           ├── app-version/
│           │   ├── qa-values.yaml
│           │   ├── staging-values.yaml
│           │   └── prod-values.yaml
│           ├── settings/
│           └── replicas/
│
├── manifests/                       # Level 3 — Workload Manifests
|   ├── rollouts-controller.yaml     # Argo Rollouts controller manifests
│   ├── sealed-controller.yaml       # Sealed Secrets controller manifests
│   └── amiranet/                    # Amiranet manifests
│       ├── rollout.yaml             # Argo Rollout (canary strategy)
│       ├── service.yaml             # Stable + Canary services
│       ├── traefik-service.yaml     # Weighted traffic routing
│       ├── ingress-route.yaml       # Traefik IngressRoute
│       └── gemini-api-key-encrypted.yaml  # Sealed Secret
│    
│   
│
└── patch-argocd-cm.yaml             # Argo CD config patch
```
 
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
 
## Deployment Strategy
 
**Canary Rollout** via Argo Rollouts:
 
```
New version deployed → 30% traffic → pause
                     → 60% traffic → pause
                     → 100% traffic → pause
```
 
Traffic is split between a **stable** and a **canary** service, managed by a Traefik weighted service.
 
---
 
## Secret Management
 
Secrets are encrypted using the **Sealed Secrets** controller. The encrypted `SealedSecret` YAML is safe to commit to Git. Only the in-cluster controller can decrypt it.
 
```bash
# Encrypt a new secret
kubectl create secret generic my-secret --from-literal=KEY=VALUE \
  --dry-run=client -o yaml | kubeseal -o yaml > encrypted-secret.yaml
```
 
---
 
## Multi-Environment Promotion
 
Environments are managed by an **ApplicationSet** using Helm value hierarchies. Each environment has its own values files that override shared defaults. Promotion of a new image version to the qa environment is triggered by the CI pipeline in [AmiranetCode](https://github.com/NoyLevi24/AmiranetCode) — which automatically commits the new image version to the relevant `qa-values.yaml` file, causing Argo CD to detect the change and sync.

### Promotion Between Environments
 
**Workflow:** `.github/workflows/promote.yaml`
 
Promotes a version between environments by copying the relevant values files:
 
```
QA → Staging → Production
```
*and vise versa*

Supports optional promotion of image version, application settings, and replica count independently.
 
---
