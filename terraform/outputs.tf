output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.crypto_data.id
}

output "redshift_endpoint" {
  description = "Redshift cluster endpoint"
  value       = aws_redshift_cluster.crypto_redshift.endpoint
}

output "redshift_database_name" {
  description = "Redshift database name"
  value       = aws_redshift_cluster.crypto_redshift.database_name
}

output "redshift_iam_role_arn" {
  description = "IAM role ARN for Redshift S3 access"
  value       = aws_iam_role.redshift_s3_role.arn
}

output "connection_command" {
  description = "Command to connect to Redshift"
  value       = "psql -h ${aws_redshift_cluster.crypto_redshift.endpoint} -U ${var.redshift_master_username} -d ${aws_redshift_cluster.crypto_redshift.database_name} -p 5439"
}