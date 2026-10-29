resource "aws_security_group" "external_alb" {
  name        = "${var.name_prefix}-external-alb"
  description = "External ALB. Ingress is the caller CIDR list."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-external-alb"
  })
}

resource "aws_vpc_security_group_ingress_rule" "external_https" {
  security_group_id = aws_security_group.external_alb.id
  description       = "HTTPS to the external ALB"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value

  for_each = toset(var.alb_ingress_cidrs)
}

resource "aws_vpc_security_group_ingress_rule" "external_http_test" {
  for_each = var.allow_insecure_external_listener ? toset(var.alb_ingress_cidrs) : []

  security_group_id = aws_security_group.external_alb.id
  description       = "TEST-ONLY HTTP to the external ALB"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

resource "aws_security_group" "internal_alb" {
  name        = "${var.name_prefix}-internal-alb"
  description = "Internal ALB. Ingress only from web tiers."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-internal-alb"
  })
}

resource "aws_security_group" "dmz_web" {
  name        = "${var.name_prefix}-dmz-web"
  description = "DMZ web. Ingress from the external ALB."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-dmz-web"
  })
}

resource "aws_security_group" "mz_web" {
  name        = "${var.name_prefix}-mz-web"
  description = "MZ web. Ingress from bank-staff CIDRs only."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-mz-web"
  })
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app"
  description = "App tier. Ingress from the internal ALB."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app"
  })
}

resource "aws_security_group" "reporting" {
  name        = "${var.name_prefix}-reporting-app"
  description = "Reporting app tier. Ingress from the internal ALB."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-reporting-app"
  })
}

resource "aws_security_group" "rabbitmq" {
  name        = "${var.name_prefix}-rabbitmq"
  description = "RabbitMQ. Client ports from app tiers. Cluster ports from itself."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rabbitmq"
  })
}

resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-redis"
  description = "Redis. Client port from app tiers. Cluster ports from itself."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis"
  })
}

resource "aws_security_group" "mysql" {
  name        = "${var.name_prefix}-mysql"
  description = "MySQL. 3306 from app tiers only."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-mysql"
  })
}

resource "aws_vpc_security_group_ingress_rule" "internal_from_web" {
  for_each = {
    dmz = aws_security_group.dmz_web.id
    mz  = aws_security_group.mz_web.id
  }

  security_group_id            = aws_security_group.internal_alb.id
  description                  = "HTTPS from ${each.key} web"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "internal_from_web_http_test" {
  for_each = var.allow_insecure_internal_listener ? {
    dmz = aws_security_group.dmz_web.id
    mz  = aws_security_group.mz_web.id
  } : {}

  security_group_id            = aws_security_group.internal_alb.id
  description                  = "TEST-ONLY HTTP from ${each.key} web"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "dmz_from_external_alb" {
  security_group_id            = aws_security_group.dmz_web.id
  description                  = "HTTP from the external ALB inside the VPC"
  ip_protocol                  = "tcp"
  from_port                    = var.dmz_web_port
  to_port                      = var.dmz_web_port
  referenced_security_group_id = aws_security_group.external_alb.id
}

resource "aws_vpc_security_group_ingress_rule" "mz_from_bank" {
  for_each = toset(var.bank_staff_cidrs)

  security_group_id = aws_security_group.mz_web.id
  description       = "Bank-staff path to MZ web. HTTP, not TLS, on the stock Nginx port."
  ip_protocol       = "tcp"
  from_port         = var.mz_web_port
  to_port           = var.mz_web_port
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "app_from_internal_alb" {
  for_each = toset([for port in var.app_ports : tostring(port)])

  security_group_id            = aws_security_group.app.id
  description                  = "HTTP from the internal ALB"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.internal_alb.id
}

resource "aws_vpc_security_group_ingress_rule" "reporting_from_internal_alb" {
  for_each = toset([for port in var.reporting_ports : tostring(port)])

  security_group_id            = aws_security_group.reporting.id
  description                  = "HTTP from the internal ALB"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.internal_alb.id
}

resource "aws_vpc_security_group_ingress_rule" "rabbit_from_apps" {
  for_each = {
    for pair in setproduct(["app", "reporting"], ["client", "management"]) :
    "${pair[0]}-${pair[1]}" => {
      source = pair[0] == "app" ? aws_security_group.app.id : aws_security_group.reporting.id
      port   = pair[1] == "client" ? var.rabbitmq_client_port : var.rabbitmq_management_port
    }
  }

  security_group_id            = aws_security_group.rabbitmq.id
  description                  = "RabbitMQ ${each.value.port} from ${split("-", each.key)[0]}"
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  referenced_security_group_id = each.value.source
}

resource "aws_vpc_security_group_ingress_rule" "rabbit_cluster" {
  for_each = toset([for port in var.rabbitmq_cluster_ports : tostring(port)])

  security_group_id            = aws_security_group.rabbitmq.id
  description                  = "RabbitMQ intra-cluster port ${each.value}. Topology is not configured by Terraform."
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.rabbitmq.id
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_apps" {
  for_each = {
    app       = aws_security_group.app.id
    reporting = aws_security_group.reporting.id
  }

  security_group_id            = aws_security_group.redis.id
  description                  = "Redis from ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = var.redis_port
  to_port                      = var.redis_port
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "redis_cluster" {
  for_each = toset([for port in var.redis_cluster_ports : tostring(port)])

  security_group_id            = aws_security_group.redis.id
  description                  = "Redis intra-cluster port ${each.value}. Replication is not configured by Terraform."
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.redis.id
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_apps" {
  for_each = {
    app       = aws_security_group.app.id
    reporting = aws_security_group.reporting.id
  }

  security_group_id            = aws_security_group.mysql.id
  description                  = "MySQL from ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = var.mysql_port
  to_port                      = var.mysql_port
  referenced_security_group_id = each.value
}

locals {
  # Bootstrap only: image pull and SSM. East-west paths are separate SG-to-SG rules below.
  # aws_security_group removes AWS's default allow-all egress. These groups have no other egress.
  locked_down = {
    dmz_web   = aws_security_group.dmz_web.id
    mz_web    = aws_security_group.mz_web.id
    app       = aws_security_group.app.id
    reporting = aws_security_group.reporting.id
    rabbitmq  = aws_security_group.rabbitmq.id
    redis     = aws_security_group.redis.id
    mysql     = aws_security_group.mysql.id
  }
}

resource "aws_vpc_security_group_egress_rule" "instances_https" {
  for_each = local.locked_down

  security_group_id = each.value
  description       = "HTTPS via NAT for image pull and SSM. Not an ingress rule."
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "instances_dns_udp" {
  for_each = local.locked_down

  security_group_id = each.value
  description       = "DNS to the Amazon resolver inside the VPC"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "instances_dns_tcp" {
  for_each = local.locked_down

  security_group_id = each.value
  description       = "DNS over TCP to the Amazon resolver inside the VPC"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "external_alb_to_dmz" {
  security_group_id            = aws_security_group.external_alb.id
  description                  = "External ALB to DMZ web on the target-group port, not 443"
  ip_protocol                  = "tcp"
  from_port                    = var.dmz_web_port
  to_port                      = var.dmz_web_port
  referenced_security_group_id = aws_security_group.dmz_web.id
}

resource "aws_vpc_security_group_egress_rule" "internal_alb_to_app" {
  for_each = toset([for port in var.app_ports : tostring(port)])

  security_group_id            = aws_security_group.internal_alb.id
  description                  = "Internal ALB to app port ${each.value}"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "internal_alb_to_reporting" {
  for_each = toset([for port in var.reporting_ports : tostring(port)])

  security_group_id            = aws_security_group.internal_alb.id
  description                  = "Internal ALB to reporting port ${each.value}. Same port as the target group and health check."
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.reporting.id
}

resource "aws_vpc_security_group_egress_rule" "web_to_internal_alb" {
  for_each = {
    dmz = aws_security_group.dmz_web.id
    mz  = aws_security_group.mz_web.id
  }

  security_group_id            = each.value
  description                  = "HTTPS to the internal ALB. Mirrors the listener ingress."
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.internal_alb.id
}

resource "aws_vpc_security_group_egress_rule" "web_to_internal_alb_http_test" {
  for_each = var.allow_insecure_internal_listener ? {
    dmz = aws_security_group.dmz_web.id
    mz  = aws_security_group.mz_web.id
  } : {}

  security_group_id            = each.value
  description                  = "TEST-ONLY HTTP to the internal ALB. Mirrors the test listener ingress."
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.internal_alb.id
}

resource "aws_vpc_security_group_egress_rule" "apps_to_mysql" {
  for_each = {
    app       = aws_security_group.app.id
    reporting = aws_security_group.reporting.id
  }

  security_group_id            = each.value
  description                  = "MySQL from ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = var.mysql_port
  to_port                      = var.mysql_port
  referenced_security_group_id = aws_security_group.mysql.id
}

resource "aws_vpc_security_group_egress_rule" "apps_to_redis" {
  for_each = {
    app       = aws_security_group.app.id
    reporting = aws_security_group.reporting.id
  }

  security_group_id            = each.value
  description                  = "Redis from ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = var.redis_port
  to_port                      = var.redis_port
  referenced_security_group_id = aws_security_group.redis.id
}

resource "aws_vpc_security_group_egress_rule" "apps_to_rabbit" {
  for_each = {
    for pair in setproduct(["app", "reporting"], ["client", "management"]) :
    "${pair[0]}-${pair[1]}" => {
      source = pair[0] == "app" ? aws_security_group.app.id : aws_security_group.reporting.id
      port   = pair[1] == "client" ? var.rabbitmq_client_port : var.rabbitmq_management_port
    }
  }

  security_group_id            = each.value.source
  description                  = "RabbitMQ ${each.value.port} from ${split("-", each.key)[0]}"
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  referenced_security_group_id = aws_security_group.rabbitmq.id
}

resource "aws_vpc_security_group_egress_rule" "rabbit_cluster" {
  for_each = toset([for port in var.rabbitmq_cluster_ports : tostring(port)])

  security_group_id            = aws_security_group.rabbitmq.id
  description                  = "RabbitMQ intra-cluster port ${each.value}. Mirrors the ingress rule."
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.rabbitmq.id
}

resource "aws_vpc_security_group_egress_rule" "redis_cluster" {
  for_each = toset([for port in var.redis_cluster_ports : tostring(port)])

  security_group_id            = aws_security_group.redis.id
  description                  = "Redis intra-cluster port ${each.value}. Mirrors the ingress rule."
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.redis.id
}
