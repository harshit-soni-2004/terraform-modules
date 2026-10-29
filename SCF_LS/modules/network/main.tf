locals {
  azs = var.availability_zones

  # 0-1 public, 2-3 dmz, 4-5 mz, 6-7 data. Index matches AZ order.
  public_cidrs = [for i in [0, 1] : cidrsubnet(var.vpc_cidr, var.subnet_newbits, i)]
  dmz_cidrs    = [for i in [2, 3] : cidrsubnet(var.vpc_cidr, var.subnet_newbits, i)]
  mz_cidrs     = [for i in [4, 5] : cidrsubnet(var.vpc_cidr, var.subnet_newbits, i)]
  data_cidrs   = [for i in [6, 7] : cidrsubnet(var.vpc_cidr, var.subnet_newbits, i)]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${count.index}"
    Tier = "public"
  })
}

resource "aws_subnet" "dmz" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.dmz_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-dmz-${count.index}"
    Tier = "dmz"
  })
}

resource "aws_subnet" "mz" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.mz_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-mz-${count.index}"
    Tier = "mz"
  })
}

resource "aws_subnet" "data" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.data_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-data-${count.index}"
    Tier = "data"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public"
  })
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat"
  })

  depends_on = [aws_route.public_igw]
}

resource "aws_route_table" "dmz" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-dmz"
  })
}

resource "aws_route" "dmz_nat" {
  route_table_id         = aws_route_table.dmz.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "dmz" {
  count = 2

  subnet_id      = aws_subnet.dmz[count.index].id
  route_table_id = aws_route_table.dmz.id
}

resource "aws_route_table" "mz" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-mz"
  })
}

resource "aws_route" "mz_nat" {
  route_table_id         = aws_route_table.mz.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "mz" {
  count = 2

  subnet_id      = aws_subnet.mz[count.index].id
  route_table_id = aws_route_table.mz.id
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-data"
  })
}

resource "aws_route" "data_nat" {
  count = var.enable_data_nat_route ? 1 : 0

  route_table_id         = aws_route_table.data.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "data" {
  count = 2

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}
