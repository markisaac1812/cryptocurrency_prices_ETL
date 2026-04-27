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