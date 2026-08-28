###############################################################################
# VPC
###############################################################################

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "ARN of the VPC."
  value       = aws_vpc.this.arn
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "availability_zones" {
  description = "Availability zones the subnets are spread across."
  value       = var.availability_zones
}

###############################################################################
# Subnets
###############################################################################

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets."
  value       = aws_subnet.public[*].cidr_block
}

output "private_app_subnet_ids" {
  description = "IDs of the private application (EKS) subnets."
  value       = aws_subnet.private_app[*].id
}

output "private_app_subnet_cidrs" {
  description = "CIDR blocks of the private application (EKS) subnets."
  value       = aws_subnet.private_app[*].cidr_block
}

output "private_db_subnet_ids" {
  description = "IDs of the private database (PostgreSQL) subnets."
  value       = aws_subnet.private_db[*].id
}

output "private_db_subnet_cidrs" {
  description = "CIDR blocks of the private database (PostgreSQL) subnets."
  value       = aws_subnet.private_db[*].cidr_block
}

###############################################################################
# NAT / Route tables
###############################################################################

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways."
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "Elastic IPs attached to the NAT gateways."
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_app_route_table_ids" {
  description = "IDs of the private application route tables."
  value       = aws_route_table.private_app[*].id
}

output "private_db_route_table_ids" {
  description = "IDs of the private database route tables."
  value       = aws_route_table.private_db[*].id
}

###############################################################################
# Security groups
###############################################################################

output "eks_security_group_id" {
  description = "Security group for the EKS control plane / worker nodes."
  value       = aws_security_group.eks.id
}

output "postgres_security_group_id" {
  description = "Security group for PostgreSQL."
  value       = aws_security_group.postgres.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group for interface VPC endpoints."
  value       = aws_security_group.vpc_endpoints.id
}

###############################################################################
# VPC endpoints
###############################################################################

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 gateway VPC endpoint."
  value       = aws_vpc_endpoint.s3.id
}

output "dynamodb_vpc_endpoint_id" {
  description = "ID of the DynamoDB gateway VPC endpoint."
  value       = aws_vpc_endpoint.dynamodb.id
}
