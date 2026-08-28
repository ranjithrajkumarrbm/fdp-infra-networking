output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private application (EKS) subnets."
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of the private database (PostgreSQL) subnets."
  value       = module.vpc.private_db_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT gateways."
  value       = module.vpc.nat_gateway_public_ips
}

output "eks_security_group_id" {
  description = "Security group for EKS control plane / nodes."
  value       = module.vpc.eks_security_group_id
}

output "postgres_security_group_id" {
  description = "Security group for PostgreSQL."
  value       = module.vpc.postgres_security_group_id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 gateway VPC endpoint."
  value       = module.vpc.s3_vpc_endpoint_id
}

output "dynamodb_vpc_endpoint_id" {
  description = "ID of the DynamoDB gateway VPC endpoint."
  value       = module.vpc.dynamodb_vpc_endpoint_id
}

output "resource_prefix" {
  description = "Prefix applied to all resource names."
  value       = local.prefix
}
