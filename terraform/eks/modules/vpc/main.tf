# ① The VPC: your private network in AWS.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr # e.g. 10.0.0.0/16 (~65,000 addresses)
  enable_dns_support   = true         # AWS DNS works inside the VPC
  enable_dns_hostnames = true         # instances get DNS names; EKS needs this

  tags = {
    Name                                        = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ② Subnets: one private + one public per Availability Zone.

# Private subnets: worker nodes live here (not reachable from the internet).
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)      # one subnet per CIDR in the list
  vpc_id            = aws_vpc.main.id                       # inside the VPC from section ①
  cidr_block        = var.private_subnet_cidrs[count.index] # 1st, 2nd, 3rd range...
  availability_zone = var.availability_zones[count.index]   # ...in the 1st, 2nd, 3rd AZ

  tags = {
    Name                                        = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1" # internal load balancers go here
  }
}

# Public subnets: NAT gateway and internet-facing load balancers.
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # things launched here get a public IP

  tags = {
    Name                                        = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1" # internet-facing load balancers go here
  }
}

# ③ Internet Gateway: the VPC's two-way door to the internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id # attach it to our VPC

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# ④ NAT Gateways: one-way door so PRIVATE subnets can reach OUT to the internet.
# One per AZ (placed in that AZ's public subnet), so losing one AZ doesn't cut off the others.

# Fixed public IP address for each NAT gateway.
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id       # use the Elastic IP above
  subnet_id     = aws_subnet.public[count.index].id # NAT lives in a PUBLIC subnet

  tags = {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main] # NAT needs the IGW to exist first
}

# ⑤ Route tables: tell each subnet where internet traffic goes.

# Public: ONE shared table. Internet traffic → Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # "anywhere on the internet"
    gateway_id = aws_internet_gateway.main.id # → out through the IGW (two-way)
  }

  tags = {
    Name = "${var.cluster_name}-public"
  }
}

# Private: ONE table PER AZ. Internet traffic → that AZ's own NAT gateway.
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id # → out through NAT (one-way)
  }

  tags = {
    Name = "${var.cluster_name}-private-${count.index + 1}"
  }
}

# Associations: attach each subnet to its route table.
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
