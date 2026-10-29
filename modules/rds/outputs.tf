output "db_instance_identifier" {
  description = "Identifier of the RDS instance."
  value       = aws_db_instance.this.identifier
}

output "endpoint" {
  description = "Hostname and port of the RDS instance, in address:port form. Not a password."
  value       = aws_db_instance.this.endpoint
}

output "port" {
  description = "Port the database listens on."
  value       = aws_db_instance.this.port
}

output "arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.this.arn
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret that holds the master password. This output is the ARN only, not the password or the secret value."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
