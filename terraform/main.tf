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
# 2. VPC & NETWORKING - RDS needs this
#############################################

# Create VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# Create 2 subnets (RDS requires at least 2 in different AZs)
resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-subnet-1"
    Project = var.project_name
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-subnet-2"
    Project = var.project_name
  }
}

# Route table
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name    = "${var.project_name}-route-table"
    Project = var.project_name
  }
}

# Associate subnets with route table
resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.main_route_table.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.main_route_table.id
}

#############################################
# 3. SECURITY GROUP - Firewall for RDS
#############################################

resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL access from my IP"
  vpc_id      = aws_vpc.main_vpc.id

  # Allow inbound on port 5432 (PostgreSQL) from YOUR IP only
  ingress {
    description = "PostgreSQL access from my IP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Allow inbound on port 5432 from EC2 security group
  ingress {
    description     = "PostgreSQL access from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
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
    Name    = "${var.project_name}-rds-sg"
    Project = var.project_name
  }
}

#############################################
# 4. IAM ROLE - Allows RDS to access S3 (optional but good practice)
#############################################

# Trust policy: allows RDS to assume this role
data "aws_iam_policy_document" "rds_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

# Create IAM role
resource "aws_iam_role" "rds_s3_role" {
  name               = "${var.project_name}-rds-s3-role"
  assume_role_policy = data.aws_iam_policy_document.rds_assume_role.json

  tags = {
    Name    = "${var.project_name}-rds-role"
    Project = var.project_name
  }
}

# Permission policy: allows reading from S3
resource "aws_iam_role_policy" "rds_s3_policy" {
  name = "${var.project_name}-rds-s3-policy"
  role = aws_iam_role.rds_s3_role.id

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
# 5. RDS POSTGRESQL - Database
#############################################

# DB Subnet Group (tells RDS which subnets to use)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  tags = {
    Name    = "${var.project_name}-subnet-group"
    Project = var.project_name
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "crypto_postgres" {
  identifier           = "${var.project_name}-postgres"
  engine               = "postgres"
  engine_version       = "16"
  instance_class       = "db.t3.micro"  # FREE TIER ELIGIBLE!
  allocated_storage    = 20              
  storage_type         = "gp2"
  
  db_name  = "crypto_db"
  username = var.db_master_username
  password = var.db_master_password
  
  # Networking
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  
  # Backups (can disable for dev to save space)
  backup_retention_period = 0  # No backups (saves space)
  skip_final_snapshot     = true
  
  # Performance
  max_allocated_storage = 0  # Disable autoscaling for free tier
  
  tags = {
    Name    = "${var.project_name}-postgres"
    Project = var.project_name
  }
}

#############################################
# 6. EC2 INSTANCE - Run Airflow
#############################################

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow SSH and HTTP for Airflow"
  vpc_id      = aws_vpc.main_vpc.id

  # SSH access from your IP
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Airflow UI access from your IP
  ingress {
    description = "Airflow UI from my IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Allow all outbound
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-ec2-sg"
    Project = var.project_name
  }
}

# IAM Role for EC2 (allows EC2 to access S3 and RDS)
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ec2-role"
    Project = var.project_name
  }
}

# Attach S3 access policy to EC2 role
resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "${var.project_name}-ec2-s3-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
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

# IAM Instance Profile (attaches role to EC2)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance
resource "aws_instance" "airflow_ec2" {
  ami           = "ami-0084a47cc718c111a"  # Ubuntu 24.04 LTS in eu-central-1
  instance_type = "t3.medium"
  
  subnet_id                   = aws_subnet.subnet_1.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  
  # SSH key pair (you need to create this in AWS console first)
  key_name = var.ec2_key_name
  
  # Storage
  root_block_device {
    volume_size = 30  # GB
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Update system
              apt-get update
              apt-get upgrade -y
              
              # Install Docker
              apt-get install -y docker.io docker-compose
              systemctl start docker
              systemctl enable docker
              
              # Add ubuntu user to docker group
              usermod -aG docker ubuntu
              
              # Install AWS CLI
              apt-get install -y awscli
              
              echo "EC2 setup complete" > /tmp/setup_complete.txt
              EOF

  tags = {
    Name    = "${var.project_name}-airflow-ec2"
    Project = var.project_name
  }
}
