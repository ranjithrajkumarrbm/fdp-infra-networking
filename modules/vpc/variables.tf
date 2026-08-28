variable "prefix" {
  description = "Prefix applied to the name of every resource, e.g. \"fdp-dev-euw2\"."
  type        = string
}

variable "region" {
  description = "AWS region the VPC is created in. Used to build gateway VPC endpoint service names."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of AZs to spread subnets across. One subnet of each tier is created per AZ."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Provide at least two availability zones."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ). Host the NAT gateways and internet-facing load balancers."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for the private application subnets (one per AZ). Used for EKS worker nodes / pods."
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for the private database subnets (one per AZ). Used for PostgreSQL (RDS)."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateway(s) and default routes for the private application subnets."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "When true, create a single shared NAT gateway instead of one per AZ."
  type        = bool
  default     = false
}

variable "enable_db_internet_access" {
  description = "When true, give the private database subnets an outbound default route via NAT. Off by default (isolated)."
  type        = bool
  default     = false
}

variable "enable_dns_support" {
  description = "Enable DNS resolution in the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC (required for many endpoint / EKS features)."
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster these subnets will host. When set, subnets get the kubernetes.io/cluster/<name> discovery tag. Leave empty to skip."
  type        = string
  default     = ""
}

variable "postgres_port" {
  description = "TCP port PostgreSQL listens on."
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
