output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.crypto_data.id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.crypto_postgres.endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.crypto_postgres.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.crypto_postgres.username
  sensitive   = true
}

output "connection_command" {
  description = "Command to connect to RDS"
  value       = "psql -h ${aws_db_instance.crypto_postgres.address} -U ${aws_db_instance.crypto_postgres.username} -d ${aws_db_instance.crypto_postgres.db_name} -p 5432"
}

output "ec2_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.airflow_ec2.public_ip
}

output "ec2_ssh_command" {
  description = "Command to SSH into EC2"
  value       = "ssh -i /path/to/your-key.pem ubuntu@${aws_instance.airflow_ec2.public_ip}"
}

output "airflow_ui_url" {
  description = "Airflow UI URL"
  value       = "http://${aws_instance.airflow_ec2.public_ip}:8080"
}