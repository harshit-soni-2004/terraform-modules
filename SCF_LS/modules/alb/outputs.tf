output "external_dns_name" {
  description = "External ALB DNS name."
  value       = aws_lb.external.dns_name
}

output "internal_dns_name" {
  description = "Internal ALB DNS name."
  value       = aws_lb.internal.dns_name
}

output "external_arn" {
  value = aws_lb.external.arn
}

output "internal_arn" {
  value = aws_lb.internal.arn
}

output "target_group_arns" {
  description = "Target group ARNs, keyed by tier. dmz is the external group."
  value = merge(
    { dmz = aws_lb_target_group.dmz.arn },
    { for key, tg in aws_lb_target_group.internal : key => tg.arn },
  )
}
