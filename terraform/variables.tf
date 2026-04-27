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

variable "redshift_master_username" {
  type        = string
  description = "Redshift admin username"
  default     = "admin"
}

variable "redshift_master_password" {
  type        = string
  description = "Redshift admin password"
  sensitive   = true
}

variable "my_ip" {
  type        = string
  description = "Your public IP for Redshift access (find it at https://whatismyipaddress.com)"
}