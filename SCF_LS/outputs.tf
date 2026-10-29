output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs by tier."
  value = {
    public = module.network.public_subnet_ids
    dmz    = module.network.dmz_subnet_ids
    mz     = module.network.mz_subnet_ids
    data   = module.network.data_subnet_ids
  }
}

output "external_alb_dns_name" {
  description = "External ALB DNS name."
  value       = module.alb.external_dns_name
}

output "internal_alb_dns_name" {
  description = "Internal ALB DNS name."
  value       = module.alb.internal_dns_name
}

output "instance_ids" {
  description = "Instance IDs keyed by tier and index."
  value       = module.compute.instance_ids
}

output "private_ips" {
  description = "Private IPs keyed by tier and index."
  value       = module.compute.private_ips
}

output "security_group_ids" {
  description = "Security group IDs."
  value = {
    external_alb  = module.security.external_alb_id
    internal_alb  = module.security.internal_alb_id
    dmz_web       = module.security.dmz_web_id
    mz_web        = module.security.mz_web_id
    app           = module.security.app_id
    reporting_app = module.security.reporting_id
    rabbitmq      = module.security.rabbitmq_id
    redis         = module.security.redis_id
    mysql         = module.security.mysql_id
  }
}

output "bucket_name" {
  description = "Object-storage bucket name."
  value       = module.files.bucket_name
}

output "bucket_arn" {
  description = "Object-storage bucket ARN."
  value       = module.files.bucket_arn
}

output "instance_profile_name" {
  description = "Instance profile name created by this stack, or null when an existing profile is used."
  value       = var.create_instance_profile ? aws_iam_instance_profile.ssm[0].name : null
}

output "target_group_arns" {
  description = "Target group ARNs."
  value       = module.alb.target_group_arns
}
