###############################################################################
# Root configuration - calls the VPC module.
#
# Region is fixed to London (eu-west-2). A single `environment` variable
# selects between the "dev" and "prod" local config sets below, and every
# resource is named/tagged from a computed prefix:
#
#   prefix = "<app_name>-<env_name>-<region_short_name>"   e.g. fdp-dev-euw2
###############################################################################

variable "environment" {
  description = "Which local config set to deploy. One of: dev, prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be either \"dev\" or \"prod\"."
  }
}

locals {
  # ---- Fixed identity -------------------------------------------------------
  app_name = "fdp"
  region   = "eu-west-2" # London

  # Region -> short name lookup, used to build the resource prefix.
  region_short_names = {
    "eu-west-2" = "euw2"
  }
  region_short = local.region_short_names[local.region]

  # ---- Per-environment config sets ---------------------------------------- #
  # One block for dev, one for prod. Add keys here as the module grows.
  env_configs = {
    dev = {
      env_name = "dev"
      vpc_cidr = "10.0.0.0/16"

      availability_zones = ["eu-west-2a", "eu-west-2b"]

      public_subnet_cidrs      = ["10.0.0.0/24", "10.0.1.0/24"]
      private_app_subnet_cidrs = ["10.0.16.0/20", "10.0.32.0/20"] # EKS worker nodes / pods
      private_db_subnet_cidrs  = ["10.0.48.0/24", "10.0.49.0/24"] # PostgreSQL (RDS)

      enable_nat_gateway        = true
      single_nat_gateway        = true # one NAT GW to save cost in dev
      enable_db_internet_access = false

      eks_cluster_name = "fdp-dev-eks"
    }

    prod = {
      env_name = "prod"
      vpc_cidr = "10.1.0.0/16"

      availability_zones = ["eu-west-2a", "eu-west-2b"]

      public_subnet_cidrs      = ["10.1.0.0/24", "10.1.1.0/24"]
      private_app_subnet_cidrs = ["10.1.16.0/20", "10.1.32.0/20"] # EKS worker nodes / pods
      private_db_subnet_cidrs  = ["10.1.48.0/24", "10.1.49.0/24"] # PostgreSQL (RDS)

      enable_nat_gateway        = true
      single_nat_gateway        = false # one NAT GW per AZ for HA in prod
      enable_db_internet_access = false

      eks_cluster_name = "fdp-prod-eks"
    }
  }

  # Selected config for this run.
  env = local.env_configs[var.environment]

  # Prefix applied to every resource name in the module.
  prefix = "${local.app_name}-${local.env.env_name}-${local.region_short}"

  common_tags = {
    Application = local.app_name
    Environment = local.env.env_name
    Region      = local.region
    ManagedBy   = "terraform"
    Repository  = "fdp-infra-networking"
  }
}

module "vpc" {
  source = "./modules/vpc"

  prefix = local.prefix
  region = local.region

  vpc_cidr           = local.env.vpc_cidr
  availability_zones = local.env.availability_zones

  public_subnet_cidrs      = local.env.public_subnet_cidrs
  private_app_subnet_cidrs = local.env.private_app_subnet_cidrs
  private_db_subnet_cidrs  = local.env.private_db_subnet_cidrs

  enable_nat_gateway        = local.env.enable_nat_gateway
  single_nat_gateway        = local.env.single_nat_gateway
  enable_db_internet_access = local.env.enable_db_internet_access

  eks_cluster_name = local.env.eks_cluster_name

  tags = local.common_tags
}
