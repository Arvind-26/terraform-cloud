terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Create a VPC
resource "aws_vpc" "three_tier" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "three-tier-vpc"
  }
}

# Create an Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.three_tier.id
  cidr_block        = "10.0.0.0/20"
  availability_zone = "us-east-1a"
  tags = {
    Name = "public-subnet"
  }
}

# Create a Private Subnet server
resource "aws_subnet" "private_subnet_server" {
  vpc_id            = aws_vpc.three_tier.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "us-east-1b"
  tags = {
    Name = "private-subnet-server"
  }
}

# Create a Private Subnet database
resource "aws_subnet" "private_subnet_database" {
  vpc_id            = aws_vpc.three_tier.id
  cidr_block        = "10.0.32.0/20"
  availability_zone = "us-east-1c"
  tags = {
    Name = "private-subnet-database"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.three_tier.id
  tags = {
    Name = "three-tier-igw"
  }
}

# Create a Route Table for the Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.three_tier.id
  tags = {
    Name = "public-route-table"
  }
}

# Attach the Internet Gateway to the Public Route Table
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate the Public Route Table with the Public Subnet
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create a Security Group for the Web Server
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.three_tier.id
  name   = "web-sg"
  description = "Allow HTTP and SSH access to the web server" 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "web-sg"
  }
}

# Launch an EC2 Instance in the Public Subnet
resource "aws_instance" "web_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]  # Changed from security_groups
  tags = {
    Name = "web-server"
  }
}

# Create a Security Group for the Application Server
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.three_tier.id
  name   = "app-sg"
  description = "Allow access from the web server to the application server"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0  
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "app-sg"
  }
}

# Launch an EC2 Instance in the Private Subnet for Application Server
resource "aws_instance" "app_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet_server.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]  # Changed from security_groups
  tags = {
    Name = "app-server"
  }
}

# Create a DB Subnet Group for RDS
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "three-tier-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_database.id, aws_subnet.private_subnet_server.id]
  tags = {
    Name = "three-tier-db-subnet-group"
  }
}

# Launch RDS instance in the Private Subnet for Database
resource "aws_db_instance" "db_instance" {
  identifier         = "three-tier-db"
  engine             = "mysql"
  engine_version     = "8.0"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  storage_type       = "gp2"
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  username           = "admin"
  password           = "password123"
  skip_final_snapshot = true
  publicly_accessible = false
  tags = {
    Name = "three-tier-db"
  }
}