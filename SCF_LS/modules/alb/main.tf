locals {
  default_targets = [for key, tier in var.internal_targets : key if tier.default_target]
  default_key     = one(local.default_targets)
  extra_targets   = { for key, tier in var.internal_targets : key => tier if !tier.default_target }
}

resource "aws_lb" "external" {
  name               = "${var.name_prefix}-ext"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.external_security_group_id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ext"
  })

  lifecycle {
    precondition {
      condition     = var.external_certificate_arn != null || var.allow_insecure_external_listener
      error_message = "External ALB needs external_certificate_arn, or allow_insecure_external_listener = true (TEST-ONLY)."
    }
  }
}

resource "aws_lb" "internal" {
  name               = "${var.name_prefix}-int"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.internal_security_group_id]
  subnets            = var.mz_subnet_ids

  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-int"
  })

  lifecycle {
    precondition {
      condition     = var.internal_certificate_arn != null || var.allow_insecure_internal_listener
      error_message = "Internal ALB needs internal_certificate_arn, or allow_insecure_internal_listener = true (TEST-ONLY)."
    }
  }
}

resource "aws_lb_target_group" "dmz" {
  name     = "${var.name_prefix}-dmz"
  port     = var.dmz_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = var.dmz_health_check_path
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-dmz"
  })
}

resource "aws_lb_target_group_attachment" "dmz" {
  for_each = var.dmz_instance_ids

  target_group_arn = aws_lb_target_group.dmz.arn
  target_id        = each.value
  port             = var.dmz_port
}

resource "aws_lb_target_group" "internal" {
  for_each = var.internal_targets

  name     = "${var.name_prefix}-${each.key}"
  port     = each.value.port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = each.value.health_check_path
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}"
  })
}

resource "aws_lb_target_group_attachment" "internal" {
  for_each = merge([
    for tier_key, ids in var.internal_instance_ids : {
      for inst_key, inst_id in ids :
      inst_key => {
        tg   = tier_key
        id   = inst_id
        port = var.internal_targets[tier_key].port
      }
    }
  ]...)

  target_group_arn = aws_lb_target_group.internal[each.value.tg].arn
  target_id        = each.value.id
  port             = each.value.port
}

resource "aws_lb_listener" "external_https" {
  count = var.external_certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.external.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.external_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dmz.arn
  }
}

resource "aws_lb_listener" "external_http" {
  count = var.allow_insecure_external_listener ? 1 : 0

  load_balancer_arn = aws_lb.external.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dmz.arn
  }
}

resource "aws_lb_listener" "internal_https" {
  count = var.internal_certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.internal.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.internal_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal[local.default_key].arn
  }
}

resource "aws_lb_listener" "internal_http" {
  count = var.allow_insecure_internal_listener ? 1 : 0

  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal[local.default_key].arn
  }
}

resource "aws_lb_listener_rule" "internal_https" {
  for_each = var.internal_certificate_arn != null ? local.extra_targets : {}

  listener_arn = aws_lb_listener.internal_https[0].arn
  priority     = 10 + index(keys(local.extra_targets), each.key)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}

resource "aws_lb_listener_rule" "internal_http" {
  for_each = var.allow_insecure_internal_listener ? local.extra_targets : {}

  listener_arn = aws_lb_listener.internal_http[0].arn
  priority     = 10 + index(keys(local.extra_targets), each.key)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}
