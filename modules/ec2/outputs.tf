output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance."
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "Private IPv4 address of the instance."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IPv4 address of the instance, or null when it has none."
  value       = aws_instance.this.public_ip != "" ? aws_instance.this.public_ip : null
}

output "availability_zone" {
  description = "Availability Zone of the instance."
  value       = aws_instance.this.availability_zone
}
