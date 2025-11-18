data "aws_availability_zones" "available" {}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags       = { Name = "${var.cluster_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.cluster_name}-igw" }
}

# --------------------------
# PUBLIC SUBNETS (MULTI-AZ)
# --------------------------
resource "aws_subnet" "public" {
  for_each = {
    az1 = {
      cidr = var.public_subnet_cidrs[0]
      az   = data.aws_availability_zones.available.names[0]
    }
    az2 = {
      cidr = var.public_subnet_cidrs[1]
      az   = data.aws_availability_zones.available.names[1]
    }
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-${each.value.cidr}"
  }
}

# --------------------------
# PRIVATE SUBNETS (MULTI-AZ)
# --------------------------
resource "aws_subnet" "private" {
  for_each = {
    az1 = {
      cidr = var.private_subnet_cidrs[0]
      az   = data.aws_availability_zones.available.names[0]
    }
    az2 = {
      cidr = var.private_subnet_cidrs[1]
      az   = data.aws_availability_zones.available.names[1]
    }
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${var.cluster_name}-private-${each.value.cidr}"
  }
}

# --------------------------
# PUBLIC ROUTE TABLE
# --------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.cluster_name}-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# --------------------------
# SECURITY GROUP FOR NODES
# --------------------------
resource "aws_security_group" "eks_nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-nodes-sg" }
}

