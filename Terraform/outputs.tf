# ── Cluster ──────────────────────────────────────────────────────────────────

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks.cluster_version
}

# ── Networking ───────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

# ── Quick-start ───────────────────────────────────────────────────────────────

output "configure_kubectl" {
  description = "Run this after apply to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "next_steps" {
  description = "What to do after terraform apply"
  value = <<-EOT

    ── Step 1: configure kubectl ──────────────────────────────────────────────
    aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}

    ── Step 2: verify the sealed-secrets key was imported ────────────────────
    kubectl get secret -n kube-system sealed-secrets-imported-key

    ── Step 3: verify nodes are ready ────────────────────────────────────────
    kubectl get nodes

    ── Step 4: install Argo CD ───────────────────────────────────────────────
    kubectl create namespace argocd
    kubectl apply -n argocd \
      -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    ── Step 5: apply root app (GitOps takes over) ────────────────────────────
    kubectl apply -f root-app/my-application.yaml

    ── Step 6: get Argo CD admin password ────────────────────────────────────
    kubectl get secret argocd-initial-admin-secret -n argocd \
      -o jsonpath="{.data.password}" | base64 -d

  EOT
}
