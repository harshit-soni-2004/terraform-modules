output "bucket_name" {
  description = "Name of the S3 bucket."
  value       = module.s3.bucket_name
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = module.s3.bucket_arn
}

output "bucket_region" {
  description = "Region of the S3 bucket."
  value       = module.s3.bucket_region
}

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = module.ec2.instance_id
}

output "instance_arn" {
  description = "ARN of the EC2 instance."
  value       = module.ec2.instance_arn
}

output "private_ip" {
  description = "Private IP of the EC2 instance."
  value       = module.ec2.private_ip
}

output "public_ip" {
  description = "Public IP of the EC2 instance, or null when it has none."
  value       = module.ec2.public_ip
}

output "availability_zone" {
  description = "Availability Zone of the EC2 instance."
  value       = module.ec2.availability_zone
}

output "rds_db_instance_identifier" {
  description = "RDS identifier when create_rds is true. Null when RDS is disabled."
  value       = one(module.rds[*].db_instance_identifier)
}

output "rds_endpoint" {
  description = "RDS endpoint when create_rds is true. Null when RDS is disabled."
  value       = one(module.rds[*].endpoint)
}

output "rds_port" {
  description = "RDS port when create_rds is true. Null when RDS is disabled."
  value       = one(module.rds[*].port)
}

output "rds_arn" {
  description = "RDS ARN when create_rds is true. Null when RDS is disabled."
  value       = one(module.rds[*].arn)
}

output "rds_master_user_secret_arn" {
  description = "Secrets Manager ARN for the RDS master password when create_rds is true. Null when RDS is disabled. This is not the password."
  value       = one(module.rds[*].master_user_secret_arn)
}
