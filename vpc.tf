locals {
    subnet_cidrs = [
        for i in range(length(var.availability_zones)) : cidrsubnet(var.vpc_cidr, 8, i)
    ]
}

resource "aws_vpc" "kafka-vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "kafka-vpc"
  }
}

resource "aws_internet_gateway" "kafka-igw" {
  vpc_id = aws_vpc.kafka-vpc.id

  tags = {
    Name = "kafka-igw"
  }

  depends_on = [aws_vpc.kafka-vpc]
}

resource "aws_subnet" "kafka-subnet" {
  count      = length(var.availability_zones)
  vpc_id     = aws_vpc.kafka-vpc.id
  cidr_block = local.subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "kafka-subnet-${count.index}"
  }

  depends_on = [aws_vpc.kafka-vpc]
}

resource "aws_route_table" "kafka-route-table" {
  vpc_id     = aws_vpc.kafka-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kafka-igw.id
  }

  tags = {
    Name = "kafka-route-table"
  }

  depends_on = [
    aws_vpc.kafka-vpc,
    aws_internet_gateway.kafka-igw
    ]
}

resource "aws_route_table_association" "kafka-route-table-association" {
  count = length(var.availability_zones)  
  subnet_id      = aws_subnet.kafka-subnet[count.index].id
  route_table_id = aws_route_table.kafka-route-table.id

  depends_on = [
    aws_subnet.kafka-subnet,
    aws_route_table.kafka-route-table
  ]
}