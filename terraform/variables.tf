variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name for resource naming"
  default     = "crypto-pipeline"
}

variable "db_master_username" {
  type        = string
  description = "RDS master username"
  default     = "admin"
}

variable "db_master_password" {
  type        = string
  description = "RDS master password"
  sensitive   = true
}

variable "my_ip" {
  type        = string
  description = "Your public IP for database access (find it at https://whatismyipaddress.com)"
}

variable "ec2_key_name" {
  type        = string
  description = "Name of SSH key pair for EC2 access"
}