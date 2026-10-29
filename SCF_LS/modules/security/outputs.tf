output "external_alb_id" {
  value = aws_security_group.external_alb.id
}

output "internal_alb_id" {
  value = aws_security_group.internal_alb.id
}

output "dmz_web_id" {
  value = aws_security_group.dmz_web.id
}

output "mz_web_id" {
  value = aws_security_group.mz_web.id
}

output "app_id" {
  value = aws_security_group.app.id
}

output "reporting_id" {
  value = aws_security_group.reporting.id
}

output "rabbitmq_id" {
  value = aws_security_group.rabbitmq.id
}

output "redis_id" {
  value = aws_security_group.redis.id
}

output "mysql_id" {
  value = aws_security_group.mysql.id
}
