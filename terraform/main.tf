terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

#############################################
# 1. S3 BUCKET - Store raw JSON files
#############################################

resource "aws_s3_bucket" "crypto_data" {
  bucket = "${var.project_name}-raw-data-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = "Crypto Raw Data Bucket"
    Environment = "dev"
    Project     = var.project_name
  }
}

# Generate random suffix to ensure unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Block public access (security best practice)
resource "aws_s3_bucket_public_access_block" "crypto_data" {
  bucket = aws_s3_bucket.crypto_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# 2. VPC & NETWORKING - Redshift needs this
#############################################

# Create VPC
resource "aws_vpc" "redshift_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# Create Internet Gateway (allows Redshift to access internet)
resource "aws_internet_gateway" "redshift_igw" {
  vpc_id = aws_vpc.redshift_vpc.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# Create 2 subnets (Redshift requires at least 2 in different availability zones)
resource "aws_subnet" "redshift_subnet_1" {
  vpc_id            = aws_vpc.redshift_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name    = "${var.project_name}-subnet-1"
    Project = var.project_name
  }
}

resource "aws_subnet" "redshift_subnet_2" {
  vpc_id            = aws_vpc.redshift_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name    = "${var.project_name}-subnet-2"
    Project = var.project_name
  }
}

# Route table (connects subnets to internet gateway)
resource "aws_route_table" "redshift_route_table" {
  vpc_id = aws_vpc.redshift_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.redshift_igw.id
  }

  tags = {
    Name    = "${var.project_name}-route-table"
    Project = var.project_name
  }
}

# Associate subnets with route table
resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.redshift_subnet_1.id
  route_table_id = aws_route_table.redshift_route_table.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.redshift_subnet_2.id
  route_table_id = aws_route_table.redshift_route_table.id
}

#############################################
# 3. SECURITY GROUP - Firewall rules
#############################################

resource "aws_security_group" "redshift_sg" {
  name        = "${var.project_name}-redshift-sg"
  description = "Allow Redshift access from my IP"
  vpc_id      = aws_vpc.redshift_vpc.id

  # Allow inbound on port 5439 (Redshift default) from YOUR IP only
  ingress {
    description = "Redshift access from my IP"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-redshift-sg"
    Project = var.project_name
  }
}

#############################################
# 4. IAM ROLE - Allows Redshift to read from S3
#############################################

# Trust policy: allows Redshift to assume this role
data "aws_iam_policy_document" "redshift_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["redshift.amazonaws.com"]
    }
  }
}

# Create IAM role
resource "aws_iam_role" "redshift_s3_role" {
  name               = "${var.project_name}-redshift-s3-role"
  assume_role_policy = data.aws_iam_policy_document.redshift_assume_role.json

  tags = {
    Name    = "${var.project_name}-redshift-role"
    Project = var.project_name
  }
}

# Permission policy: allows reading from S3
resource "aws_iam_role_policy" "redshift_s3_policy" {
  name = "${var.project_name}-redshift-s3-policy"
  role = aws_iam_role.redshift_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.crypto_data.arn,
          "${aws_s3_bucket.crypto_data.arn}/*"
        ]
      }
    ]
  })
}

#############################################
# 5. REDSHIFT CLUSTER - Data warehouse
#############################################

# Subnet group (tells Redshift which subnets to use)
resource "aws_redshift_subnet_group" "redshift_subnet_group" {
  name       = "${var.project_name}-redshift-subnet-group"
  subnet_ids = [aws_subnet.redshift_subnet_1.id, aws_subnet.redshift_subnet_2.id]

  tags = {
    Name    = "${var.project_name}-subnet-group"
    Project = var.project_name
  }
}

# Redshift cluster
resource "aws_redshift_cluster" "crypto_redshift" {
  cluster_identifier  = "${var.project_name}-redshift"
  database_name       = "crypto_db"
  master_username     = var.redshift_master_username
  master_password     = var.redshift_master_password
  node_type           = "dc2.large"
  cluster_type        = "single-node"
  
  # Networking
  publicly_accessible        = true
  vpc_security_group_ids     = [aws_security_group.redshift_sg.id]
  cluster_subnet_group_name  = aws_redshift_subnet_group.redshift_subnet_group.name
  
  # IAM role for S3 access
  iam_roles = [aws_iam_role.redshift_s3_role.arn]
  
  # Skip final snapshot when destroying (for dev/testing)
  skip_final_snapshot = true

  tags = {
    Name    = "${var.project_name}-redshift"
    Project = var.project_name
  }
}