# ── Data sources ─────────────────────────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(
    data.aws_availability_zones.available.names, 0, 2
  )

  # /16 VPC -> each subnet gets a /24 (256 IPs)
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 100)]
}

# ── VPC ──────────────────────────────────────────────────────────────────────

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# ── EKS ──────────────────────────────────────────────────────────────────────

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    main = {
      name = "${var.cluster_name}-nodes"

      instance_types = var.node_instance_types
      disk_size      = var.node_disk_size

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      subnet_ids = module.vpc.private_subnets

      labels = {
        Environment = var.environment
      }
    }
  }

  cluster_addons = {
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    vpc-cni            = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }
}

# ── Sealed Secrets — import the local key into the cluster ───────────────────
#
# Sealed Secrets encrypts using the controller's RSA key pair.
# If you encrypted secrets locally, the EKS controller MUST use the same key —
# otherwise it will generate a new one and fail to decrypt your existing secrets.
#
# This resource imports your local key as a Kubernetes TLS secret in kube-system
# BEFORE Argo CD installs the sealed-secrets controller.
# The controller auto-discovers secrets labelled sealedsecrets.bitnami.com/sealed-secrets-key=active.
#
# How to get the values:
#   kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key \
#     -o jsonpath='{.items[0].data.tls\.key}' | base64 -d > sealed-secrets.key
#   kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key \
#     -o jsonpath='{.items[0].data.tls\.crt}' | base64 -d > sealed-secrets.crt
#
# Then put the PEM content in terraform.tfvars:
#   sealed_secrets_key  = file("sealed-secrets.key")
#   sealed_secrets_cert = file("sealed-secrets.crt")

resource "kubernetes_namespace" "kube_system_ensure" {
  metadata { name = "kube-system" }

  # kube-system already exists — ignore if it's there
  lifecycle { ignore_changes = [metadata] }

  depends_on = [module.eks]
}

resource "kubernetes_secret" "sealed_secrets_key" {
  metadata {
    name      = "sealed-secrets-imported-key"
    namespace = "kube-system"

    labels = {
      # This label tells the controller to use this secret as its signing key
      "sealedsecrets.bitnami.com/sealed-secrets-key" = "active"
    }
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.key" = var.sealed_secrets_key
    "tls.crt" = var.sealed_secrets_cert
  }

  depends_on = [module.eks]
}
