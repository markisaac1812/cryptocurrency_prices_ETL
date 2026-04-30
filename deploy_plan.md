# EC2 Deployment Plan - Crypto Pipeline

## Overview
Deploy the fully functional crypto ETL pipeline to EC2 so it runs 24/7 without manual intervention.

**Pipeline Flow:**

**Execution:** Daily at 9 PM Cairo time (automated by Airflow)

---

## Prerequisites
- ✅ Terraform installed locally
- ✅ AWS CLI configured with credentials
- ✅ RDS, S3, VPC already provisioned (from previous steps)
- ✅ Docker Compose setup working locally
- ✅ All DAGs, scripts, and dbt models ready

---

## Step 1: Update Terraform - Add EC2 Infrastructure

### 1.1 Update `terraform/main.tf` - Add IAM Role

```hcl
#############################################
# 4. IAM ROLE - EC2 access to S3 & RDS
#############################################

resource "aws_iam_role" "ec2_airflow_role" {
  name = "${var.project_name}-ec2-airflow-role"

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
}

# Policy: S3 access
resource "aws_iam_role_policy" "s3_access" {
  name = "${var.project_name}-s3-access"
  role = aws_iam_role.ec2_airflow_role.id

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

# Instance profile
resource "aws_iam_instance_profile" "ec2_airflow_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_airflow_role.id
}
```

### 1.2 Update `terraform/main.tf` - Add Security Group

#############################################
# 5. SECURITY GROUP - EC2 (Airflow + SSH)
#############################################

resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for Airflow EC2"
  vpc_id      = aws_vpc.main_vpc.id

  # SSH from your IP
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Airflow webserver (8080) from your IP
  ingress {
    description = "Airflow UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Allow EC2 to reach RDS (5432)
  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

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

# Update RDS security group to allow EC2
resource "aws_security_group_rule" "rds_from_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.ec2_sg.id
  description              = "PostgreSQL from Airflow EC2"
}

#############################################
# 6. EC2 INSTANCE - Airflow Server
#############################################

resource "aws_instance" "airflow_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"
  
  subnet_id                   = aws_subnet.subnet_1.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_airflow_profile.name
  associate_public_ip_address = true

  # User data script - install Docker & deploy Airflow
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    s3_bucket          = aws_s3_bucket.crypto_data.id
    rds_host           = aws_db_instance.postgres.address
    rds_port           = aws_db_instance.postgres.port
    rds_user           = var.db_username
    rds_password       = var.db_password
    rds_db_name        = var.db_name
    aws_region         = var.region
    project_name       = var.project_name
  }))

  tags = {
    Name    = "${var.project_name}-airflow-server"
    Project = var.project_name
  }

  depends_on = [
    aws_db_instance.postgres,
    aws_s3_bucket.crypto_data
  ]
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


STEP2:create user data script
#!/bin/bash
set -e

echo "🚀 Starting Airflow EC2 setup..."

# Update system
yum update -y
yum install -y git docker

# Start Docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create airflow user
useradd -m -s /bin/bash airflow || true
usermod -aG docker airflow

# Create directories
mkdir -p /home/airflow/crypto-pipeline
cd /home/airflow/crypto-pipeline

# Create .env file with AWS credentials
cat > /home/airflow/crypto-pipeline/.env << 'EOF'
# Airflow
AIRFLOW_HOME=/home/airflow/airflow
AIRFLOW__CORE__DAGS_FOLDER=/home/airflow/airflow/dags
AIRFLOW__CORE__LOAD_EXAMPLES=False
AIRFLOW__CORE__UNIT_TEST_MODE=False
AIRFLOW__CORE__EXECUTOR=LocalExecutor
AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${RDS_USER}:${RDS_PASSWORD}@${RDS_HOST}:${RDS_PORT}/${RDS_DB}
AIRFLOW__WEBSERVER__EXPOSE_CONFIG=True

# AWS
AWS_REGION=${AWS_REGION}
S3_BUCKET_NAME=${S3_BUCKET}

# Database
DATABASE_HOST=${RDS_HOST}
DATABASE_PORT=${RDS_PORT}
DATABASE_USERNAME=${RDS_USER}
DATABASE_PASSWORD=${RDS_PASSWORD}
DATABASE_NAME=${RDS_DB}

# CoinGecko (optional API key)
COINGECKO_API_KEY=
EOF

# Replace Terraform variables
sed -i "s|\${RDS_USER}|${rds_user}|g" .env
sed -i "s|\${RDS_PASSWORD}|${rds_password}|g" .env
sed -i "s|\${RDS_HOST}|${rds_host}|g" .env
sed -i "s|\${RDS_PORT}|${rds_port}|g" .env
sed -i "s|\${RDS_DB}|${rds_db_name}|g" .env
sed -i "s|\${AWS_REGION}|${aws_region}|g" .env
sed -i "s|\${S3_BUCKET}|${s3_bucket}|g" .env

# Change ownership
chown -R airflow:airflow /home/airflow/crypto-pipeline

# Create systemd service for docker-compose
cat > /etc/systemd/system/airflow.service << 'EOF'
[Unit]
Description=Airflow Docker Compose
Requires=docker.service
After=docker.service
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=airflow
WorkingDirectory=/home/airflow/crypto-pipeline
Environment="PATH=/usr/local/bin:/usr/bin"
ExecStart=/usr/local/bin/docker-compose up
ExecStop=/usr/local/bin/docker-compose down
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable airflow
systemctl start airflow

echo "✅ Airflow EC2 setup complete!"



Step 3 update ouputs.tf

output "ec2_public_ip" {
  description = "Public IP of Airflow EC2"
  value       = aws_instance.airflow_server.public_ip
}

output "ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.airflow_server.id
}

output "airflow_url" {
  description = "Airflow UI URL"
  value       = "http://${aws_instance.airflow_server.public_ip}:8080"
}

output "ec2_ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i airflow-key.pem ec2-user@${aws_instance.airflow_server.public_ip}"
}



Step 4 update variables.tf
variable "db_username" {
  description = "RDS username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "RDS password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "crypto_db"
}


Step 5 update tfvars
project_name = "crypto-pipeline"
region       = "eu-central-1"
my_ip        = "YOUR_IP_ADDRESS/32"          # Replace with your home/office IP
db_username  = "crypto_user"
db_password  = "YourSecurePassword123!"      # Change this!
db_name      = "crypto_db"

rest in chat