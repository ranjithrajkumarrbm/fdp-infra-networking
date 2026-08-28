###############################################################################
# VPC networking module
#
#   * 1x VPC
#   * 2x public subnets        - Internet Gateway + NAT Gateway(s)
#   * 2x private "app" subnets  - EKS worker nodes / pods (egress via NAT)
#   * 2x private "db" subnets   - PostgreSQL / RDS (isolated by default)
#   * Route tables + associations for every tier
#   * Security groups for EKS and PostgreSQL
#   * Gateway VPC endpoints for S3 and DynamoDB
###############################################################################

locals {
  az_count = length(var.availability_zones)

  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  # kubernetes.io/cluster/<name> discovery tag, only when a cluster name is given.
  eks_discovery_tags = var.eks_cluster_name != "" ? {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  } : {}

  # All route tables that should carry the S3 / DynamoDB gateway endpoint routes.
  gateway_endpoint_route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private_app[*].id,
    aws_route_table.private_db[*].id,
  )
}

###############################################################################
# VPC + Internet Gateway
###############################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(var.tags, {
    Name = "${var.prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-igw"
  })
}

###############################################################################
# Subnets
###############################################################################

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, local.eks_discovery_tags, {
    Name                     = "${var.prefix}-public-${var.availability_zones[count.index]}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, local.eks_discovery_tags, {
    Name                              = "${var.prefix}-private-app-${var.availability_zones[count.index]}"
    Tier                              = "private-app"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "private_db" {
  count = length(var.private_db_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-db-${var.availability_zones[count.index]}"
    Tier = "private-db"
  })
}

###############################################################################
# NAT Gateways (in the public subnets)
###############################################################################

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.prefix}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.prefix}-natgw-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

###############################################################################
# Route tables - Public
###############################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# Route tables - Private application (EKS), one per AZ
###############################################################################

resource "aws_route_table" "private_app" {
  count = local.az_count

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-app-rt-${count.index + 1}"
    Tier = "private-app"
  })
}

resource "aws_route_table_association" "private_app" {
  count = length(aws_subnet.private_app)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

###############################################################################
# Route tables - Private database (PostgreSQL), one per AZ
# Isolated by default; add a NAT default route only if enable_db_internet_access.
###############################################################################

resource "aws_route_table" "private_db" {
  count = local.az_count

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_db_internet_access && var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-db-rt-${count.index + 1}"
    Tier = "private-db"
  })
}

resource "aws_route_table_association" "private_db" {
  count = length(aws_subnet.private_db)

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[count.index].id
}

###############################################################################
# Security groups
###############################################################################

# --- EKS control plane / worker nodes ----------------------------------------
resource "aws_security_group" "eks" {
  name        = "${var.prefix}-eks-sg"
  description = "EKS control plane and worker node traffic"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-eks-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks_self" {
  security_group_id            = aws_security_group.eks.id
  referenced_security_group_id = aws_security_group.eks.id
  ip_protocol                  = "-1"
  description                  = "All traffic between members of the EKS security group"
}

resource "aws_vpc_security_group_egress_rule" "eks_all" {
  security_group_id = aws_security_group.eks.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound"
}

# --- PostgreSQL ------------------------------------------------------------- #
resource "aws_security_group" "postgres" {
  name        = "${var.prefix}-postgres-sg"
  description = "PostgreSQL access from the EKS application tier"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-postgres-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_eks" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.eks.id
  from_port                    = var.postgres_port
  to_port                      = var.postgres_port
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from the EKS application tier"
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_db_subnets" {
  count = local.az_count

  security_group_id = aws_security_group.postgres.id
  cidr_ipv4         = var.private_db_subnet_cidrs[count.index]
  from_port         = var.postgres_port
  to_port           = var.postgres_port
  ip_protocol       = "tcp"
  description       = "PostgreSQL intra-db-subnet (replication / management)"
}

resource "aws_vpc_security_group_egress_rule" "postgres_all" {
  security_group_id = aws_security_group.postgres.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound"
}

# --- VPC endpoints (reserved for future interface endpoints) --------------- #
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.prefix}-vpce-sg"
  description = "HTTPS from within the VPC to interface VPC endpoints"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-vpce-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  security_group_id = aws_security_group.vpc_endpoints.id
  cidr_ipv4         = aws_vpc.this.cidr_block
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from within the VPC"
}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoints_all" {
  security_group_id = aws_security_group.vpc_endpoints.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound"
}

###############################################################################
# Gateway VPC endpoints - S3 and DynamoDB
###############################################################################

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.gateway_endpoint_route_table_ids

  tags = merge(var.tags, {
    Name = "${var.prefix}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.gateway_endpoint_route_table_ids

  tags = merge(var.tags, {
    Name = "${var.prefix}-dynamodb-endpoint"
  })
}
