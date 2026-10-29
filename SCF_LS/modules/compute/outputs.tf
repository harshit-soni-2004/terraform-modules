output "instance_ids" {
  description = "Instance IDs keyed by tier and index."
  value       = { for key, inst in aws_instance.this : key => inst.id }
}

output "private_ips" {
  description = "Private IPs keyed by tier and index."
  value       = { for key, inst in aws_instance.this : key => inst.private_ip }
}

output "instance_ids_by_tier" {
  description = "Instance IDs grouped by tier key."
  value = {
    for key, tier in var.tiers : key => [
      for index in range(tier.count) : aws_instance.this["${key}-${index}"].id
    ]
  }
}
